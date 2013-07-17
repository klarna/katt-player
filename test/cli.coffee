express = require 'express'
{
  _
  fs
  nock
  should
} = require './_utils'
cli = require '../bin/cli'

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
      fun = () ->
        server = cli.main(['-e', 'bad-engine'])
      fun.should.throw "process.exit(2)"


  # describe "when providing a built-in engine", ->

  #   it 'should accept argument: -e linear-check', ->
  #     (-> server = cli.main(['-e', 'linear-check']))
  #       .should.not.throw "process.exit(2)"
