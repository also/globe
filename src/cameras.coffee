class globe.Arc
  constructor: ({@origin, @destination, @before, @after, @distance}) ->
    @before ?= 0
    @after ?= 0
    @range = 1 + @before + @after
    @originCartesian = globe.llToXyz @origin.lng, @origin.lat, 1
    @destinationCartesian = globe.llToXyz @destination.lng, @destination.lat, 1
    @targetCartesian = globe.llToXyz @destination.lng, @destination.lat, 200
    @distance = Math.acos(@originCartesian.clone().dot(@destinationCartesian)) / Math.PI
    @slerp = globe.slerp @originCartesian, @destinationCartesian

  interpolate: (p) ->
    @slerp(p * @range - @before).multiplyScalar 300

class globe.CameraTrack
  toCartesian = (arc, p) ->
    if arc.interpolate?
      arc.interpolate p
    else if arc.lat
      globe.llToXyz arc.lng, arc.lat, (arc.distance ? 1) * 200
    else arc

  constructor: ({@position, @target, @up, @tween}) ->

  update: (p) ->
    p = @tween p if @tween?
    position = toCartesian @position, p
    target = toCartesian @target, p
    up = if @up?
      toCartesian @up, p
    else
      position
    position: position
    target: target
    up: up

class globe.CameraTrackController
  constructor: (@context, @track, @duration, @oncomplete)->
    @t = 0

  update: (deltaT) ->
    @t += deltaT
    if @t > @duration
      @oncomplete?()
    else
      {position, target, up} = @track.update @t / @duration
      @context.updateCamera position, target, up

globe.createFlyByTrack = (origin, destination) ->
  new globe.CameraTrack
    position: new globe.Arc
      origin: {lng: origin.lng, lat: origin.lat}
      destination: {lng: destination.lng, lat: destination.lat - 10}
      distance: 1.5
      before: 1
      after: 0.25
    target: {lng: destination.lng, lat: destination.lat, distance: 1}
    tween: (p) -> Math.sin p * Math.PI / 2

globe.createCircleTrack = (target, start=-180, end=180) ->
  range = end - start

  targetSatellite = new globe.Satellite
  targetSatellite.setPosition target
  targetSatellite.setAltitude 0
  positionSatellite = new globe.Satellite
  positionSatellite.setPosition lng: 0, lat: 45
  positionSatellite.setAltitude -0.5
  positionSatellite.orbiting = targetSatellite
  positionCartesian = new THREE.Vector3

  new globe.CameraTrack
    position: interpolate: (p) ->
      positionSatellite.setPosition lng: p * range + start
      positionSatellite.update 0
      positionSatellite.toCartesian positionCartesian
      positionCartesian
    target: {lng: target.lng, lat: target.lat, distance: 1.05}

globe.createPanCameraTrack = (target, start=-180, end=180) ->
  range = end - start

  centerSatellite = new globe.Satellite
  centerSatellite.setPosition lng: target.lng, lat: target.lat
  centerSatellite.setDistance 0.7
  targetSatellite = new globe.Satellite
  targetSatellite.setPosition lng: 0, lat: 0
  targetSatellite.setDistance 0.5
  targetSatellite.orbiting = centerSatellite
  targetCartesian = new THREE.Vector3

  new globe.CameraTrack
    position: {lng: target.lng, lat: target.lat - 30, distance: 1.5}
    target: interpolate: (p) ->
      targetSatellite.setPosition lng: 180 + (p * range + start)
      targetSatellite.update 0
      targetSatellite.toCartesian targetCartesian
      targetCartesian
    up: target

globe.createRiseCameraTrack = (target) ->
  positionCartesian = globe.llToXyz target.lng, target.lat - 30, 1
  targetCartesian = globe.llToXyz target.lng, target.lat, 1
  new globe.CameraTrack
    position: interpolate: (p) ->
      positionCartesian.clone().multiplyScalar p * 100 + 300
    target: interpolate: (p) ->
      targetCartesian.clone().multiplyScalar p * 80 + 170

