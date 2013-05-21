_ = require 'lodash'
LinearCheckEngine = require './linear-check'


module.exports = class LinearEngine extends LinearCheckEngine
  constructor: (scenarios, options = {}) ->
    return new LinearEngine(scenarios, options)  unless this instanceof LinearEngine
    options.check or= {}
    _.merge options,
      check:
        url: true
        method: true
        headers: false
        body: false
    super scenarios, options
