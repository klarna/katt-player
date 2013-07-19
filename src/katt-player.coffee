###
   Copyright 2013 Klarna AB

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
###

http = require 'http'
url = require 'url'
katt = require 'katt-js'
_ = require 'lodash'
utils = require './utils'


exports.makeServer = (engine) ->
  app = http.createServer (req, res, next) ->
    # CORS
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


exports.engines =
  'linear': require './engines/linear'
  'linear-check': require './engines/linear-check'