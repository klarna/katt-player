fs = require 'fs'
_ = require 'lodash'
katt = require '../katt'
blueprintParser = require 'katt-blueprint-parser'
#Blueprint = require('katt-blueprint-parser').ast.Blueprint

module.exports = class linearCheckEngine
  options: undefined
  _app: undefined
  _winston: undefined
  _contexts: undefined


  constructor: (app, options = {}) ->
    return new linearCheckEngine(app, options)  unless this instanceof linearCheckEngine
    @_app = app
    @_winston = @_app.winston
    @_contexts =
      sessionID:
        scenario: undefined
        operationIndex: undefined
        vars: undefined
    @options = _.merge options, {
      hooks:
        preSend: undefined
        postSend: undefined
      check:
        url: true
        method: true
        headers: true
        body: true
    }, _.defaults


  middleware: (req, res, next) =>
    unless req.cookies?.katt_scenario?
      res.clearCookie 'katt_scenario'
      res.clearCookie 'katt_operation'
      return @sendError res, 500, 'Please define a scenario'

    context = @_contexts[req.sessionID] or {}

    scenario_id = req.cookies?.katt_scenario
    if scenario_id? and (not context.scenario? or context.scenario?.id isnt scenario_id)
      scenario = @_app.scenariosById[scenario_id] or @_app.scenariosByFilename[scenario_id]
      return @sendError res, 500, "Unknown scenario #{scenario_id}"  unless scenario?
      try
        blueprint = scenario.blueprint or= blueprintParser.parse fs.readFileSync scenario.filename, 'utf8'
        for operation in blueprint.operations
          operation.request.headers = katt.normalizeHeaders operation.request.headers
          operation.request.body = @maybeJsonBody operation.request  if operation.request.body?
          operation.response.headers = katt.normalizeHeaders operation.response.headers
          operation.response.body = @maybeJsonBody operation.response  if operation.response.body?
      catch e
        return @sendError res, 500, "Unable to find/parse blueprint file #{scenario.filename} for scenario #{scenario.id}\n#{e}"

      context = @_contexts[req.sessionID] = {
        scenario
        operationIndex: Number(req.cookies.katt_operation) or 0
        vars: {}
      }
    # FIXME refresh vars

    nextOperationIndex = context.operationIndex + 1
    logPrefix = "#{context.scenario.filename}\##{nextOperationIndex} - "
    @_winston.info "#{logPrefix}#{req.method} #{req.url}"

    operation = context.scenario.blueprint.operations[nextOperationIndex-1]
    return @sendError res, 403, "Operation #{nextOperationIndex} has not been defined in blueprint file #{context.scenario.filename} for #{context.scenario.id}"  unless operation

    context.operationIndex = nextOperationIndex

    result = []
    @validateRequest req, operation.request, context.vars, result
    if result.length
      result = JSON.stringify result, null, 2
      return @sendError res, 403, "#{logPrefix}Request does not match\n#{result}"

    @_winston.info "#{logPrefix}OK"

    res.cookie 'katt_scenario', context.scenario.id
    res.cookie 'katt_operation', context.operationIndex

    headers = katt.extractDeep(operation.response.headers, context.vars) or {}
    res.body = katt.extractDeep operation.response.body, context.vars

    res.status operation.response.status
    res.set header, headerValue  for header, headerValue of headers

    @callHook 'preSend', context, req, res, () =>
      res.send res.body
      @callHook 'postSend', context, req, res


  callHook: (name, context, req, res, next) ->
    next or= () ->
    if @options.hooks[name]?
      @options.hooks[name] context, req, res, next
    else
      next()


  maybeJsonBody: (reqres) ->
    if katt.isJsonBody reqres
      try
        return JSON.parse reqres.body
      catch e
    reqres.body


  sendError: (res, status, error) ->
    @_winston.error error
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

    actualRequestBody = @maybeJsonBody actualRequest
    bodyResult = []
    bodyResult = @options.check.body ? katt.validateBody actualRequestBody, expectedRequest.body, vars
    result = result.concat bodyResult  if bodyResult.length

    result
