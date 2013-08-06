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
              example_uri: 'http://#{hostname}:#{port}/step2'
            }

        app = kattPlayer.makeServer engine
        app.listen port
        katt.run {scenario, params: {hostname, port}}, (err, result) ->
          result.status.should.eql 'pass'
          app.close()
          done()
