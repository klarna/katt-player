fs = require 'fs'
_ = require 'lodash'
blueprintParser = require 'katt-blueprint-parser'
#Blueprint = require('katt-blueprint-parser').ast.Blueprint

module.exports = (app) ->
  contexts =
    sessionID:
      blueprint: undefined
      scenario: undefined
      operation: undefined


  app.use (req, res, next) ->
    unless req.cookies?.katt_scenario?
      res.clearCookie 'katt_scenario'
      res.clearCookie 'katt_operation'
      return next()

    context = contexts[req.sessionID] or {}
    try
      if req.cookies?.katt_scenario? and (not context?.scenario? or context.scenario isnt req.cookies.katt_scenario)
        scenario = req.cookies.katt_scenario
        blueprint = app.scenarios[scenario]
        throw new Error("Unable to find blueprint file for scenario #{scenario}")  unless blueprint?
        blueprintObj = blueprintParser.parse fs.readFileSync blueprint, 'utf8'

        context = contexts[req.sessionID] = {
          scenario
          blueprint
          blueprintObj
          operation: req.cookies.katt_operation or -1
        }
        # FIXME refresh vars
    catch e
      return res.send 500, "Unable to find/parse blueprint file #{context.blueprint} for scenario #{context.scenario}\n#{e}"
    res.locals.context = context
    next()


  (req, res, next) ->
    context = res.locals.context
    return res.send 500, 'Please define a scenario first'  unless context?.scenario
    nextOperation = context.operation + 1

    operation = context.blueprintObj.operations[nextOperation]
    return res.send 500, "Operation #{nextOperation} has not been defined in blueprint file #{context.blueprint} for #{context.scenario}"  unless operation

    context.operation = nextOperation

    return 404  unless req.url is operation.url
    # FIXME check if request headers and body match operation.request

    # res.cookie katt_scenario, context.scenario
    res.cookie 'katt_operation', context.operation

    res.status operation.response.status
    res.set header, headerValue  for header, headerValue of operation.response.headers
    res.send operation.response.body
