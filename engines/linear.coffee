fs = require 'fs'
_ = require 'lodash'
blueprintParser = require 'katt-blueprint-parser'
#Blueprint = require('katt-blueprint-parser').ast.Blueprint

module.exports = (app, winston) ->
  contexts =
    sessionID:
      blueprint: undefined
      scenario: undefined
      operation: undefined

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
    winston.info "#{context.scenario}\##{nextOperation} - #{req.method} #{req.url}"

    operation = context.blueprintObj.operations[nextOperation-1]
    return sendError res, 500, "Operation #{nextOperation} has not been defined in blueprint file #{context.blueprint} for #{context.scenario}"  unless operation

    context.operation = nextOperation

    return res.send 404  unless req.url is operation.url
    # FIXME check if request headers and body match operation.request

    winston.info "#{context.scenario}\##{nextOperation} - OK"

    # res.cookie katt_scenario, context.scenario
    res.cookie 'katt_operation', context.operation

    res.status operation.response.status
    res.set header, headerValue  for header, headerValue of operation.response.headers
    res.send operation.response.body
