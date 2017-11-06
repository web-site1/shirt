((root, factory) ->
  'use strict'
  if typeof define == 'function' and define.amd
    define [ 'jquery' ], ($) ->
      factory $
      return
  else if typeof module == 'object' and module.exports
    module.exports = root.EasyZoom = factory(require('jquery'))
  else
    root.EasyZoom = factory(root.jQuery)
  return
) this, ($) ->

  ###*
  # EasyZoom
  # @constructor
  # @param {Object} target
  # @param {Object} options (Optional)
  ###

  EasyZoom = (target, options) ->
    @$target = $(target)
    @opts = $.extend({}, defaults, options, @$target.data())
    @isOpen == undefined and @_init()
    return

  'use strict'
  dw = undefined
  dh = undefined
  rw = undefined
  rh = undefined
  lx = undefined
  ly = undefined
  defaults =
    loadingNotice: 'Loading image'
    errorNotice: 'The image could not be loaded'
    errorDuration: 2500
    linkAttribute: 'href'
    preventClicks: true
    beforeShow: $.noop
    beforeHide: $.noop
    onShow: $.noop
    onHide: $.noop
    onMove: $.noop

  ###*
  # Init
  # @private
  ###

  EasyZoom::_init = ->
    @$link = @$target.find('a')
    @$image = @$target.find('img')
    @$flyout = $('<div class="easyzoom-flyout" />')
    @$notice = $('<div class="easyzoom-notice" />')
    @$target.on
      'mousemove.easyzoom touchmove.easyzoom': $.proxy(@_onMove, this)
      'mouseleave.easyzoom touchend.easyzoom': $.proxy(@_onLeave, this)
      'mouseenter.easyzoom touchstart.easyzoom': $.proxy(@_onEnter, this)
    @opts.preventClicks and @$target.on('click.easyzoom', (e) ->
      e.preventDefault()
      return
    )
    return

  ###*
  # Show
  # @param {MouseEvent|TouchEvent} e
  # @param {Boolean} testMouseOver (Optional)
  ###

  EasyZoom::show = (e, testMouseOver) ->
    w1 = undefined
    h1 = undefined
    w2 = undefined
    h2 = undefined
    self = this
    if @opts.beforeShow.call(this) == false
      return
    if !@isReady
      return @_loadImage(@$link.attr(@opts.linkAttribute), ->
        if self.isMouseOver or !testMouseOver
          self.show e
        return
      )
    @$target.append @$flyout
    w1 = @$target.width()
    h1 = @$target.height()
    w2 = @$flyout.width()
    h2 = @$flyout.height()
    dw = @$zoom.width() - w2
    dh = @$zoom.height() - h2
    # For the case where the zoom image is actually smaller than
    # the flyout.
    if dw < 0
      dw = 0
    if dh < 0
      dh = 0
    rw = dw / w1
    rh = dh / h1
    @isOpen = true
    @opts.onShow.call this
    e and @_move(e)
    return

  ###*
  # On enter
  # @private
  # @param {Event} e
  ###

  EasyZoom::_onEnter = (e) ->
    touches = e.originalEvent.touches
    @isMouseOver = true
    if !touches or touches.length == 1
      e.preventDefault()
      @show e, true
    return

  ###*
  # On move
  # @private
  # @param {Event} e
  ###

  EasyZoom::_onMove = (e) ->
    if !@isOpen
      return
    e.preventDefault()
    @_move e
    return

  ###*
  # On leave
  # @private
  ###

  EasyZoom::_onLeave = ->
    @isMouseOver = false
    @isOpen and @hide()
    return

  ###*
  # On load
  # @private
  # @param {Event} e
  ###

  EasyZoom::_onLoad = (e) ->
