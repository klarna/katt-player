#jshint node:true

fs = require 'fs'
argparse = require 'argparse'
express = require 'express'
KattPlayer = require './index'
pkg = require '../package'

# For argument validation / transformation.
CUSTOM_TYPES = do (types = {}) ->
  types =
    'KATT engine': (value) ->
      if KattPlayer.hasEngine(value)
        KattPlayer.getEngine value
      else if fs.existsSync(value)
        require value
      else
        throw new Error "bad engine: #{value}"

    'JSON string': (value) ->
      try
        JSON.parse(value)
      catch e
        throw new Error "Invalid JSON string: #{value}. #{e}"

  for own k, v of types
    v.displayName = k

  types


parseArgs = ->
  parser = new argparse.ArgumentParser
    description: pkg.description
    version: pkg.version
    addHelp: true

  parser.addArgument ['-e', '--engine'],
    help: 'Engine as built-in name or filename path (%(defaultValue)s)'
    defaultValue: 'linear'
    type: CUSTOM_TYPES['KATT engine']

  parser.addArgument ['-p', '--port'],
    help: 'Port number (%(defaultValue)d)'
    defaultValue: 1337
    type: 'int'

  parser.addArgument ['scenarios'],
    help: 'Scenarios as files/folders'
    nargs: '+'

  parser.addArgument ['--engine-options'],
    help: 'Options for the engine (JSON string) (%(defaultValue)s)'
    defaultValue: '{}'
    metavar: 'JSON_STRING'
    type: CUSTOM_TYPES['JSON string']
    dest: 'engineOptions'

  parser.parseArgs()


exports.main = (args = process.args) ->
  args = parseArgs(args)
  app = express()
  engine = new args.engine(app, args.engineOptions)
  new KattPlayer(app, engine,
    scenarios: args.scenarios
  )
  console.log 'Server start on http://127.0.0.1:' + args.port
  app.listen args.port

