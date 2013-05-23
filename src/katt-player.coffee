express = require 'express'
katt = require './katt'
utils = require './utils'

ENGINES =
  'linear': require './engines/linear'
  'linear-check': require './engines/linear-check'
  'checkout': require './engines/checkout'


exports.addEngine = (name, engine)   -> ENGINES[name] = engine
exports.hasEngine = (name)           -> ENGINES[name] isnt undefined
exports.getEngine = (name)           -> ENGINES[name]
exports.getEngineNames =             -> Object.keys(ENGINES)

exports.makeServer = (engine) ->
  app = express()
  app.engine = engine
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session
    secret: 'Lorem ipsum dolor sit amet.'
  app.use utils.express2Compatibility
  app.use engine.middleware
  app
