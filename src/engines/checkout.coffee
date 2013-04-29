_ = require 'lodash'
LinearCheckEngine = require './linear-check'


module.exports = class CheckoutEngine extends LinearCheckEngine
  @_preSendHooks: undefined


  constructor: (app, options = {}) ->
    return new CheckoutEngine(app, options)  unless this instanceof CheckoutEngine
    _.merge options,
      hooks:
        preSend: @_preSendHook
        postSend: @_postSendHook
    @_preSendHooks = [
      @_preSendHookAggV1
      @_preSendHookAggV2
    ]
    super app, options


  _MT: (name) ->
    "application/vnd.klarna.checkout.#{name}+json"


  _hasContentType: (reqres, name) ->
    MT =  @_MT name
    headers = reqres.headers or reqres._headers
    contentType = headers?['content-type']
    contentType is MT


  _preSendHook: (context, req, res, next) =>
    hookIndex = -1
    nextHook = (err) =>
      hookIndex += 1
      return next()  if hookIndex + 1 > @_preSendHooks.length
      fun = @_preSendHooks[hookIndex]
      fun.call @, context, req, res, nextHook
    nextHook()


  _preSendHookAggV1: (context, req, res, next) =>
    return next()  unless req.method is 'GET' and res.body? and @_hasContentType res, 'aggregated-order-v1'
    res.body.gui.snippet = "SOME_HTML_STUFF"
    next()


  _preSendHookAggV2: (context, req, res, next) ->
    return next()  unless req.method is 'GET' and res.body? and @_hasContentType res, 'aggregated-order-v2'
    res.body.gui.snippet = "SOME_HTML_STUFF"
    next()


  _postSendHook: (context, req, res, next) =>
    next()
