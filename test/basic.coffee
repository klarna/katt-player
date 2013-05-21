{
  _
  fs
  should
  nock
} = require './utils'

describe 'KATT Player', () ->
  blueprint = fs.readFileSync "#{__dirname}/basic.apib", 'utf8'

  it 'should start', () ->
    1.should.equal 1
