_ = require 'lodash'
linearCheckEngine = require './linearCheck'

module.exports = class linearEngine extends linearCheckEngine
  constructor: (app, options = {}) ->
    return new linearEngine(app, options)  unless this instanceof linearEngine
    options.check or= {}
    _.merge options,
      check:
        url: true
        method: true
        headers: false
        body: false
    super options