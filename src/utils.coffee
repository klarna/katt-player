cookie = require 'cookie'

# Convenience monkey patching
exports.helperPatching = (req, res, next) ->
  req.cookies = cookie.parse req.headers.cookie
  res.cookies = {}

  res.headers = res._headers or= {}
  res.send = (statusCode, body) ->
    if typeof statusCode is 'number'
      res.statusCode = res.status = statusCode
    else
      # no statusCode sent, just maybe body
      body = statusCode

    cookies = []
    cookies.push cookie.serialize key, value, {}  for key, value of res.cookies
    res.setHeader 'Set-Cookie', cookies

    res.statusCode ?= res.status
    @end body, 'utf-8'

  body = ''

  req.on 'data', (chunk) ->
    body += chunk.toString()
  req.on 'end', () ->
    body or= null
    req.body = body
    next()
