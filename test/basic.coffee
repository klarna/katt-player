{
  _
  fs
  should
  nock
} = r = require './_utils'

describe 'KATT Player', () ->
  blueprint = fs.readFileSync "#{__dirname}/basic.apib", 'utf8'

  it 'should start', () ->
    1.should.equal 1
