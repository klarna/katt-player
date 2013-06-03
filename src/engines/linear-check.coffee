fs = require 'fs'
path = require 'path'
url = require 'url'
glob = require 'glob'
_ = require 'lodash'
blueprintParser = require 'katt-blueprint-parser'
katt = require '../katt'
MockResponse = require '../mock-response'
MockRequest = require '../mock-request'


GLOB_OPTIONS =
  nosort: true
  stat: false


module.exports = class LinearCheckEngine
  options: undefined
  _contexts: undefined
  _modifyContext: () ->

  constructor: (scenarios, options = {}) ->
    return new LinearCheckEngine(scenarios, options)  unless this instanceof LinearCheckEngine
    @scenariosByFilename = {}
    @_contexts =
      UID:
        UID: undefined
        scenario: undefined
        operationIndex: undefined
        vars: undefined
    @options = _.merge options, {
      default:
        scenario: undefined
        operation: 0
      hooks:
        preSend: undefined
        postSend: undefined
      check:
        url: true
        method: true
        headers: true
        body: true
    }
    @server =
      hostname: options.hostname
      port: options.port
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
    # FIXME better idea? proxies might rewrite the path
    if /scenarios\.json/.test req.url
      @middleware_json req, res, next
    else
      @middleware_scenario req, res, next


  middleware_json: (req, res, next) ->
    res.setHeader 'Content-Type', 'application/json'
    res.body = JSON.stringify @scenariosByFilename, null, 2
    res.send 200, res.body


  middleware_scenario: (req, res, next) ->
    cookieScenario = req.cookies.katt_scenario or @options.default.scenario
    cookieOperation = req.cookies.katt_operation or @options.default.operation
    [operationIndex, resetToOperationIndex] = "#{cookieOperation}".split '|'

    # Check for scenario filename
    scenarioFilename = cookieScenario

    unless scenarioFilename
      res.cookies.katt_scenario = undefined
      res.cookies.katt_operation = undefined
      return @sendError res, 500, 'Please define a scenario'

    UID = req.sessionID + " # " + scenarioFilename
    context = req.context = @_contexts[UID] or (@_contexts[UID] = {
      UID
      scenario: undefined
      operationIndex: 0
      vars: @options.vars or {}
    })

    # Check for scenario
    context.scenario = scenario = @scenariosByFilename[scenarioFilename]
    unless scenario?
      return @sendError res, 500, "Unknown scenario with filename #{scenarioFilename}"

    # FIXME this is not really the index, it's the reference point (the last operation step), so please rename
    if resetToOperationIndex?
      currentOperationIndex = parseInt resetToOperationIndex, 10
    else
      currentOperationIndex = context.operationIndex
    # Check for operation index
    context.operationIndex = parseInt operationIndex, 10

    # FIXME if context.operationIndex < currentOperationIndex, then it means we went back in time
    # and it might be better to clear the context.vars

    # Check if we're FFW operations
    if context.operationIndex > currentOperationIndex
      mockedOperationIndex = context.operationIndex - 1
      for operationIndex in [currentOperationIndex..mockedOperationIndex]
        context.operationIndex = operationIndex
        mockResponse = @_mockPlayOperationIndex req, res

        return @sendError res, mockResponse.statusCode, mockResponse.body  if mockResponse.getHeader 'x-katt-error'

        nextOperationIndex = context.operationIndex
        logPrefix = "#{context.scenario.filename}\##{nextOperationIndex}"
        operation = context.scenario.blueprint.operations[nextOperationIndex - 1]

        # Validate response, so that we can continue with the request
        result = []
        @validateResponse mockResponse, operation.response, context.vars, result
        if result.length
          result = JSON.stringify result, null, 2
          return @sendError res, 403, "#{logPrefix} < Response does not match\n#{result}"

        # Remember mockResponse cookies for next request
        do () ->
          for key, value of mockResponse.cookies
            req.cookies[key] = value

      context.operationIndex = mockedOperationIndex + 1
      @_maybeSetContentLocation req, res

    # Play
    @_playOperationIndex req, res


  _maybeSetContentLocation: (req, res) ->
    context = req.context
    operation = context.scenario.blueprint.operations[context.operationIndex]

    # maybe the request target has changed during the skipped operations
    result = katt.validateURL req.url, operation.request.url, context.vars
    if result?[0]?[0] is 'not_equal'
      intendedUrl = result[0][3]
      res.setHeader 'content-location', intendedUrl


  _mockPlayOperationIndex: (req, res) ->
    context = req.context

    mockRequest = new MockRequest req

    nextOperationIndex = context.operationIndex + 1
    logPrefix = "#{context.scenario.filename}\##{nextOperationIndex}"
    operation = context.scenario.blueprint.operations[nextOperationIndex - 1]
    unless operation
      return @sendError res, 403,
        "Operation #{nextOperationIndex} has not been defined in blueprint file for #{context.scenario.filename}"

    mockRequest.method = operation.request.method
    mockRequest.url = @recallDeep operation.request.url, context.vars
    mockRequest.headers = @recallDeep(operation.request.headers, context.vars) or {}
    mockRequest.body = @recallDeep operation.request.body, context.vars
    # FIXME special treat for cookies (sync req.cookies with Cookie header)

    mockResponse = new MockResponse()

    @_playOperationIndex mockRequest, mockResponse

    mockResponse


  _playOperationIndex: (req, res) ->
    context = req.context

    @_modifyContext req, res

    nextOperationIndex = context.operationIndex + 1
    logPrefix = "#{context.scenario.filename}\##{nextOperationIndex}"
    operation = context.scenario.blueprint.operations[nextOperationIndex - 1]
    unless operation
      return @sendError res, 403,
        "Operation #{nextOperationIndex} has not been defined in blueprint file for #{context.scenario.filename}"

    context.operationIndex = nextOperationIndex

    if req.headers['x-katt-dont-validate']
      @_maybeSetContentLocation req, res
    else
      result = []
      @validateRequest req, operation.request, context.vars, result
      if result.length
        result = JSON.stringify result, null, 2
        return @sendError res, 403, "#{logPrefix} < Request does not match\n#{result}"

    res.cookies.katt_scenario = context.scenario.filename
    res.cookies.katt_operation = context.operationIndex

    headers = @recallDeep(operation.response.headers, context.vars) or {}
    res.body = @recallDeep operation.response.body, context.vars

    res.statusCode = operation.response.status
    res.setHeader header, headerValue  for header, headerValue of headers

    @callHook 'preSend', req, res, () =>
      res.body = JSON.stringify(res.body, null, 2)  if katt.isJsonBody res
      res.send res.body
      @callHook 'postSend', req, res

    true


  recallDeep: (value, vars) =>
    if _.isString value
      value = value.replace /{{>/g, '{{<'
      katt.recall value, vars
    else
      value[key] = @recallDeep value[key], vars  for key in _.keys value
      value


  callHook: (name, req, res, next = ->) ->
    if @options.hooks[name]?
      @options.hooks[name] req, res, next
    else
      next()


  sendError: (res, statusCode, error) ->
    res.setHeader 'Content-Type', 'text/plain'
    res.setHeader 'X-KATT-Error', encodeURIComponent error.split('\n').shift()
    res.send statusCode, error


  validateReqRes: (actualReqRes, expectedReqRes, vars = {}, result = []) ->
    headerResult = []
    headersResult = katt.validateHeaders actualReqRes.headers, expectedReqRes.headers, vars  if @options.check.headers
    result.push.apply result, headersResult  if headersResult.length

    actualReqResBody = katt.maybeJsonBody actualReqRes
    bodyResult = []
    bodyResult = katt.validateBody actualReqResBody, expectedReqRes.body, vars  if @options.check.body
    result.push.apply result, bodyResult  if bodyResult.length

    result


  validateRequest: (actualRequest, expectedRequest, vars = {}, result = []) ->
    methodResult = []
    methodResult = katt.validate 'method', actualRequest.method, expectedRequest.method, vars  if @options.check.method
    result.push.apply result, methodResult  if methodResult.length

    urlResult = []
    urlResult = katt.validateURL actualRequest.url, expectedRequest.url, vars
    result.push.apply result, urlResult  if urlResult.length

    @validateReqRes actualRequest, expectedRequest, vars, result

    result


  validateResponse: (actualResponse, expectedResponse, vars = {}, result = []) ->
    statusResult = []
    statusResult = katt.validate 'status', actualResponse.statusCode, expectedResponse.status, vars
    result.push.apply result, statusResult  if statusResult.length

    @validateReqRes actualResponse, expectedResponse, vars, result

    result
