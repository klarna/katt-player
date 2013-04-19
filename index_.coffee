fs = require 'fs'
path = require 'path'
glob = require 'glob'
winston = require 'winston'
express = require 'express'
crypto = require 'crypto'
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


kattPlayer = (engine) ->
  app = express()
  app.winston = winston
  app.scenariosById = {}
  app.scenariosByFilename = {}

  loadScenario = (filename) ->
    id = md5 filename
    app.scenariosById[id] = app.scenariosByFilename[filename] = {
      id
      filename
      blueprint: undefined
    }

  app.load = (args...) ->
    for scenario in args
      continue  unless fs.existsSync scenario
      scenario = path.normalize scenario

      if fs.statSync(scenario).isDirectory()
        scenarios = glob.sync "#{scenario}/**/*.apib", globOptions
        app.load.apply null, scenarios
      else if fs.statSync(scenario).isFile()
        loadScenario scenario

  appListen = app.listen
  app.listen = (args...) ->
    winston.info "Server started on http://127.0.0.1:#{args[0]}"
    appListen.apply app, args

  app.engine = engine
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session
    secret: 'Lorem ipsum dolor sit amet.'
  app.use new engine(app).middleware

  app


kattPlayer.engines =
  linear: require './engines/linear'
  linearCheck: require './engines/linearCheck'

module.exports = kattPlayer
