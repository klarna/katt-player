# Copyright 2013 Klarna AB
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module.exports = class MockResponse
  statusCode: undefined
  headers: undefined
  cookies: undefined
  body: undefined
  finished: false

  constructor: () ->
    @headers = {}
    @cookies = {}


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
