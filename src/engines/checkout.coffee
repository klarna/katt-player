crypto = require 'crypto'
_ = require 'lodash'
LinearCheckEngine = require './linear-check'


md5 = (text) ->
  crypto.createHash('md5').update(text).digest 'hex'


module.exports = class CheckoutEngine extends LinearCheckEngine
  @_preSendHooks: undefined


  constructor: (scenarios, options = {}) ->
    return new CheckoutEngine(scenarios, options)  unless this instanceof CheckoutEngine
    _.merge options,
      hooks:
        preSend: @_preSendHook
        postSend: @_postSendHook
    @_preSendHooks = [
      @_preSendHook_res_AggV2
    ]
    super scenarios, options
    @_contexts.vars = _.merge
      checkout_uri: '/missing-checkout-uri'
      confirmation_uri: '/missing-confirmation-uri'
      bootstrap_uri: 'data:text/javascript;base64,YWxlcnQoJ01pc3NpbmcgYm9vdHN0cmFwX3VyaSB2YXJpYWJsZScpOw=='
      allow_separate_shipping_address: false
    , @options.vars


  _modifyContext: (req, res, next) ->
    context = req.context
    id = md5(req.context.UID) # to please isak 2013-04-29 /andrei
    id = md5(req.context.scenario.filename) # to please isak 2013-04-29 /andrei
    context.vars.order_uri = "http://#{@server.hostname}:#{@server.port}/checkout/orders/#{id}"


  _MT: (name) ->
    "application/vnd.klarna.checkout.#{name}+json"


  _hasContentType: (reqres, name) ->
    MT =  @_MT name
    headers = reqres.headers or reqres._headers or {}
    contentType = headers?['content-type']
    contentType is MT


  _makeSnippet: (req, res) ->
    """
    <div id="klarna-checkout-container" style="overflow-x: hidden;">
        <script type="text/javascript">
        /* <![CDATA[ */
            (function(w,k,i,d,u,n,c){
                w[k]=w[k]||function(){(w[k].q=w[k].q||[]).push(arguments)};
                w[k].config={
                    container:w.document.getElementById(i),
                    ORDER_URL:'#{req.context.vars.order_uri}',
                    AUTH_HEADER:'KlarnaCheckout sargantana',
                    LAYOUT:'#{res.body.gui.layout}',
                    LOCALE:'#{res.body.locale}',
                    PURCHASE_COUNTRY:'#{res.body.purchase_country}',
                    PURCHASE_CURRENCY:'#{res.body.purchase_currency}',
                    ORDER_STATUS:'#{res.body.status}',
                    MERCHANT_TAC_URI:'#{res.body.merchant.terms_uri}',
                    MERCHANT_TAC_TITLE:'Demobutiken (dev)',
                    MERCHANT_NAME:'Demobutiken (dev)',
                    GUI_OPTIONS:[],
                    ALLOW_SEPARATE_SHIPPING_ADDRESS:#{@_contexts.vars.allow_separate_shipping_address},
                    BOOTSTRAP_SRC:u
                };

                n=d.createElement('script');
                c=d.getElementById(i);
                n.async=!0;
                n.src=u;
                c.insertBefore(n,c.firstChild);
            })(this,'_klarnaCheckout',
               'klarna-checkout-container',document,'#{@_contexts.vars.bootstrap_uri}');
        /* ]]> */
        </script>
    </div>
    """


  _preSendHook: (req, res, next) =>
    hookIndex = -1
    nextHook = (err) =>
      hookIndex += 1
      return next()  if hookIndex + 1 > @_preSendHooks.length
      fun = @_preSendHooks[hookIndex]
      fun.call @, req, res, nextHook
    nextHook()


  _preSendHook_res_AggV2: (req, res, next) ->
    return next()  unless res.body? and @_hasContentType res, 'aggregated-order-v2'

    res.body = _.merge res.body,
      merchant:
        checkout_uri: @_contexts.vars.checkout_uri
        confirmation_uri: @_contexts.vars.confirmation_uri.replace '{checkout.order.uri}', encodeURIComponent req.context.vars.order_uri
      options:
        allow_separate_shipping_address: @_contexts.vars.allow_separate_shipping_address
      gui:
        snippet: @_makeSnippet req, res
    next()


  _postSendHook: (req, res, next) =>
    next()
