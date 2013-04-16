fs = require 'fs'
path = require 'path'
glob = require 'glob'

express = require 'express'

globOptions =
  nosort: true
  stat: false

kattPlayer = (engine) ->
  app = express()
  app.scenarios = {}

  loadBlueprint = (blueprint) ->
    scenario = blueprint.replace '.apib', ''
    if app.scenarios[scenario]?
      console.log "Duplicate scenario called #{name}\nin  #{app.scenarios[name]}\nand #{blueprint}"
    app.scenarios[scenario] = blueprint

  app.load = (args...) ->
    for blueprint in args
      continue  unless fs.existsSync blueprint
      blueprint = path.normalize blueprint

      if fs.statSync(blueprint).isDirectory()
        blueprints = glob.sync "#{blueprint}/**/*.apib", globOptions
      else if fs.statSync(blueprint).isFile()
        loadBlueprint blueprint

  app.engine = engine
  app.use express.cookieParser()
  app.use express.session
    secret: 'Lorem ipsum dolor sit amet.'
  app.use engine app

  app

kattPlayer.engines =
  linear: require './engines/linear'

module.exports = kattPlayer
