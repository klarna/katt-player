_ = require 'lodash'

normalizeHeader = (header) ->
  header.trim().toLowerCase()

isPlainObjectOrArray = (obj) ->
  _.isPlainObject(obj) or _.isArray(obj)

storeRE = /^{{>.+}}$/
matchAnyRE = /^{{_}}$/

#
# API
#

exports.normalizeHeaders = (headers) ->
  result = {}
  result[normalizeHeader(header)] = headerValue  for header, headerValue of headers
  result

exports.validate = (key, actualValue, expectedValue, result = []) ->
  return result  if actualValue is expectedValue or matchAnyRE.test expectedValue
  return result.concat [['missing_value', key, actualValue, expectedValue]]  unless actualValue?
  return result.concat [['empty_value', key, actualValue, expectedValue]]  if storeRE.test actualValue
  result.concat [['not_equal', key, actualValue, expectedValue]]

exports.validateDeep = (key, actualValue, expectedValue, result) ->
  return exports.validate key, actualValue, expectedValue, result  unless isPlainObjectOrArray(actualValue) and isPlainObjectOrArray(expectedValue)
  keys = _.sortBy _.union _.keys(actualValue), _.keys(expectedValue)
  for key in keys
    if isPlainObjectOrArray expectedValue[key]
      exports.validateDeep key, actualValue[key], expectedValue[key], result
    else
      exports.validateDeep key, actualValue[key], expectedValue[key], result
  result

exports.validateHeaders = (actualHeaders, expectedHeaders) ->
  result = []
  actualHeaders = exports.normalizeHeaders actualHeaders
  expectedHeaders = exports.normalizeHeaders expectedHeaders

  exports.validate header, actualHeaders[header], expectedHeaders[header], result  for header of expectedHeaders
  result

exports.validateBody = (actualBody, expectedBody, result = []) ->
  result = []
  if isPlainObjectOrArray(actualBody) and isPlainObjectOrArray(expectedBody)
    exports.validateDeep 'body', actualBody, expectedBody, result
  else
    # actualBody = JSON.stringify actualBody, null, 2  unless _.isString actualBody
    # expectedBody = JSON.stringify expectedBody, null, 2  unless _.isString expectedBody
    exports.validate 'body', actualBody, expectedBody, result
