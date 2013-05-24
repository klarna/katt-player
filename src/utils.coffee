Cookies = require 'cookies'

# Maintain compatibility with express2
exports.express2Compatibility = (req, res) ->
  # Not express2compatibility, just convenience; should be kept when removing express dep
  req.cookies = res.cookies = new Cookies req, res

  req.cookie = res.cookie = (name, value, options) ->
    if arguments.length > 1
      res.cookies.set name, value, options
    else
      req.cookies.get name

  res.clearCookie = (name, options = {}) ->
    @cookies.set name, null, options

  res.headers = res._headers or= {}
  res.send = (statusCode, body) ->
    if typeof statusCode is 'number'
      res.statusCode = statusCode
    else
      # no statusCode sent, just maybe body
      body = statusCode
    @end body, 'utf-8'
