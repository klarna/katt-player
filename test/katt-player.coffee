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

{
  _
  should
} = require './_utils'
net = require 'net'
fixtures = require './katt-player.fixtures'
katt = undefined # delayed
kattPlayer = undefined # delayed

getFreePort = (next) ->
  app = net.createServer()
  app.on 'listening', () ->
    port = app.address().port
    app.close()
    next null, port
  app.on 'error', next
  app.listen 0

describe 'katt', () ->
  describe 'run', () ->
    before () ->
      {
        katt
        kattPlayer
      } = fixtures.run.before()
    after fixtures.run.after

    it 'should run a basic linear scenario', (done) ->
      getFreePort (err, port) ->
        hostname = '127.0.0.1'
        scenario = '/mock/basic.apib'
        Engine = kattPlayer.engines.linear
        engine = new Engine
          scenarios: [scenario]
          options:
            params: {
              hostname
              port
              example_uri: "http://#{hostname}:#{port}/step2"
            }

        app = kattPlayer.makeServer engine
        app.listen port
        katt.run {scenario, params: {hostname, port}}, (err, result) ->
          result.status.should.eql 'pass'
          app.close()
          done()
