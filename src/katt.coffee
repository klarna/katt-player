fs = require 'fs'
url = require 'url'
_ = require 'lodash'
blueprintParser = require 'katt-blueprint-parser'

isPlainObjectOrArray = (obj) ->
  _.isPlainObject(obj) or _.isArray(obj)

regexEscape = (text) ->
  text.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\,\\\^\$\|\#\s]/g, '\\$&'

TAGS =
  MATCH_ANY: '{{_}}'
  RECALL_BEGIN: '{{<'
  RECALL_END: '}}'
  STORE_BEGIN: '{{>'
  STORE_END: '}}'
  MARKER_BEGIN: '{'
  MARKER_END: '}'
  # SUB_BEGIN: '{{>'
  # SUB_END: '<}}'
TAGS_RE = do () ->
  result = {}
  result[tagName] = regexEscape tag  for tagName, tag of TAGS
  result

###
recallRE = ///
  ^#{TAGS_RE.RECALL_BEGIN}
  [^#{TAGS_RE.MARKER_END}]+
  #{TAGS_RE.RECALL_END}$
///
###

storeRE = ///
  ^#{TAGS_RE.STORE_BEGIN}
  [^#{TAGS_RE.MARKER_END}]+
  #{TAGS_RE.STORE_END}$
///

###
subRE = ///
  ^#{TAGS_RE.SUBE_BEGIN}
  [^#{TAGS_RE.MARKER_END}]+
  #{TAGS_RE.SUBE_END}$
///
###

matchAnyRE = ///
  #{TAGS_RE.MATCH_ANY}
///

#
# API
#

exports.isJsonBody = (reqres) ->
  contentType = reqres.headers?['content-type'] or reqres.get?('content-type') or ''
  /\bjson\b/.test contentType


exports.maybeJsonBody = (reqres) ->
  if exports.isJsonBody reqres
    try
      return JSON.parse reqres.body
  reqres.body


exports.normalizeHeaders = (headers) ->
  result = {}
  for name, value of headers
    # Lowercase names
    name = name.trim().toLowerCase()
    # Ignore charset param in Content-Type headers
    if name is 'content-type'
      value = value.replace /;\s*charset=[^\s;]+\s*/, ''
    result[name] = value
  result


exports.normalizeURL = (URL, vars = {}) ->
  result = url.parse URL
  sameHostname = (result.hostname is vars.hostname)
  samePort = not vars.port or (result.port is vars.port.toString())
  if sameHostname and samePort
    delete result.protocol
    delete result.slashes
    delete result.hostname
    delete result.host
    delete result.port
    result = url.format result
    result
  else
    URL


exports.getHost = (host) ->
  [hostname, port] = host.split ':'
  {
    host
    hostname
    port
  }


# VALIDATE
exports.validate = (key, actualValue, expectedValue, vars = {}, result = []) ->
  return result  if matchAnyRE.test expectedValue
  # maybe store, maybe recall
  exports.store actualValue, expectedValue, vars
  expectedValue = exports.recall expectedValue, vars

  return result  if actualValue is expectedValue
  unless actualValue?
    result.push.apply result, [['missing_value', key, actualValue, expectedValue]]
    return result
  if storeRE.test actualValue
    result.push.apply result, [['empty_value', key, actualValue, expectedValue]]
    return result
  result.push.apply result, [['not_equal', key, actualValue, expectedValue]]
  result


exports.validateDeep = (key, actualValue, expectedValue, vars, result) ->
  if isPlainObjectOrArray(actualValue) and isPlainObjectOrArray(expectedValue)
    keys = _.sortBy _.union _.keys(actualValue), _.keys(expectedValue)
    for key in keys
      if isPlainObjectOrArray expectedValue[key]
        exports.validateDeep key, actualValue[key], expectedValue[key], vars, result
      else
        exports.validate key, actualValue[key], expectedValue[key], vars, result
    result
  else
    exports.validate key, actualValue, expectedValue, vars, result


exports.validateURL = (actualURL, expectedURL, vars = {}) ->
  result = []
  actualURL = exports.normalizeURL actualURL, vars
  expectedURL = exports.recall expectedURL, vars
  expectedURL = exports.normalizeURL expectedURL, vars

  exports.validate 'url', actualURL, expectedURL, vars, result
  result


exports.validateHeaders = (actualHeaders, expectedHeaders, vars = {}) ->
  result = []
  actualHeaders = exports.normalizeHeaders actualHeaders
  expectedHeaders = exports.recallDeep expectedHeaders, vars
  expectedHeaders = exports.normalizeHeaders expectedHeaders

  for header of expectedHeaders
    exports.validate header, actualHeaders[header], expectedHeaders[header], vars, result
  result


exports.validateBody = (actualBody, expectedBody, vars = {}, result = []) ->
  result = []
  if isPlainObjectOrArray(actualBody) and isPlainObjectOrArray(expectedBody)
    exports.validateDeep 'body', actualBody, expectedBody, vars, result
  else
    # actualBody = JSON.stringify actualBody, null, 2  unless _.isString actualBody
    # expectedBody = JSON.stringify expectedBody, null, 2  unless _.isString expectedBody
    exports.validate 'body', actualBody, expectedBody, vars, result


exports.validateResponse = (actualResponse, expectedResponse, vars = {}, result = []) ->
  # TODO check status
  # TODO check headers
  # TODO check body


# SUBSTITUTE ?!
# exports.substitute = (string, subVars) ->
#   for subVar, subValue of subVars
#     RE = new RegExp regexEscape("#{SUB_BEGIN_TAG}#{subVar}#{SUB_END_TAG}"), 'g'
#     string = string.replace RE, subValue


# STORE
exports.store = (actualValue, expectedValue, vars = {}) ->
  return vars  unless _.isString expectedValue
  return vars  if matchAnyRE.test expectedValue
  return vars  unless storeRE.test expectedValue
  expectedValue = expectedValue.replace TAGS.STORE_BEGIN, ''
  expectedValue = expectedValue.replace TAGS.STORE_END, ''
  vars[expectedValue] = actualValue


exports.storeDeep = (actualValue, expectedValue, vars = {}) ->
  if isPlainObjectOrArray(actualValue) and isPlainObjectOrArray(expectedValue)
    keys = _.sortBy _.union _.keys(actualValue), _.keys(expectedValue)
    for key in keys
      if isPlainObjectOrArray expectedValue[key]
        exports.storeDeep actualValue[key], expectedValue[key], vars
      else
        exports.store actualValue[key], expectedValue[key], vars
    vars
  else
    exports.store actualValue, expectedValue, vars


# RECALL
exports.recall = (expectedValue, vars = {}) ->
  return expectedValue  unless _.isString expectedValue
  for key, value of vars
    keyRE = regexEscape key
    keyRE = new RegExp "#{TAGS_RE.RECALL_BEGIN}#{keyRE}#{TAGS_RE.RECALL_END}", 'g'
    expectedValue = expectedValue.replace keyRE, value
  expectedValue


exports.recallDeep = (expectedValue, vars = {}) ->
  if isPlainObjectOrArray expectedValue
    keys = _.keys expectedValue
    expectedValue = _.clone expectedValue
    for key in keys
      if isPlainObjectOrArray expectedValue[key]
        expectedValue[key] = exports.recallDeep expectedValue[key], vars
      else
        expectedValue[key] = exports.recall expectedValue[key], vars
    expectedValue
  else
    exports.recall expectedValue, vars


# RUN
exports.run = (scenario, params = {}, vars = {}) ->
  blueprint = exports.readScenario scenario
  # TODO implement timeouts, spawn process?
  exports.runScenario scenario, blueprint.operations, params, vars


exports.readScenario = (scenario) ->
  blueprint = blueprintParser.parse fs.readFileSync scenario, 'utf8'
  # NOTE probably should return a normalized copy
  for operation in blueprint.operations
    for reqres in [operation.request, operation.response]
      reqres.headers = exports.normalizeHeaders reqres.headers
      reqres.body = exports.maybeJsonBody reqres  if reqres.body?
  blueprint


exports.runScenario = (scenario, blueprintOrOperations, params = {}, vars = {}) ->
  if blueprintOrOperations.operations?
    exports.runScenario scenario, blueprintOrOperations.operations, params, vars
  operations = blueprintOrOperations
  for operation in operations
    request = makeRequest operation.request, params, vars
    expectedResponse = makeResponse operation.response, vars
    actualResponse = getResponse request
    result = exports.validateResponse actualResponse, expectedResponse
    return result  if result.length isnt 0
  # TODO
