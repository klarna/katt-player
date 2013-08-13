###
   Copyright 2013 Klarna AB

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
###

fs = require 'fs'
path = require 'path'
url = require 'url'
glob = require 'glob'
_ = require 'lodash'
katt = require 'katt-js'
{
  isJsonCT
  normalizeHeaders
  parseHost
} = katt.utils
callbacks = katt.callbacks
{
  validate
  validateBody
  validateHeaders
  validateMethod
  validateStatusCode
  validateUrl
} = katt.validate
MockResponse = require '../mock-response'
MockRequest = require '../mock-request'


GLOB_OPTIONS =
  nosort: true
  stat: false


module.exports = class LinearCheckEngine
  options: undefined
  _contexts: undefined
  _playTransactionIndex_modifyContext: () ->
  _middleware_resolveTransactionIndex: (req, res, transactionIndex) -> transactionIndex


  constructor: ({scenarios, options}) ->
    return new LinearCheckEngine({scenarios, options})  unless this instanceof LinearCheckEngine
    options ?= {}
    @scenariosByFilename = {}
    @_contexts =
      UID:
        UID: undefined
        scenario: undefined
        transactionIndex: undefined
        params: undefined
    @options = _.merge options, {
      default:
        scenario: undefined
        transaction: 0
      params: {}
      callbacks:
        preSend: undefined
        postSend: undefined
      check:
        url: true
        method: true
        headers: true
        body: true
    }
    @loadScenarios scenarios


  loadScenario: (filename) ->
    try
      blueprint = katt.readScenario filename
    catch e
      throw new Error "Unable to find/parse blueprint file #{filename}\n#{e}"
    @scenariosByFilename[filename] = {
      filename
      blueprint
    }


  loadScenarios: (scenarios) ->
    scenarios = [scenarios]  unless _.isArray scenarios
    for scenario in scenarios
      continue  unless fs.existsSync scenario
      scenario = path.normalize scenario

      if fs.statSync(scenario).isDirectory()
        apibs = glob.sync "#{scenario}/**/*.apib", GLOB_OPTIONS
        @loadScenarios apibs
      else if fs.statSync(scenario).isFile()
        @loadScenario scenario


  middleware: (req, res, next) =>
    if /katt_scenarios\.json/.test req.url
      @middleware_json req, res, next
    else
      @middleware_scenario req, res, next


  middleware_json: (req, res, next) ->
    res.setHeader 'Content-Type', 'application/json'
    res.body = JSON.stringify @scenariosByFilename, null, 2
    res.send 200, res.body


  middleware_scenario: (req, res, next) ->
    cookieScenario = req.cookies.katt_scenario or @options.default.scenario
    cookieTransaction = decodeURIComponent(req.cookies.katt_transaction or @options.default.transaction)
    [transactionIndex, resetToTransactionIndex] = "#{cookieTransaction}".split '|'

    # Check for scenario filename
    scenarioFilename = cookieScenario

    unless scenarioFilename
      delete res.cookies.katt_scenario
      delete res.cookies.katt_transaction
      return @sendError res, 500, 'Please define a scenario'

    sessionID = res.cookies.katt_session_id = req.cookies.katt_session_id or (new Date().getTime())

    UID = sessionID + " # " + scenarioFilename
    context = req.context = @_contexts[UID] ?= {
      UID
      scenario: undefined
      transactionIndex: 0
      params: _.merge {}, @options.params or {},
        parseHost req.headers.host
    }

    # Check for scenario
    context.scenario = scenario = @_findScenarioByFilename scenarioFilename
    unless scenario?
      return @sendError res, 500, "Unknown scenario with filename #{scenarioFilename}"

    transactionIndex = @_middleware_resolveTransactionIndex req, res, transactionIndex

    unknownTransactionIndex = _.isNaN transactionIndex - 0
    unknownResetTransactionIndex = resetToTransactionIndex isnt undefined and _.isNaN resetToTransactionIndex - 0
    if unknownTransactionIndex or unknownResetTransactionIndex
      return @sendError res, 500, """
      Unknown transactions with filename #{scenarioFilename} - #{transactionIndex}|#{resetToTransactionIndex}
      """

    if resetToTransactionIndex?
      currentTransactionIndex = parseInt resetToTransactionIndex, 10
    else
      currentTransactionIndex = context.transactionIndex
    # Check for transaction index
    context.transactionIndex = parseInt transactionIndex, 10

    # Check if we're FFW transactions
    if context.transactionIndex > currentTransactionIndex
      mockedTransactionIndex = context.transactionIndex - 1
      for transactionIndex in [currentTransactionIndex..mockedTransactionIndex]
        context.transactionIndex = transactionIndex
        mockResponse = @_mockPlayTransactionIndex req, res

        return @sendError res, mockResponse.statusCode, mockResponse.body  if mockResponse.getHeader 'x-katt-error'

        nextTransactionIndex = context.transactionIndex
        logPrefix = "#{context.scenario.filename}\##{nextTransactionIndex}"
        transaction = context.scenario.blueprint.transactions[nextTransactionIndex - 1]

        # Validate response, so that we can continue with the request
        errors = []
        @validateResponse {
          actual: mockResponse
          expected: transaction.response
          params: context.params
          callbacks
          errors
        }
        if errors.length
          errors = JSON.stringify errors, null, 2
          return @sendError res, 403, "#{logPrefix} < Response does not match\n#{errors}"

        # Remember mockResponse cookies for next request
        do () ->
          for key, value of mockResponse.cookies
            req.cookies[key] = value

      context.transactionIndex = mockedTransactionIndex + 1
      req.url = @recallDeep context.scenario.blueprint.transactions[nextTransactionIndex].request.url, context.params

    # Play
    res.cookies['x-katt-dont-validate'] = ''  if req.cookies['x-katt-dont-validate']
    @_playTransactionIndex req, res


  _findScenarioByFilename: (scenarioFilename) ->
    scenario = @scenariosByFilename[scenarioFilename]
    return scenario  if scenario?
    for scenarioF, scenario of @scenariosByFilename
      endsWith = scenarioF.indexOf(scenarioFilename, scenarioF.length - scenarioFilename.length) isnt -1
      return scenario  if endsWith
    undefined


  _maybeSetContentLocation: (req, res) ->
    context = req.context
    transaction = context.scenario.blueprint.transactions[context.transactionIndex]

    return  unless transaction

    # maybe the request target has changed during the skipped transactions
    errors = []
    validateUrl {
      actual: req.url
      expected: transaction.request.url
      params: context.params
      callbacks
      errors
    }
    if errors?[0]?[0] is 'not_equal'
      intendedUrl = result[0][3]
      res.setHeader 'content-location', intendedUrl


  _mockPlayTransactionIndex: (req, res) ->
    context = req.context

    mockRequest = new MockRequest req

    nextTransactionIndex = context.transactionIndex + 1
    logPrefix = "#{context.scenario.filename}\##{nextTransactionIndex}"
    transaction = context.scenario.blueprint.transactions[nextTransactionIndex - 1]
    unless transaction
      return @sendError res, 403,
        "Transaction #{nextTransactionIndex} has not been defined in blueprint file for #{context.scenario.filename}"

    mockRequest.method = transaction.request.method
    mockRequest.url = @recallDeep transaction.request.url, context.params
    mockRequest.headers = @recallDeep(transaction.request.headers, context.params) or {}
    mockRequest.body = @recallDeep transaction.request.body, context.params

    mockResponse = new MockResponse()

    @_playTransactionIndex mockRequest, mockResponse

    mockResponse


  _dontValidate: (req, res) ->
    header = req.headers['x-katt-dont-validate']
    cookie = req.cookies['x-katt-dont-validate']
    header or cookie


  _playTransactionIndex: (req, res) ->
    context = req.context

    @_playTransactionIndex_modifyContext req, res

    nextTransactionIndex = context.transactionIndex + 1
    logPrefix = "#{context.scenario.filename}\##{nextTransactionIndex}"
    transaction = context.scenario.blueprint.transactions[nextTransactionIndex - 1]
    unless transaction
      return @sendError res, 403,
        "Transaction #{nextTransactionIndex} has not been defined in blueprint file for #{context.scenario.filename}"

    context.transactionIndex = nextTransactionIndex

    if @_dontValidate req, res
      @_maybeSetContentLocation req, res
    else
      errors = []
      actualRequest = _.cloneDeep {
        method: req.method
        url: req.url
        headers: req.headers
        body: req.body
      }
      actualRequest.body = callbacks.parse {
        headers: normalizeHeaders actualRequest.headers
        body: actualRequest.body
      }
      expectedRequest = _.cloneDeep transaction.request
      do () =>
        for key, value of expectedRequest
          expectedRequest[key] = @recallDeep value, context.params
      expectedRequest.body = callbacks.parse {
        headers: normalizeHeaders expectedRequest.headers
        body: expectedRequest.body
      }
      @validateRequest {
        actual: actualRequest
        expected: expectedRequest
        params: context.params
        callbacks
        errors
      }
      if errors.length
        errors = JSON.stringify errors, null, 2
        return @sendError res, 403, "#{logPrefix} < Request does not match\n#{errors}"

    res.cookies.katt_scenario = context.scenario.filename
    res.cookies.katt_transaction = context.transactionIndex

    headers = @recallDeep(_.cloneDeep(transaction.response.headers), context.params) or {}
    res.body = @recallDeep _.cloneDeep(transaction.response.body), context.params

    res.statusCode = transaction.response.status
    res.setHeader header, headerValue  for header, headerValue of headers

    @callback 'preSend', req, res, () =>
      contentType = _.find res.headers, (header) -> header.toLowerCase() is 'content-type'
      res.body = JSON.stringify(res.body, null, 2)  if isJsonCT contentType
      res.send res.body
      @callback 'postSend', req, res

    true


  recallDeep: (input, params) =>
    if _.isString input
      input = input.replace /{{>/g, '{{<'
      callbacks.recall {input, params}
    else
      input[key] = @recallDeep input[key], params  for key in _.keys input
      input


  callback: (name, req, res, next) ->
    if @options.callbacks[name]?
      @options.callbacks[name] req, res, next
    else
      next()  if next?


  sendError: (res, statusCode, error) ->
    res.setHeader 'Content-Type', 'text/plain'
    res.setHeader 'X-KATT-Error', encodeURIComponent error.split('\n').shift()
    res.send statusCode, error


  validateReqRes: ({actual, expected, params, callbacks, errors}) ->
    errors ?= []

    if @options.check.headers
      validateHeaders {
        actual: actual.headers
        expected: expected.headers
        params
        callbacks
        errors
      }
    if @options.check.body
      validateBody {
        actual: actual.body
        expected: expected.body
        params
        callbacks
        errors
      }
    errors


  validateRequest: ({actual, expected, params, callbacks, errors}) ->
    errors ?= []
    if @options.check.method
      validateMethod {
        actual: actual.method.toUpperCase()
        expected: expected.method.toUpperCase()
        params
        callbacks
        errors
      }
    validateUrl {
      actual: actual.url
      expected: expected.url
      params
      callbacks
      errors
    }
    @validateReqRes {
      actual
      expected
      params
      callbacks
      errors
    }
    errors


  validateResponse: ({actual, expected, params, callbacks, errors}) ->
    errors ?= []
    validateStatusCode {
      actual: actual.statusCode.toString()
      expected: expected.status.toString()
      params
      callbacks
      errors
    }
    @validateReqRes {
      actual
      expected
      params
      callbacks
      errors
    }
    errors
