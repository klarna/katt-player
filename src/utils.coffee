# Maintain compatibility with express2
exports.express2Compatibility = (req, res, next) ->
  req.get or= (header)        -> req.header header
  res.get or= (header)        -> res.header header
  req.set or= (header, value) -> req.header header, value
  res.set or= (header, value) -> res.header header, value

  originalSend = res.send

  res.send = (statusCode, body) ->
    if typeof statusCode is 'number'
      res.statusCode = statusCode
    else
      # no statusCode sent, just maybe body
      body = statusCode
    originalSend.call res, body

  # Not express2compatibility, just convenience; should be kept when removing express dep
  # FIXME should add .cookies and .cookie()
  res.headers = res._headers

  next()
