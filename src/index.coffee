fs = require 'fs'
path = require 'path'
glob = require 'glob'
express = require 'express'
katt = require './katt'


globOptions =
  nosort: true
  stat: false


kattPlayer = (app, engine, options = {}) ->
  # NOTE maintain compatibility with express2
  scenarios = options.scenarios or= []
  scenariosByFilename = {}
  app.katt = {
    scenariosByFilename
  }

  loadScenario = (filename) ->
    try
      blueprint = katt.readScenario filename
    catch e
      throw new Error "Unable to find/parse blueprint file for scenario #{filename}\n#{e}"
    scenariosByFilename[filename] = {
      filename
      blueprint
    }

  app.katt.load = (scenarios) ->
    for scenario in scenarios
      continue  unless fs.existsSync scenario
      scenario = path.normalize scenario

      if fs.statSync(scenario).isDirectory()
        apibs = glob.sync "#{scenario}/**/*.apib", globOptions
        app.katt.load apibs
      else if fs.statSync(scenario).isFile()
        loadScenario scenario
  app.katt.load scenarios  if scenarios?.length

  app.engine = engine
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session
    secret: 'Lorem ipsum dolor sit amet.'
  app.use (req, res, next) ->
    # NOTE maintain compatibility with express2
    req.get or= (header) -> req.header header
    res.get or= (header) -> res.header header
    req.set or= (header, value) -> req.header header, value
    res.set or= (header, value) -> res.header header, value
    originalSend = res.send
    res.send = (statusCode, body) ->
      if (typeof statusCode is 'number')
        res.statusCode = statusCode
      else
        # no statusCode sent, just maybe body
        body = statusCode
      originalSend.call res, body
    # TODO REMOVE ASAP
    engine.middleware req, res, next

  app


kattPlayer.engines =
  linear: require './engines/linear'
  linearCheck: require './engines/linear-check'
  checkout: require './engines/checkout'


module.exports = kattPlayer
