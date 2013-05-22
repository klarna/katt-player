fs = require 'fs'
path = require 'path'
glob = require 'glob'
_ = require 'lodash'
katt = require '../katt'
blueprintParser = require 'katt-blueprint-parser'


GLOB_OPTIONS =
  nosort: true
  stat: false


module.exports = class LinearCheckEngine
  options: undefined
  _contexts: undefined
  _modifyContext: -> # to please isak 2013-04-29 /andrei

  constructor: (scenarios, options = {}) ->
    return new LinearCheckEngine(scenarios, options)  unless this instanceof LinearCheckEngine
    @scenariosByFilename = {}
    @_contexts =
      sessionID:
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
    for scenario in scenarios
      continue  unless fs.existsSync scenario
      scenario = path.normalize scenario

      if fs.statSync(scenario).isDirectory()
        apibs = glob.sync "#{scenario}/**/*.apib", GLOB_OPTIONS
        @loadScenarios apibs
      else if fs.statSync(scenario).isFile()
        @loadScenario scenario


  middleware: (req, res, next) =>
    context = @_contexts[req.sessionID] or {}

    req.cookies.katt_scenario or= @options.default.scenario
    req.cookies.katt_operation or= @options.default.operation

    unless req.cookies?.katt_scenario?
      res.clearCookie 'katt_scenario', path: '/'
      res.clearCookie 'katt_operation', path: '/'
      return @sendError res, 500, 'Please define a scenario'

    scenarioFilename = req.cookies?.katt_scenario
    scenario = @scenariosByFilename[scenarioFilename]

    isNewScenario = not context.scenario? or context.scenario?.filename isnt scenarioFilename
    if isNewScenario
      return @sendError res, 500, "Unknown scenario #{scenarioFilename}"  unless scenario?
      blueprint = scenario.blueprint

      context = @_contexts[req.sessionID] = {
        scenario
        operationIndex: Number(req.cookies.katt_operation) or 0
        vars: {}
      }
    # FIXME refresh vars

    req.context = context

    @_modifyContext req, res

    nextOperationIndex = context.operationIndex + 1
    logPrefix = "#{context.scenario.filename}\##{nextOperationIndex}"

    operation = context.scenario.blueprint.operations[nextOperationIndex - 1]
    unless operation
      return @sendError res, 403,
        "Operation #{nextOperationIndex} has not been defined in blueprint file for #{context.scenario.filename}"

    context.operationIndex = nextOperationIndex

    result = []
    @validateRequest req, operation.request, context.vars, result
    if result.length
      result = JSON.stringify result, null, 2
      return @sendError res, 403, "#{logPrefix} < Request does not match\n#{result}"

    res.cookie 'katt_scenario', context.scenario.filename, path: '/'
    res.cookie 'katt_operation', context.operationIndex, path: '/'

    headers = @recallDeep(operation.response.headers, context.vars) or {}
    res.body = @recallDeep operation.response.body, context.vars

    res.status operation.response.status
    res.set header, headerValue  for header, headerValue of headers

    @callHook 'preSend', req, res, () =>
      res.body = JSON.stringify(res.body, null, 4)  if katt.isJsonBody res
      res.send res.body
      @callHook 'postSend', req, res


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


  sendError: (res, status, error) ->
    res.set 'Content-Type', 'text/plain'
    res.send status, error


  validateRequest: (actualRequest, expectedRequest, vars = {}, result = []) ->
    urlResult = []
    urlResult = @options.check.url ? katt.validate 'url', actualRequest.url, expectedRequest.url, vars
    result = result.concat urlResult  if urlResult.length

    methodResult = []
    methodResult = @options.check.method ? katt.validate 'method', actualRequest.method, expectedRequest.method, vars
    result = result.concat methodResult  if methodResult.length

    headerResult = []
    headersResult = @options.check.headers ? katt.validateHeaders actualRequest.headers, expectedRequest.headers, vars
    result = result.concat headersResult  if headersResult.length

    actualRequestBody = katt.maybeJsonBody actualRequest
    bodyResult = []
    bodyResult = @options.check.body ? katt.validateBody actualRequestBody, expectedRequest.body, vars
    result = result.concat bodyResult  if bodyResult.length

    result
