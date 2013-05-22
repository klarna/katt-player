#jshint node:true

fs = require 'fs'
argparse = require 'argparse'
_ = require 'lodash'
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

  # NOTE: 0.0.0.0 listens on all network interfaces.
  # 127.0.0.1 would only listen on the loopback interface.
  parser.addArgument ['--hostname'],
    help: 'Server hostname / IP address. (%(defaultValue)d)'
    defaultValue: '0.0.0.0'
    type: 'string'

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


main = exports.main = (args = process.args) ->
  args = parseArgs(args)
  {hostname, port} = args
  options = _.merge({hostname, port}, args.engineOptions)
  engine = new args.engine(args.scenarios, options)
  kattPlayer.makeServer(engine).listen port, hostname, ->
    console.log "Server started on http://#{hostname}:#{port}"


main()  if require.main is module
