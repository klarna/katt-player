chai = require 'chai'
chai.Assertion.includeStack = true

console.jog = (arg) ->
  console.log JSON.stringify arg

module.exports =
  _: require 'lodash'
  should: chai.should()
  nock: require 'nock'
  fs : require 'fs'

