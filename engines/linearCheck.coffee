fs = require 'fs'
_ = require 'lodash'
katt = require '../katt'
blueprintParser = require 'katt-blueprint-parser'
#Blueprint = require('katt-blueprint-parser').ast.Blueprint

maybeJsonBody = (reqres) ->
  if /\bjson\b/.test(reqres.headers['content-type'] or '')
    try
      return JSON.parse reqres.body
    catch e
  reqres.body

module.exports = (app, ignore = {}) ->
  winston = app.winston
  contexts =
    sessionID:
      blueprint: undefined
      scenario: undefined
      operation: undefined
  _.defaults ignore,
    url: false
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
    if req.cookies?.katt_scenario? and (not context?.scenario? or context.scenario isnt req.cookies.katt_scenario)
      scenario = req.cookies.katt_scenario
      blueprint = app.scenarios[scenario]
      return sendError res, 500, "Unable to find blueprint file for scenario #{scenario}"  unless blueprint?
      try
        blueprintObj = blueprintParser.parse fs.readFileSync blueprint, 'utf8'
        for operation in blueprintObj.operations
          operation.request.headers = katt.normalizeHeaders operation.request.headers
          operation.request.body = maybeJsonBody operation.request  if operation.request.body?
          operation.response.headers = katt.normalizeHeaders operation.response.headers
          operation.response.body = maybeJsonBody operation.response  if operation.response.body?
      catch e
        return sendError res, 500, "Unable to parse blueprint file #{context.blueprint} for scenario #{context.scenario}\n#{e}"

      context = contexts[req.sessionID] = {
        scenario
        blueprint
        blueprintObj
        operation: req.cookies.katt_operation or 0
      }
    # FIXME refresh vars
    res.locals.context = context
    next()


  (req, res, next) ->
    context = res.locals.context
    nextOperation = context.operation + 1
    logPrefix = "#{context.scenario}\##{nextOperation} - "
    winston.info "#{logPrefix}#{req.method} #{req.url}"

    operation = context.blueprintObj.operations[nextOperation-1]
    return sendError res, 500, "Operation #{nextOperation} has not been defined in blueprint file #{context.blueprint} for #{context.scenario}"  unless operation

    context.operation = nextOperation

    return res.send 404  unless ignore.url or req.url is operation.url

    headersDiff = if ignore.headers then [] else katt.validateHeaders req.headers, operation.request.headers
    if headersDiff?.length
      headersDiff = JSON.stringify headersDiff, null, 2
      return sendError res, 400, "#{logPrefix}Request headers do not match\n#{headersDiff}"

    reqBody = maybeJsonBody req
    bodyDiff = if ignore.body then [] else katt.validateBody reqBody, operation.request.body
    if bodyDiff?.length
      bodyDiff = JSON.stringify bodyDiff, null, 2
      return sendError res, 400, "#{logPrefix}Request Headers/Body do not match\n#{bodyDiff}"

    winston.info "#{logPrefix}OK"

    # res.cookie katt_scenario, context.scenario
    res.cookie 'katt_operation', context.operation

    res.status operation.response.status
    res.set header, headerValue  for header, headerValue of operation.response.headers
    res.send operation.response.body