# IE may fire a load event even on error so test the image dimensions
    if !e.currentTarget.width
      return
    @isReady = true
    @$notice.detach()
    @$flyout.html @$zoom
    @$target.removeClass('is-loading').addClass 'is-ready'
    e.data.call and e.data()
    return

  ###*
  # On error
  # @private
  ###

  EasyZoom::_onError = ->
    self = this
    @$notice.text @opts.errorNotice
    @$target.removeClass('is-loading').addClass 'is-error'
    @detachNotice = setTimeout((->
      self.$notice.detach()
      self.detachNotice = null
      return
    ), @opts.errorDuration)
    return

  ###*
  # Load image
  # @private
  # @param {String} href
  # @param {Function} callback
  ###

  EasyZoom::_loadImage = (href, callback) ->
    zoom = new Image
    @$target.addClass('is-loading').append @$notice.text(@opts.loadingNotice)
    @$zoom = $(zoom).on('error', $.proxy(@_onError, this)).on('load', callback, $.proxy(@_onLoad, this))
    zoom.style.position = 'absolute'
    zoom.src = href
    return

  ###*
  # Move
  # @private
  # @param {Event} e
  ###

  EasyZoom::_move = (e) ->
    if e.type.indexOf('touch') == 0
      touchlist = e.touches or e.originalEvent.touches
      lx = touchlist[0].pageX
      ly = touchlist[0].pageY
    else
      lx = e.pageX or lx
      ly = e.pageY or ly
    offset = @$target.offset()
    pt = ly - (offset.top)
    pl = lx - (offset.left)
    xt = Math.ceil(pt * rh)
    xl = Math.ceil(pl * rw)
    # Close if outside
    if xl < 0 or xt < 0 or xl > dw or xt > dh
      @hide()
    else
      top = xt * -1
      left = xl * -1
      @$zoom.css
        top: top
        left: left
      @opts.onMove.call this, top, left
    return

  ###*
  # Hide
  ###

  EasyZoom::hide = ->
    if !@isOpen
      return
    if @opts.beforeHide.call(this) == false
      return
    @$flyout.detach()
    @isOpen = false
    @opts.onHide.call this
    return

  ###*
  # Swap
  # @param {String} standardSrc
  # @param {String} zoomHref
  # @param {String|Array} srcset (Optional)
  ###

  EasyZoom::swap = (standardSrc, zoomHref, srcset) ->
    @hide()
    @isReady = false
    @detachNotice and clearTimeout(@detachNotice)
    @$notice.parent().length and @$notice.detach()
    @$target.removeClass 'is-loading is-ready is-error'
    @$image.attr
      src: standardSrc
      srcset: if $.isArray(srcset) then srcset.join() else srcset
    @$link.attr @opts.linkAttribute, zoomHref
    return

  ###*
  # Teardown
  ###

  EasyZoom::teardown = ->
    @hide()
    @$target.off('.easyzoom').removeClass 'is-loading is-ready is-error'
    @detachNotice and clearTimeout(@detachNotice)
    delete @$link
    delete @$zoom
    delete @$image
    delete @$notice
    delete @$flyout
    delete @isOpen
    delete @isReady
    return

  # jQuery plugin wrapper

  $.fn.easyZoom = (options) ->
    @each ->
      api = $.data(this, 'easyZoom')
      if !api
        $.data this, 'easyZoom', new EasyZoom(this, options)
      else if api.isOpen == undefined
        api._init()
      return

  return

# ---
# generated by js2coffee 2.2.0


Spree.ready ($) ->
  Spree.addImageHandlers = ->
    thumbnails = ($ '#product-images ul.thumbnails')
    ($ '#main-image').data 'selectedThumb', ($ '#main-image img').attr('src')
    thumbnails.find('li').eq(0).addClass 'selected'
    thumbnails.find('a').on 'click', (event) ->
      ($ '#main-image').data 'selectedThumb', ($ event.currentTarget).attr('href')
      ($ '#main-image').data 'selectedThumbId', ($ event.currentTarget).parent().attr('id')
      thumbnails.find('li').removeClass 'selected'
      ($ event.currentTarget).parent('li').addClass 'selected'
      false

    thumbnails.find('li').on 'mouseenter', (event) ->
      ($ '#main-image img').attr 'src', ($ event.currentTarget).find('a').attr('href')

    thumbnails.find('li').on 'mouseleave', (event) ->
      ($ '#main-image img').attr 'src', ($ '#main-image').data('selectedThumb')

  Spree.showVariantImages = (variantId) ->
    ($ 'li.vtmb').hide()
    ($ 'li.tmb-' + variantId).show()
    currentThumb = ($ '#' + ($ '#main-image').data('selectedThumbId'))
    if not currentThumb.hasClass('vtmb-' + variantId)
      thumb = ($ ($ '#product-images ul.thumbnails li:visible.vtmb').eq(0))
      thumb = ($ ($ '#product-images ul.thumbnails li:visible').eq(0)) unless thumb.length > 0
#      newImg = thumb.find('a').attr('href')
      newImg = thumb.find('a').data('standard')
      ($ '#product-images ul.thumbnails li').removeClass 'selected'
      thumb.addClass 'selected'
      ($ '#main-image img').attr 'src', newImg
      ($ '#main-image').data 'selectedThumb', newImg
      ($ '#main-image').data 'selectedThumbId', thumb.attr('id')

  Spree.updateVariantPrice = (variant) ->
    variantPrice = variant.find(':selected').data('price')
    ($ '.price.selling').text(variantPrice) if variantPrice
    
  Spree.updateVariantOnHand = (variant) ->
    variantOnHand = variant.find(':selected').data('on-hand')
    ($ 'li.qty.on-hand').text(variantOnHand )


  Spree.disableCartForm = (variant) ->
    inStock = variant.find(':selected').data('in-stock')
    $addToCartButton = $('#add-to-cart-button')
    $addToCartButton.attr('disabled', !inStock)
    if (inStock)
      $addToCartButton.text('Add To Cart')
    else
      $addToCartButton.text('Out of Stock')


  selectElem = $('#variants')

  if selectElem.length > 0
    Spree.showVariantImages selectElem.attr('value')
    Spree.updateVariantPrice selectElem
    Spree.updateVariantOnHand selectElem
    Spree.disableCartForm selectElem

    selectElem.change (event) ->
      Spree.showVariantImages @value
      Spree.updateVariantPrice ($ this)
      Spree.updateVariantOnHand ($ this)
      Spree.disableCartForm ($ this)

#  Spree.addImageHandlers()


