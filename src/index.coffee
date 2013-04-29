fs = require 'fs'
path = require 'path'
glob = require 'glob'
winston = require 'winston'
express = require 'express'
crypto = require 'crypto'
katt = require './katt'


md5 = (text) ->
  crypto.createHash('md5').update(text).digest 'hex'


globOptions =
  nosort: true
  stat: false


winston.remove winston.transports.Console
if process.env.NODE_ENV is 'development'
  winston.add winston.transports.Console,
    # handleExceptions: true
    # exitOnError: false
    # timestamp: true
    colorize: true
else
  winston.add winston.transports.File,
    # handleExceptions: true
    # exitOnError: false
    timestamp: true
    filename: "#{__dirname}/console.log"


kattPlayer = (engine, options = {}) ->
  # NOTE maintain compatibility with express2
  app = options.app or express.createServer()
  scenarios = options.scenarios or []
  scenariosByFilename = {}
  app.katt = {
    winston
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


  appListen = app.listen
  app.listen = (args...) ->
    winston.info "Server started on http://127.0.0.1:#{args[0]}"
    appListen.apply app, args

  app.engine = engine
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session
    secret: 'Lorem ipsum dolor sit amet.'
  engineMiddleware = engine(app).middleware
  app.use (req, res, next) ->
    # NOTE maintain compatibility with express2
    req.get = (header) -> req.header header
    res.get = (header) -> res.header header
    req.set = (header, value) -> req.header header, value
    res.set = (header, value) -> res.header header, value
    engineMiddleware req, res, next

  app


kattPlayer.engines =
  linear: require './engines/linear'
  linearCheck: require './engines/linear-check'
  checkout: require './engines/checkout'


module.exports = kattPlayer
