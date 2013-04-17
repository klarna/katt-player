fs = require 'fs'
_ = require 'lodash'
blueprintParser = require 'katt-blueprint-parser'

normalizeHeader = (header) ->
  header.trim().toLowerCase()

isPlainObjectOrArray = (obj) ->
  _.isPlainObject(obj) or _.isArray(obj)

regexEscape = (text) ->
  text.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\,\\\^\$\|\#\s]/g, '\\$&'

TAGS =
  MATCH_ANY: '{{_}}'
  EXTRACT_BEGIN: '{{<'
  EXTRACT_END: '}}'
  STORE_BEGIN: '{{>'
  STORE_END: '}}'
  # SUB_BEGIN: '{{>'
  # SUB_END: '<}}'
TAGS_RE = do () ->
  result = {}
  result[tagName] = regexEscape tag  for tagName, tag of TAGS
  result

extractRE = new RegExp "^#{TAGS_RE.EXTRACT_BEGIN}.+#{TAGS_RE.EXTRACT_END}$", 'g'
storeRE = new RegExp "^#{TAGS_RE.STORE_BEGIN}.+#{TAGS_RE.STORE_END}$", 'g'
# subRE = new RegExp "^#{TAGS_RE.SUBE_BEGIN}.+#{TAGS_RE.SUBE_END}$", 'g'
matchAnyRE = new RegExp TAGS_RE.MATCH_ANY, 'g'

#
# API
#

exports.isJsonBody = (reqres) ->
  /\bjson$/.test(reqres.headers['content-type'] or '')

exports.normalizeHeaders = (headers) ->
  result = {}
  result[normalizeHeader(header)] = headerValue  for header, headerValue of headers
  result

# VALIDATE
exports.validate = (key, actualValue, expectedValue, vars = {}, result = []) ->
  return result  if matchAnyRE.test expectedValue
  # maybe store, maybe extract
  exports.store actualValue, expectedValue, vars
  expectedValue = exports.extract expectedValue, vars

  return result  if actualValue is expectedValue
  return result.concat [['missing_value', key, actualValue, expectedValue]]  unless actualValue?
  return result.concat [['empty_value', key, actualValue, expectedValue]]  if storeRE.test actualValue
  result.concat [['not_equal', key, actualValue, expectedValue]]

exports.validateDeep = (key, actualValue, expectedValue, vars, result) ->
  return exports.validate key, actualValue, expectedValue, vars, result  unless isPlainObjectOrArray(actualValue) and isPlainObjectOrArray(expectedValue)
  keys = _.sortBy _.union _.keys(actualValue), _.keys(expectedValue)
  for key in keys
    if isPlainObjectOrArray expectedValue[key]
      exports.validateDeep key, actualValue[key], expectedValue[key], vars, result
    else
      exports.validate key, actualValue[key], expectedValue[key], vars, result
  result

exports.validateHeaders = (actualHeaders, expectedHeaders, vars = {}) ->
  result = []
  actualHeaders = exports.normalizeHeaders actualHeaders
  expectedHeaders = exports.normalizeHeaders expectedHeaders

  exports.validate header, actualHeaders[header], expectedHeaders[header], vars, result  for header of expectedHeaders
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
  return exports.store actualValue, expectedValue, vars  unless isPlainObjectOrArray actualValue and isPlainObjectOrArray expectedValue
  keys = _.sortBy _.union _.keys(actualValue), _.keys(expectedValue)
  for key in keys
    if isPlainObjectOrArray expectedValue[key]
      exports.storeDeep actualValue[key], expectedValue[key], vars
    else
      exports.store actualValue[key], expectedValue[key], vars
  vars

# EXTRACT
exports.extract = (expectedValue, vars = {}) ->
  return expectedValue  unless _.isString expectedValue
  return expectedValue  unless extractRE.test expectedValue
  expectedValue = expectedValue.replace TAGS.EXTRACT_BEGIN, ''
  expectedValue = expectedValue.replace TAGS.EXTRACT_END, ''
  vars[expectedValue]

exports.extractDeep = (expectedValue, vars = {}) ->
  return exports.extract expectedValue, vars  unless isPlainObjectOrArray expectedValue
  keys = _.keys expectedValue
  expectedValue = _.clone expectedValue
  for key in keys
    if isPlainObjectOrArray expectedValue[key]
      expectedValue[key] = exports.extractDeep expectedValue[key], vars
    else
      expectedValue[key] = exports.extract expectedValue[key], vars
  expectedValue

# RUN
exports.run = (scenario, params = {}, vars = {}) ->
  blueprint = blueprintParser fs.readFileSync scenario, 'utf8'
  # TODO implement timeouts, spawn process?
  exports.runScenario scenario, blueprint.operations, params, vars

exports.runScenario = (scenario, blueprintOrOperations, params = {}, vars = {}) ->
  return exports.runScenario scenario, blueprintOrOperations.operations, params, vars  if blueprintOrOperations.operations?
  operations = blueprintOrOperations
  for operation in operations
    request = makeRequest operation.request, params, vars
    expectedResponse = makeResponse operation.response, vars
    actualResponse = getResponse request
    result = exports.validateResponse actualResponse, expectedResponse
    return result  if result.length isnt 0
  # TODO