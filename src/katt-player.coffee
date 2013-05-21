express = require 'express'
katt = require './katt'

ENGINES =
  'linear': require './engines/linear'
  'linear-check': require './engines/linear-check'
  'checkout': require './engines/checkout'

# Maintain compatibility with express2
express2Compatibility = (req, res, next) ->
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

  next()


exports.hasEngine = (engine) -> ENGINES[engine] isnt undefined
exports.getEngine = (engine) -> ENGINES[engine]
exports.getEngineNames =     -> Object.keys(ENGINES)

exports.makeServer = (engine) ->
  app = express()
  app.engine = engine
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session
    secret: 'Lorem ipsum dolor sit amet.'
  app.use express2Compatibility
  app.use engine.middleware
  app
