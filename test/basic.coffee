{
  _
  should
  nock
} = require './utils'

describe 'KATT Player', () ->
  blueprint = fs.readFileSync './basic.apib', 'utf8'

  it 'should start', () ->
    1.should.equal 1
