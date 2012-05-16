eToLl = (e, o) ->
  x = e.pageX - o.offsetLeft
  y = e.pageY - o.offsetTop
  lng = 360 * (x / o.width) - 180
  lat = 90 - 180 * (y / o.height)
  {lng, lat}

init = ->
  window.earth = globe.create()
  earth.init container: document.body, width: 500, height: 500, atmosphere: false, globeTexture: '../../natural-earth.jpg'
  cameraController = new globe.Satellite
  cameraTarget = new globe.Satellite
  cameraTarget.setAltitude 0
  cameraController.orbiting = cameraTarget
  cameraController.setPosition {lng: 0, lat: 90}
  cameraController.setAltitude 1
  earth.setCameraController cameraController
  earth.setCameraTarget cameraTarget
  earth.initAnimation()

  $('#altitude').on 'change', (e) ->
    cameraTarget.setAltitude this.value
  $('#distance').on 'change', (e) ->
    cameraController.setAltitude this.value
  $('#lat').on 'change', ->
    cameraController.setPosition lat: this.value
  $('#lng').on 'change', ->
    cameraController.setPosition lng: this.value

  $img = $ 'img'
  $img.on 'mousemove', (e) ->
    cameraTarget.setPosition eToLl(e, this)

$ init
