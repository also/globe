init = ->
  window.earth = globe.create()
  earth.init container: document.body, width: 500, height: 500, atmosphere: false, globeTexture: '../../natural-earth.jpg'
  earth.initAnimation()

  $altitude = $ '#altitude'
  $altitude.on 'change', (e) ->
    earth.satellite.setAltitude parseFloat($altitude.val(), 10)

  $img = $ 'img'
  $img.on 'mousemove', (e) ->
    x = e.pageX - this.offsetLeft
    y = e.pageY - this.offsetTop
    lng = 360 * (x / this.width) - 180
    lat = 90 - 180 * (y / this.height)
    earth.satellite.setPosition {lng, lat}

$ init
