###
   Copyright 2013 Klarna AB

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
###

cookie = require 'cookie'

# Convenience monkey patching
exports.helperPatching = (req, res, next) ->
  req.cookies = {}
  req.cookies = cookie.parse req.headers.cookie  if req.headers.cookie
  res.cookies = {}

  res.headers = res._headers or= {}
  res.send = (statusCode, body) ->
    if typeof statusCode is 'number'
      res.statusCode = statusCode
    else
      # no statusCode sent, just maybe body
      body = statusCode

    cookies = (cookie.serialize key, value, {path:'/'}  for key, value of res.cookies)
    res.setHeader 'Set-Cookie', cookies

    @end body, 'utf-8'

  body = ''

  req.on 'data', (chunk) ->
    body += chunk.toString()
  req.on 'end', () ->
    body or= null
    req.body = body
    next()
