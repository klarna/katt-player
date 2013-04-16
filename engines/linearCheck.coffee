fs = require 'fs'
_ = require 'lodash'
katt = require '../katt'
blueprintParser = require 'katt-blueprint-parser'
#Blueprint = require('katt-blueprint-parser').ast.Blueprint

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
    res.send status, error

  app.use (req, res, next) ->
    unless req.cookies?.katt_scenario?
      res.clearCookie 'katt_scenario'
      res.clearCookie 'katt_operation'
      return sendError res, 500, 'Please define a scenario'

    context = contexts[req.sessionID] or {}
    try
    if req.cookies?.katt_scenario? and (not context?.scenario? or context.scenario isnt req.cookies.katt_scenario)
      scenario = req.cookies.katt_scenario
      blueprint = app.scenarios[scenario]
      return sendError res, 500, "Unable to find blueprint file for scenario #{scenario}"  unless blueprint?
      try
        blueprintObj = blueprintParser.parse fs.readFileSync blueprint, 'utf8'
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
    # FIXME check if request headers and body match operation.request

    headersDiff = if ignore.headers then [] else katt.makeHeadersDiff req.headers, operation.request.headers
    return sendError res, 400, "#{logPrefix}Request headers do not match\n#{headersDif}"  if headersDiff?.length

    bodyDiff = if ignore.body then [] else katt.makeBodyDiff req.body, operation.request.body
    return sendError res, 400, "#{logPrefix}Request Headers/Body do not match\n#{bodyDif}"  if bodyDiff?.length

    winston.info "#{logPrefix}OK"

    # res.cookie katt_scenario, context.scenario
    res.cookie 'katt_operation', context.operation

    res.status operation.response.status
    res.set header, headerValue  for header, headerValue of operation.response.headers
    res.send operation.response.body
