fs = require 'fs'
_ = require 'lodash'
katt = require '../katt'
blueprintParser = require 'katt-blueprint-parser'
#Blueprint = require('katt-blueprint-parser').ast.Blueprint

maybeJsonBody = (reqres) ->
  if katt.isJsonBody reqres
    try
      return JSON.parse reqres.body
    catch e
  reqres.body

validateRequest = (actualRequest, expectedRequest, vars = {}, result = [], ignore = {}) ->
  urlResult = if ignore.url then [] else katt.validate 'url', actualRequest.url, expectedRequest.url, vars
  result = result.concat urlResult  if urlResult.length

  methodResult = if ignore.method then [] else katt.validate 'method', actualRequest.method, expectedRequest.method, vars
  result = result.concat methodResult  if methodResult.length

  headersResult = if ignore.headers then [] else katt.validateHeaders actualRequest.headers, expectedRequest.headers, vars
  result = result.concat headersResult  if headersResult.length

  actualRequestBody = maybeJsonBody actualRequest
  bodyResult = if ignore.body then [] else katt.validateBody actualRequestBody, expectedRequest.body, vars
  result = result.concat bodyResult  if bodyResult.length

  result

module.exports = (app, ignore = {}) ->
  winston = app.winston
  contexts =
    sessionID:
      scenario: undefined
      operationIndex: undefined
      vars: undefined
  _.defaults ignore,
    url: false
    method: false
    headers: false
    body: false

  sendError = (res, status, error) ->
    winston.error error
    res.set 'Content-Type', 'text/plain'
    res.send status, error

  app.use (req, res, next) ->
    unless req.cookies?.katt_scenario?
      res.clearCookie 'katt_scenario'
      res.clearCookie 'katt_operation'
      return sendError res, 500, 'Please define a scenario'

    context = contexts[req.sessionID] or {}
    scenario_id = req.cookies?.katt_scenario
    if scenario_id? and (not context.scenario? or context.scenario?.id isnt scenario_id)
      scenario = app.scenarios[scenario_id]
      return sendError res, 500, "Unknown scenario #{scenario_id}"  unless scenario?
      try
        blueprint = scenario.blueprint or= blueprintParser.parse fs.readFileSync scenario.filename, 'utf8'
        for operation in blueprint.operations
          operation.request.headers = katt.normalizeHeaders operation.request.headers
          operation.request.body = maybeJsonBody operation.request  if operation.request.body?
          operation.response.headers = katt.normalizeHeaders operation.response.headers
          operation.response.body = maybeJsonBody operation.response  if operation.response.body?
      catch e
        return sendError res, 500, "Unable to find/parse blueprint file #{scenario.filename} for scenario #{scenario.filename}\n#{e}"

      context = contexts[req.sessionID] = {
        scenario
        operationIndex: req.cookies.katt_operation or 0
        vars: {}
      }
    # FIXME refresh vars
    res.locals.context = context
    next()


  (req, res, next) ->
    context = res.locals.context
    nextOperationIndex = context.operationIndex + 1
    logPrefix = "#{context.scenario.filename}\##{nextOperationIndex} - "
    winston.info "#{logPrefix}#{req.method} #{req.url}"

    operation = context.scenario.blueprint.operations[nextOperationIndex-1]
    return sendError res, 403, "Operation #{nextOperationIndex} has not been defined in blueprint file #{context.scenario.filename} for #{context.scenario.id}"  unless operation

    context.operationIndex = nextOperationIndex

    result = []
    validateRequest req, operation.request, context.vars, result, ignore
    if result.length
      result = JSON.stringify result, null, 2
      return sendError res, 403, "#{logPrefix}Request does not match\n#{result}"

    winston.info "#{logPrefix}OK"

    res.cookie 'katt_scenario', context.scenario.id
    res.cookie 'katt_operation', context.operationIndex

    headers = katt.extractDeep(operation.response.headers, context.vars) or {}
    body = katt.extractDeep operation.response.body, context.vars

    res.status operation.response.status
    res.set header, headerValue  for header, headerValue of headers
    res.send body
