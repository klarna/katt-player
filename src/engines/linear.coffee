_ = require 'lodash'
LinearCheckEngine = require './linear-check'


module.exports = class LinearEngine extends LinearCheckEngine
  constructor: (app, options = {}) ->
    return new LinearEngine(app, options)  unless this instanceof LinearEngine
    options.check or= {}
    _.merge options,
      check:
        url: true
        method: true
        headers: false
        body: false
    super options
