eToLl = (e, o) ->
  x = e.pageX - o.offsetLeft
  y = e.pageY - o.offsetTop
  lng = 360 * (x / o.width) - 180
  lat = 90 - 180 * (y / o.height)
  {lng, lat}

class SphericalCameraController
  constructor: (@context) ->
    @target = new globe.Satellite
    @position = new globe.Satellite
    @target.setAltitude 0

    @position.orbiting = @target
    @position.setPosition lng: 0, lat: 89
    @position.setAltitude 1

    @positionCartesian = new THREE.Vector3
    @targetCartesian = new THREE.Vector3

  update: (deltaT) ->
    if @position.update deltaT
      @position.toCartesian @positionCartesian
      @target.toCartesian @targetCartesian
      @context.updateCamera @positionCartesian, @targetCartesian, @positionCartesian

init = ->
  window.earth = globe.create()
  earth.init container: document.body, width: 500, height: 500, atmosphere: false, globeTexture: '../../natural-earth.jpg'
  controller = new SphericalCameraController earth
  earth.setCameraController controller
  earth.initAnimation()

  $('#altitude').on 'change', (e) ->
    controller.target.setAltitude this.value
  $('#distance').on 'change', (e) ->
    controller.position.setAltitude this.value
  $('#lat').on 'change', ->
    controller.position.setPosition lat: this.value
  $('#lng').on 'change', ->
    controller.position.setPosition lng: this.value

  $img = $ 'img'
  $img.on 'mousemove', (e) ->
    cameraTarget.setPosition eToLl(e, this)

$ init
