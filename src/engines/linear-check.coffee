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
BasicEngine = require './basic'

module.exports = class LinearCheckEngine extends BasicEngine
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
      hooks:
        preSend: undefined
        postSend: undefined
      check:
        url: true
        method: true
        headers: true
        body: true
    }
    super


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

    # TODO: options.params has to supply host, hostname & port to override correctly
    # we should parse host for options as well
    UID = sessionID + " # " + scenarioFilename
    context = req.context = @_contexts[UID] ?= {
      UID
      scenario: undefined
      transactionIndex: 0
      params: _.merge (parseHost req.headers.host), (@options.params or {})
    }

    # Check for scenario
    context.scenario = scenario = @_findScenarioByFilename scenarioFilename
    unless scenario?
      return @sendError res, 500, "Unknown scenario with filename #{scenarioFilename}"

    transactionIndex = @_middleware_resolveTransactionIndex req, res, transactionIndex

    unknownTransactionIndex = _.isNaN(transactionIndex - 0)
    unknownResetTransactionIndex = resetToTransactionIndex? and _.isNaN(resetToTransactionIndex - 0)
    if unknownTransactionIndex or unknownResetTransactionIndex
      return @sendError res, 500, """
Unknown transactions with filename #{scenarioFilename} - #{transactionIndex}|#{resetToTransactionIndex}
      """

    if resetToTransactionIndex?
      currentTransactionIndex = resetToTransactionIndex = parseInt resetToTransactionIndex, 10
    else
      currentTransactionIndex = context.transactionIndex
    # Check for transaction index
    context.transactionIndex = transactionIndex = parseInt transactionIndex, 10

    isOutOfBounds = (i) ->
      i not in [0..context.scenario.blueprint.transactions.length - 1]

    outOfBoundsTransactionIndex = isOutOfBounds(transactionIndex)
    outOfBoundsResetTransactionIndex = resetToTransactionIndex? and isOutOfBounds(resetToTransactionIndex)
    if outOfBoundsTransactionIndex or outOfBoundsResetTransactionIndex
      return @sendError res, 500, """
      Out of bound transactions with filename #{scenarioFilename} - #{transactionIndex}|#{resetToTransactionIndex}
      """

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

        # Remember mockResponse cookies for next request
        do () ->
          for key, value of mockResponse.cookies
            req.cookies[key] = value

      context.transactionIndex = mockedTransactionIndex + 1
      req.url = @recallDeep context.scenario.blueprint.transactions[nextTransactionIndex].request.url, context.params

    # Play
    req.body = callbacks.parse {
      headers: normalizeHeaders req.headers
      body: req.body
    }
    res.cookies['katt_dont_validate'] = ''  if req.cookies['katt_dont_validate']
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
    cookie = req.cookies['katt_dont_validate']
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
      @validateRequest {
        actual: req
        expected: transaction.request
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
    @sendResponse req, res

    true


  recallDeep: (input, params) =>
    if _.isString input
      input = input.replace /{{>/g, '{{<'
      callbacks.recall {input, params}
    else
      input[key] = @recallDeep input[key], params  for key in _.keys input
      input


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
    actual = _.cloneDeep {
      method: actual.method
      url: actual.url
      headers: actual.headers
      body: actual.body
    }
    expected = _.cloneDeep expected
    do () =>
      for key, value of expected
        expected[key] = @recallDeep value, params

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
