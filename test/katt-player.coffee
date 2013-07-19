{
  _
  should
} = require './_utils'
fixtures = require './katt-player.fixtures'
katt = undefined # delayed
kattPlayer = undefined # delayed

describe 'katt', () ->
  describe 'run', () ->
    before () ->
      {
        katt
        kattPlayer
      } = fixtures.run.before()
    after fixtures.run.after

    it 'should run a basic linear scenario', (done) ->
      scenario = '/mock/basic.apib'
      app = kattPlayer.makeServer kattPlayer.linear
      app.on 'listening', () ->
        port = app.address().port
        katt.run {scenario, params: {port}}, (err, result) ->
          result.status.should.eql 'pass'
          app.close()
          done()
      app.listen 0 # free random port
