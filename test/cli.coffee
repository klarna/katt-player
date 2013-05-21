express = require 'express'
{
  _
  fs
  should
  nock
} = require './utils'

# Pro tip: if you want to break mocha, do this:
# cli = require '../cli'. # -_-/
cli = require '../src/cli'

err = process.stderr.write
log = process.stdout.write


silenceOutput = ->
  return  if process.env.DEBUG
  process.stderr.write = (args) =>
    err.apply(process.stderr, args)
  process.stdout.write = (args) =>
    log.apply(process.stdout, args)

enableOutput = ->
  process.stderr.write = err
  process.stdout.write = log


#
# TESTS
#

describe 'CLI', () ->
  server = null

  before ->
    @exit = process.exit
    process.exit = (code) ->
      throw new Error "process.exit(#{code})"

  after ->
    process.exit = @exit
    enableOutput()


  describe "when providing an incorrect engine", ->

    it 'should not accept argument: -e bad-engine', ->
      (->
        server = cli.main(['-e', 'bad-engine'])
      ).should.throw "process.exit(2)"


  # describe "when providing a built-in engine", ->

  #   it 'should accept argument: -e linear-check', ->
  #     (-> server = cli.main(['-e', 'linear-check']))
  #       .should.not.throw "process.exit(2)"
