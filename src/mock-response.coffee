_ = require 'lodash'

module.exports = class MockResponse
  statusCode: undefined
  headers: undefined
  cookies: undefined
  body: undefined
  finished: false

  constructor: (res) ->
    @headers = {}
    @cookies = {}

    return  unless res
    @statusCode = res.statusCode
    @headers = _.cloneDeep(res.headers) or {}
    @body = res.body


  status: () ->
    @statusCode


  getHeader: (header) ->
    @headers[header.toLowerCase()]


  setHeader: (header, value) ->
    @headers[header.toLowerCase()] = value


  cookie: (key, value) ->
    @cookies[key] = value


  end: () ->


  send: (statusCode, body) ->
    return  if @finished # or throw error ?
    if typeof statusCode is 'number'
      @statusCode = statusCode
    else
      # no statusCode sent, just maybe body
      body = statusCode
    @body = body  if body
    finished = true
