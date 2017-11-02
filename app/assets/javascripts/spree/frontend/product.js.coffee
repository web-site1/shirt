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
      newImg = thumb.find('a').attr('href')
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

  Spree.addImageHandlers()
