#jshint node:true

fs = require 'fs'
argparse = require 'argparse'
kattPlayer = require './katt-player'
pkg = require '../package'

# For argument validation / transformation.
CUSTOM_TYPES =
  engine: (value) ->
    if kattPlayer.hasEngine(value)
      kattPlayer.getEngine value
    else if fs.existsSync(value)
      require value
    else
      throw new Error "Invalid engine: #{value}."

  json: (value) ->
    try
      JSON.parse(value)
    catch e
      throw new Error "Invalid JSON string: #{value}. #{e}."


parseArgs = (args) ->
  engines = kattPlayer.getEngineNames().join(', ')

  parser = new argparse.ArgumentParser
    description: pkg.description
    version: pkg.version
    addHelp: true

  parser.addArgument ['-e', '--engine'],
    help: "Engine as built-in [#{engines}] or file path. (%(defaultValue)s)"
    defaultValue: 'linear'
    type: CUSTOM_TYPES.engine

  parser.addArgument ['-p', '--port'],
    help: 'Port number. (%(defaultValue)d)'
    defaultValue: 1337
    type: 'int'

  parser.addArgument ['scenarios'],
    help: 'Scenarios as files/folders'
    nargs: '+'

  parser.addArgument ['--engine-options'],
    help: 'Options for the engine. (%(defaultValue)s)'
    defaultValue: '{}'
    metavar: 'JSON_STRING'
    type: CUSTOM_TYPES.json
    dest: 'engineOptions'

  parser.parseArgs(args)


exports.main = (args = process.args) ->
  args = parseArgs(args)
  engine = new args.engine(args.scenarios, args.engineOptions)
  kattPlayer
    .makeServer(engine)
    .listen args.port, ->
      console.log 'Server started on http://127.0.0.1:' + args.port

