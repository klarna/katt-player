http = require 'http'
url = require 'url'
katt = require './katt'
utils = require './utils'

ENGINES =
  'linear': require './engines/linear'
  'linear-check': require './engines/linear-check'


exports.addEngine = (name, engine)   -> ENGINES[name] = engine
exports.hasEngine = (name)           -> ENGINES[name] isnt undefined
exports.getEngine = (name)           -> ENGINES[name]
exports.getEngineNames =             -> Object.keys ENGINES

exports.makeServer = (engine) ->
  app = http.createServer (req, res, next) ->
    if req.method is 'OPTIONS'
      res.statusCode = 200
      res.setHeader 'Access-Control-Allow-Origin', do () ->
        origin = req.headers.origin
        origin ?= '*'
        origin
      res.setHeader 'Access-Control-Allow-Methods', do () ->
        methods = req.headers['access-control-request-method']
        methods ?= 'HEAD, GET, POST, PATCH, PUT, DELETE'
        methods = "OPTIONS, #{methods}"
        methods
      res.setHeader 'Access-Control-Allow-Headers', do () ->
        headers = req.headers['access-control-request-headers']
        headers ?= 'accept, origin, authorization, content-type'
        headers
      res.setHeader 'Access-Control-Max-Age', '0'
      res.end ''
      return
    utils.helperPatching req, res, () ->
      engine.middleware req, res, next
  app.engine = engine
  app
