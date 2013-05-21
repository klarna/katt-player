fs = require 'fs'
path = require 'path'
glob = require 'glob'
express = require 'express'
katt = require './katt'


globOptions =
  nosort: true
  stat: false


# Maintain compatibility with express2
enableExpressCompatibilityMode = (req, res) ->
  req.get or= (header)        -> req.header header
  res.get or= (header)        -> res.header header
  req.set or= (header, value) -> req.header header, value
  res.set or= (header, value) -> res.header header, value

  originalSend = res.send

  res.send = (statusCode, body) ->
    if typeof statusCode is 'number'
      res.statusCode = statusCode
    else
      # no statusCode sent, just maybe body
      body = statusCode
    originalSend.call res, body


 class KattPlayer
  self = this

  @engines =
    linear:       require './engines/linear'
    linearCheck:  require './engines/linear-check'
    checkout:     require './engines/checkout'

  @hasEngine = (engine) -> !!self.engines[engine]
  @getEngine = (engine) -> self.engines[engine]


  constructor: (app, engine, options = {}) ->
    @_constructor(options.scenarios)

    app.katt = this
    app.engine = engine
    app.use express.bodyParser()
    app.use express.cookieParser()
    app.use express.session
      secret: 'Lorem ipsum dolor sit amet.'

    app.use (req, res, next) ->
      enableExpressCompatibilityMode req, res
      # TODO REMOVE ASAP
      engine.middleware req, res, next
    app


  _constructor: (scenarios = []) ->
    @scenariosByFilename = {}
    @loadScenarios(scenarios)  if scenarios

  loadScenario: (filename) ->
    try
      blueprint = katt.readScenario filename
    catch e
      throw new Error "Unable to find/parse blueprint file for scenario #{filename}\n#{e}"
    @scenariosByFilename[filename] = {
      filename
      blueprint
    }

  loadScenarios: (scenarios) ->
    for scenario in scenarios
      continue  unless fs.existsSync scenario
      scenario = path.normalize scenario

      if fs.statSync(scenario).isDirectory()
        apibs = glob.sync "#{scenario}/**/*.apib", globOptions
        @loadScenarios apibs
      else if fs.statSync(scenario).isFile()
        @loadScenario scenario


module.exports = KattPlayer
