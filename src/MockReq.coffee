module.exports = class MockReq
  method: undefined
  url: undefined
  headers: undefined
  cookies: undefined
  body: undefined

  context: undefined
  sessionID: undefined

  constructor: (req) ->
    @headers = {}
    @cookies = {}

    return  unless req
    @context = req.context
    @sessionID = req.sessionID
    @cookies = req.cookies # FIXME not part of vanilla NodeJS serverResponse


  getHeader: (header) ->
    @headers[header.toLowerCase()]
