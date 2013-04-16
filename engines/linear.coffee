_ = require 'lodash'
linearCheck = require './linearCheck'

module.exports = (args...) ->
  ignore = args[1] or {}
  _.merge ignore,
    url: false
    headers: true
    body: true
  args[1] = ignore
  linearCheck.apply @, args
