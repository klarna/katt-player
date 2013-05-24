http = require 'http'
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
  app = http.createServer (req, res, next) ->
    utils.helperPatching req, res
    engine.middleware req, res, next
  app.engine = engine
  app
