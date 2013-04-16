fs = require 'fs'
path = require 'path'
glob = require 'glob'
winston = require 'winston'
express = require 'express'

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
  app.scenarios = {}

  loadBlueprint = (blueprint) ->
    scenario = blueprint.replace '.apib', ''
    if app.scenarios[scenario]?
      winston.warn "Duplicate scenario called #{name}\nin  #{app.scenarios[name]}\nand #{blueprint}"
    app.scenarios[scenario] = blueprint

  app.load = (args...) ->
    for blueprint in args
      continue  unless fs.existsSync blueprint
      blueprint = path.normalize blueprint

      if fs.statSync(blueprint).isDirectory()
        blueprints = glob.sync "#{blueprint}/**/*.apib", globOptions
      else if fs.statSync(blueprint).isFile()
        loadBlueprint blueprint

  appListen = app.listen
  app.listen = (args...) ->
    winston.info "Server started on http://127.0.0.1:#{args[0]}"
    appListen.apply app, args

  app.engine = engine
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session
    secret: 'Lorem ipsum dolor sit amet.'
  app.use engine app

  app


kattPlayer.engines =
  linear: require './engines/linear'
  linearCheck: require './engines/linearCheck'

module.exports = kattPlayer
