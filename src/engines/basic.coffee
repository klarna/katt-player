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

fs = require 'fs'
path = require 'path'
url = require 'url'
glob = require 'glob'
_ = require 'lodash'
katt = require 'katt-js'
{
  isJsonCT
  normalizeHeaders
  parseHost
} = katt.utils
callbacks = katt.callbacks


GLOB_OPTIONS =
  nosort: true
  stat: false


# A trivial engine without any magic apart from basic routing possibilities.
module.exports = class BasicEngine

  constructor: ({scenarios, options}) ->
    return new BasicEngine({scenarios, options})  unless this instanceof BasicEngine
    options or= {}
    @options = _.merge options, {
      hooks: {}
    }
    @scenariosByFilename = {}
    @loadScenarios scenarios

  eachBlueprint: (fun = ((bp) -> bp)) ->
    fun(blueprint, filename)  for filename, {blueprint} of @scenariosByFilename

  loadScenario: (filename) ->
    try
      blueprint = katt.readScenario filename
      for transaction in blueprint.transactions
        for reqres in [transaction.request, transaction.response]
          continue  unless reqres.body?
          try
            reqres.body = callbacks.parse {
              headers: normalizeHeaders reqres.headers
              body: reqres.body
            }
          catch e
            console.log 'loadScenarios error while parsing ', reqres
            throw new Error "Unable to parse blueprint"
    catch e
      throw new Error "Unable to find/parse blueprint file #{filename}\n#{e}"
    @scenariosByFilename[filename] = {
      filename
      blueprint
    }


  loadScenarios: (scenarios) ->
    scenarios = [scenarios]  unless _.isArray scenarios
    for scenario in scenarios
      continue  unless fs.existsSync scenario
      scenario = path.normalize scenario

      if fs.statSync(scenario).isDirectory()
        apibs = glob.sync "#{scenario}/**/*.apib", GLOB_OPTIONS
        @loadScenarios apibs
      else if fs.statSync(scenario).isFile()
        @loadScenario scenario


  callHook: (name, req, res, next) ->
    if @options.hooks[name]?
      @options.hooks[name] req, res, next
    else
      next()  if next?


  sendError: (res, statusCode, error) ->
    res.setHeader 'Content-Type', 'text/plain'
    res.setHeader 'X-KATT-Error', encodeURIComponent error.split('\n').shift()
    res.send statusCode, error

  sendResponse: (req, res, next) ->
    @callHook 'preSend', req, res, () =>
      res.body = JSON.stringify(res.body, null, 2)  if isJsonCT res.getHeader 'content-type'
      res.send res.body
      @callHook 'postSend', req, res, () ->


  middleware: (req, res, next) ->
    @sendError res, 500, 'Define a middleware unless all you want is this error'

