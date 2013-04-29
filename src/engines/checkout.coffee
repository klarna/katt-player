crypto = require 'crypto'
_ = require 'lodash'
LinearCheckEngine = require './linear-check'


md5 = (text) ->
  crypto.createHash('md5').update(text).digest 'hex'


module.exports = class CheckoutEngine extends LinearCheckEngine
  @_preSendHooks: undefined


  constructor: (app, options = {}) ->
    return new CheckoutEngine(app, options)  unless this instanceof CheckoutEngine
    _.merge options,
      hooks:
        preSend: @_preSendHook
        postSend: @_postSendHook
    @_preSendHooks = [
      @_preSendHook_GET_AggV2
    ]
    super app, options


  _modifyContext: (req, res, next) ->
    context = req.context

    id = md5(req.sessionID + req.context.scenario.filename) # to please isak 2013-04-29 /andrei
    context.vars.order_uri = @options.vars.order_uri_template.replace '{/id}', "/#{id}"


  _MT: (name) ->
    "application/vnd.klarna.checkout.#{name}+json"


  _hasContentType: (reqres, name) ->
    MT =  @_MT name
    headers = reqres.headers or reqres._headers
    contentType = headers?['content-type']
    contentType is MT


  _preSendHook: (req, res, next) =>
    hookIndex = -1
    nextHook = (err) =>
      hookIndex += 1
      return next()  if hookIndex + 1 > @_preSendHooks.length
      fun = @_preSendHooks[hookIndex]
      fun.call @, req, res, nextHook
    nextHook()


  _preSendHook_GET_AggV2: (req, res, next) ->
    return next()  unless req.method is 'GET' and res.body? and @_hasContentType res, 'aggregated-order-v2'

    res.body.gui.snippet = "SOME_HTML_STUFF"
    next()


  _postSendHook: (req, res, next) =>
    next()
