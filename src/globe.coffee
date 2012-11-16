SIZE = 200

ROTATE_RATE = 0.005
DISTANCE_RATE = 0.015 / 4

MIN_DISTANCE = 350
MAX_DISTANCE = 1000

MAX_ROTATE_Y = Math.PI / 2
MIN_ROTATE_Y = -MAX_ROTATE_Y

ORIGIN = new THREE.Vector3 0, 0, 0

MIN_TARGET_DELTA = 0.005

CIRCLE_IMAGE = do ->
  size = 64
  r = size / 2
  canvas = $("<canvas width='#{size}' height='#{size}'/>").get 0
  ctx = canvas.getContext '2d'
  ctx.fillStyle = '#fff'
  ctx.beginPath()
  ctx.arc r, r, r, 0, Math.PI * 2, true
  ctx.closePath()
  ctx.fill()
  canvas

llToRotationMatrix = (lng, lat) ->
  theta = lng * Math.PI / 180
  phi = (90 - lat) * Math.PI / 180
  m = new THREE.Matrix4
  m.rotateY theta
  m.rotateZ phi
  m

llToXyz = (lng, lat, size=SIZE, pos=new THREE.Vector3) ->
  theta = (180 - lng) * Math.PI / 180
  phi = (90 - lat) * Math.PI / 180

  pos.x = size * Math.sin(phi) * Math.cos(theta)
  pos.y = size * Math.cos(phi)
  pos.z = size * Math.sin(phi) * Math.sin(theta)

  pos

srand = (radius=SIZE) ->
  pos = new THREE.Vector3
  z = Math.random() * 2 - 1
  t = Math.random() * Math.PI * 2
  r = Math.sqrt(1 - z * z) * radius
  pos.z = radius * z
  pos.x = r * Math.cos t
  pos.y = r * Math.sin t

  pos

slerp = (p0, p1, t) ->
  omega = Math.acos(p0.clone().normalize().dot(p1.clone().normalize()))
  sinOmega = Math.sin omega
  fn = (t) ->
    _p0 = p0.clone()
    _p1 = p1.clone()
    _p0.multiplyScalar((Math.sin((1 - t) * omega) / sinOmega)).addSelf(_p1.multiplyScalar(Math.sin(t * omega) / sinOmega))
    _p0
  if t? then fn t else fn

window.globe =
create: ->
  camera = null
  renderer = null
  scene = null
  width = height = null
  onupdate = null
  cameraPositionNormalized = new THREE.Vector3
  forceUpdate = false
  cameraMoved = true
  previousTime = null
  projector = new THREE.Projector
  cameraController = null
  canvasSizeUniform =
    type: 'v2'
    value:
      x: 0
      y: 0

  satellite = new Satellite

  init = (opts={}) ->
    width = opts.width ? 800
    height = opts.height ? 600
    onupdate = opts.onupdate

    renderer = new THREE.WebGLRenderer antialias: true, preserveDrawingBuffer: opts.preserveDrawingBuffer
    renderer.setSize width, height
    opts.container?.appendChild renderer.domElement
    @domElement = renderer.domElement
    renderer.autoClear = false
    renderer.setClearColorHex opts.backgroundColor ? 0x000000, opts.backgroundOpacity ? 1

    camera = new THREE.PerspectiveCamera 30, width / height, 1, 10000
    setCameraController new SimpleCameraController this
    cameraController.satellite = satellite
    canvasSizeUniform.value.x = width
    canvasSizeUniform.value.y = height

    scene = new THREE.Scene
    if opts.atmosphere ? true
      atmosphereColor = opts.atmosphereColor ? 0xffffff
      scene.add globe.createAtmosphere {atmosphereColor}
    else
      atmosphereColor = 0

    if opts.globe ? true
      texture = if opts.globeTexture instanceof THREE.Texture
        opts.globeTexture
        window.setTimeout ->
          opts.onload?()
        ,1
      else
        THREE.ImageUtils.loadTexture opts.globeTexture ? 'world.jpg', null, opts.onload

      scene.add globe.createEarth {texture, atmosphereColor}

    if opts.stars
      scene.add globe.createStars()

    scene.add camera

    renderer.clear()

  resize = (w, h) ->
    width = w
    height = h
    renderer.setSize width, height
    camera.aspect = width / height
    camera.updateProjectionMatrix()

    event = new CustomEvent 'resize', detail: {width, height}, bubbles: false
    renderer.domElement.dispatchEvent event

  initAnimation = ->
    previousTime = + new Date
    nextFrame()

  setCameraController = (controller) ->
    cameraController = controller

  updateCamera = (position, target, up) ->
    camera.position.copy position
    camera.up.copy up if up?
    camera.lookAt target ? scene.position
    cameraPositionNormalized.copy(camera.position).normalize()
    cameraMoved = true

  updatePosition = (time) ->
    deltaT = time - previousTime

    cameraController.update deltaT

    if forceUpdate or cameraMoved
      forceUpdate = false
      cameraMoved = false
      onupdate?()

    previousTime = time

  render = (time) ->
    updatePosition time
    renderer.clear()

    renderer.render scene, camera

  nextFrame = ->
    window.requestAnimationFrame animate, renderer.domElement

  animate = (t) ->
    render t
    nextFrame()

  createLocation = (lng, lat) ->
    pos = llToXyz lng, lat
    projectedPos = pos.clone()
    posNormalized = pos.clone().normalize()

    angle: -> Math.acos(posNormalized.dot cameraPositionNormalized)
    screenPosition: ->
      projectedPos.copy pos
      screen = projector.projectVector projectedPos, camera
      x: width * (screen.x + 1) / 2
      y: height * (-screen.y + 1) / 2

  updated = ->
    forceUpdate = true

  createParticles = (opts) ->
    textures = opts.textures ? {default: opts.texture ? CIRCLE_IMAGE}

    fragmentShaderTextures = ""
    fragmentShaderTextureSelection = []

    textureInfo =
      none: {num: -1, scale: 0}

    uniforms = {}

    num = 0
    for name, image of textures
      uniformName = "texture_#{num}"
      texture = new THREE.Texture image
      texture.needsUpdate = true
      # FIXME figure out why this is necessary
      # https://github.com/also/globe/issues/7
      texture.minFilter = THREE.LinearFilter
      if image.width == image.height
        scale = new THREE.Vector2 1, 1
      else if image.width < image.height
        scale = new THREE.Vector2 image.height / image.width, 1
      else
        scale = new THREE.Vector2 1, image.width / image.height

      uniforms[uniformName] =
        type: 't'
        value: num
        texture: texture
      fragmentShaderTextures += "uniform sampler2D #{uniformName};\n"
      fragmentShaderTextureSelection.push "if (f_textureNum == #{num}.0) {color = texture2D(#{uniformName}, position);}"
      textureInfo[name] = {num, scale}
      num += 1

    defaultTexture = textureInfo.default ? textureInfo.none

    attributes =
      size:
        type: 'f'
        value: []
      particleColor:
        type: 'c'
        value: []
      particleOpacity:
        type: 'f'
        value: []
      textureNum:
        type: 'f'
        value: []
      textureScale:
        type: 'v2'
        value: []

    shader = shaders.particle
    vertexShader = shader.vertexShader
    if opts.sizeAttenuation ? true
      vertexShader = '#define USE_SIZEATTENUATION\n' + vertexShader
      uniforms.canvasSize = THREE.UniformsUtils.clone(canvasSize: canvasSizeUniform).canvasSize

      renderer.domElement.addEventListener 'resize', ({detail: {width, height}}) ->
        uniforms.canvasSize.value.x = width
        uniforms.canvasSize.value.y = height
        uniforms.canvasSize.needsUpdate = true

    fragmentShader = fragmentShaderTextures + shader.fragmentShader.replace('// TEXTURE SELECTION', fragmentShaderTextureSelection.join('\n else\n '))

    material = new THREE.ShaderMaterial
      transparent: true
      vertexShader: vertexShader
      fragmentShader: fragmentShader
      attributes: attributes
      uniforms: uniforms

    geometry = new THREE.Geometry

    particles = for i in [0...opts.particleCount]
      position = new THREE.Vector3
      do (position, i) ->
        normalizedPosition = new THREE.Vector3
        altitude = 0
        origin = destination = null
        slerpP = null

        setTexture = (t) ->
          attributes.textureNum.value[i] = t.num
          attributes.textureNum.needsUpdate = true
          attributes.textureScale.value[i] = t.scale
          attributes.textureScale.needsUpdate

        p =
          position: position
          altitude: 0
          reset: ->
            @setPosition 0,0
            @setSize opts.size ? 1
            @setColor new THREE.Color opts.color ? 0xffffff
            @setOpacity opts.opacity ? 1
            setTexture defaultTexture
          setPosition: (lng, lat) ->
            normalizedPosition.copy llToXyz lng, lat, 1
            @setAltitude altitude
          setSize: (size) ->
            attributes.size.value[i] = size
            attributes.size.needsUpdate = true
          setColor: (color) ->
            attributes.particleColor.value[i] = color
            attributes.particleColor.needsUpdate = true
          setOpacity: (opacity) ->
            attributes.particleOpacity.value[i] = opacity
            attributes.particleOpacity.needsUpdate = true
          setOrigin: (lng, lat) ->
            origin = llToXyz lng, lat, 1
            updateSlerp()
          setDestination: (lng, lat) ->
            destination = llToXyz lng, lat, 1
            updateSlerp()
          setPositionMix: (t) ->
            normalizedPosition = slerpP t
            @setAltitude altitude
          setAltitude: (altitude) ->
            position.copy(normalizedPosition).multiplyScalar SIZE * (1 + altitude)
            geometry.verticesNeedUpdate = true
          setTexture: (name) ->
            t = textureInfo[name]
            setTexture t

        updateSlerp = ->
          if origin? and destination?
            slerpP = slerp origin, destination
            p.distance = Math.acos(origin.clone().dot(destination)) / Math.PI

        p.reset()

        geometry.vertices.push(position)
        p

    add = ->
      ps = new THREE.ParticleSystem(
        geometry,
        material,
      )
      ps.sortParticles = true
      scene.add ps

    {add, particles}

  createBarChart = (opts={}) ->
    points = []
    defaultPointColor = new THREE.Color
    opts.defaultDimension ?= 0.75
    defaultPointGeometry = new THREE.CubeGeometry opts.defaultDimension, opts.defaultDimension, 1
    defaultPointGeometry.vertices.forEach (v) -> v.z += 0.5

    geometry = new THREE.Geometry
    # making the geometry dynamic is necessary to have three.js update custom
    # attributes on the mesh created from the geometry. weird. this changed at
    # some point after https://github.com/mrdoob/three.js/issues/267 when
    # dynamic was set on the mesh
    geometry.dynamic = true

    uniforms = {}
    attributes =
      size:
        type: 'f'
        value: []
      customPosition:
        type: 'v3'
        value: []

    if opts.customColor
      attributes.customColor =
        type: 'c'
        value: []

    if opts.sizeTarget
      attributes.sizeTarget =
        type: 'f'
        value: []
      uniforms.sizeTargetMix =
        type: 'f'
        value: 0

    createBar = (lng, lat, pointGeometry=defaultPointGeometry) ->
      vertexOffset = geometry.vertices.length
      vertexCount = pointGeometry.vertices.length

      THREE.GeometryUtils.merge geometry, pointGeometry

      pos = llToXyz(lng, lat)

      set = (name, value) ->
        attribute = attributes[name]
        attribute.value[i] = value for i in [vertexOffset...vertexOffset + vertexCount]
        attribute.needsUpdate = true

      set 'customPosition', pos

      setSize = (@size) -> set 'size', @size

      setSizeTarget = (@sizeTarget) -> set 'sizeTarget', @sizeTarget

      mix = (sizeTargetMix) ->
        @setSize @size + (@sizeTarget - @size) * sizeTargetMix

      setColor = (color) -> set 'color', color

      p = {setSize, setSizeTarget, mix, setColor}

      # firefox likes it better if we explicitly set the size the first time.
      # chrome doesn't seem to care
      p.setSize 0
      if opts.sizeTarget
        p.setSizeTarget 0
      if opts.customColor
        p.setColor defaultPointColor

      points.push(p)
      p

    setSizes = (sizes, m=1) ->
      points[i].setSize s * m for s, i in sizes

    setSizeTargets = (sizeTargets, m=1) ->
      points[i].setSizeTarget t * m for t, i in sizeTargets

    setSizeTargetMix = (@sizeTargetMix) ->
      uniforms.sizeTargetMix.value = sizeTargetMix

    mix = (sizeTargetMix=@sizeTargetMix ? 0) ->
      p.mix sizeTargetMix for p in points
      @setSizeTargetMix 0

    add = ->
      vertexShader = shaders.point.vertexShader
      if opts.customColor
        vertexShader = "#define USE_CUSTOM_COLOR;\n" + vertexShader
      if opts.sizeTarget
        vertexShader = "#define USE_SIZE_TARGET;\n" + vertexShader

      scene.add new THREE.Mesh geometry, new THREE.ShaderMaterial(
        uniforms: uniforms
        attributes: attributes
        vertexShader: vertexShader
        fragmentShader: shaders.point.fragmentShader
      )

    {points, createBar, add, setSizes, setSizeTargets, setSizeTargetMix, mix}

  {
    init,
    initAnimation,
    resize,
    render,
    createBarChart,
    createParticles,
    updated,
    createLocation,
    satellite,
    setCameraController,
    updateCamera
  }

createEarth: (opts) ->
  shader = shaders.earth
  uniforms = THREE.UniformsUtils.clone shader.uniforms
  uniforms.atmosphereColor.value = new THREE.Color opts.atmosphereColor
  uniforms.texture.texture = opts.texture
  material = new THREE.ShaderMaterial(
    uniforms: uniforms
    vertexShader: shader.vertexShader
    fragmentShader: shader.fragmentShader
  )

  geometry = new THREE.SphereGeometry SIZE, 100, 50
  mesh = new THREE.Mesh geometry, material

  # https://github.com/mrdoob/three.js/issues/1123
  mesh.rotation.y = Math.PI
  mesh.updateMatrix()

  mesh.matrixAutoUpdate = false
  mesh

createAtmosphere: (opts) ->
  shader = shaders.atmosphere
  uniforms = THREE.UniformsUtils.clone(shader.uniforms)
  uniforms.color.value = new THREE.Color opts.atmosphereColor
  material = new THREE.ShaderMaterial(
    uniforms: uniforms
    vertexShader: shader.vertexShader
    fragmentShader: shader.fragmentShader
  )
  geometry = new THREE.SphereGeometry SIZE, 100, 50
  mesh = new THREE.Mesh geometry, material
  mesh.scale.set 1.4, 1.4, 1.4
  mesh.flipSided = true
  mesh.matrixAutoUpdate = false
  mesh.updateMatrix()
  mesh

createStars: ->
  geometry = new THREE.Geometry
  for i in [1..800]
    v = srand(SIZE * 10 + Math.random() * SIZE * 5)
    geometry.vertices.push v

  texture = new THREE.Texture CIRCLE_IMAGE
  texture.needsUpdate = true

  material = new THREE.ParticleBasicMaterial
    size: 12
    map: texture
    blending: THREE.AdditiveBlending
    transparent : true

  material.color.setHSV .65, .0, .5

  ps = new THREE.ParticleSystem geometry, material
  ps.updateMatrix()
  ps

circle: CIRCLE_IMAGE
llToXyz: llToXyz
slerp: slerp
observeMouse: (camera, target, {type, distanceRange}={}) ->
  eventTypes =
    mouse:
      start: 'mousedown'
      move:  'mousemove'
      end:   'mouseup mouseleave'
    touch:
      start: 'touchstart'
      move:  'touchmove'
      end:   'touchend'

  type ?= 'mouse'
  distanceRange ?= [1.5, 10]

  events = eventTypes[type]

  mouseDown = null
  targetDown = null

  position = (e) ->
    if e.originalEvent.touches?
      e = e.originalEvent.touches[0]
    x: -e.clientX, y: e.clientY

  $domElement = $(target)
  $domElement.bind 'mousewheel', (e) ->
    newDistance = camera.distanceTarget - e.originalEvent.wheelDeltaY * (0.005)
    camera.setDistanceTarget Math.min(Math.max(distanceRange[0], newDistance), distanceRange[1])
    e.preventDefault()

  mouseup = (e) ->
    $domElement
      .unbind(events.move, mousemove)
      .unbind(events.end, mouseup)
    $domElement.css 'cursor', ''

  mousemove = (e) ->
    mouse = position e
    zoomDamp = (camera.distance * SIZE) / 1000

    if !e.originalEvent.touches? or e.originalEvent.touches.length == 1
      camera.setPositionTarget
        lng: targetDown.lng + (mouse.x - mouseDown.x) * .25 * zoomDamp
        lat: Math.max -90, Math.min(89, targetDown.lat + (mouse.y - mouseDown.y) * .25 * zoomDamp)

    scale = e.originalEvent.scale
    if scale?
      camera.setDistanceTarget Math.min 10, Math.max(1.3, camera.distanceTarget + ((scale - 1) / -10))

  $domElement.bind events.start, (e) ->
    e.preventDefault()
    $domElement.bind events.move, mousemove

    $domElement.bind events.end, mouseup

    mouseDown = position e
    targetDown = lng: camera.positionTarget.lng, lat: camera.positionTarget.lat

    $domElement.css 'cursor', 'move'

Satellite: class Satellite
  constructor: ->
    @updated = true
    @moving = false
    @position =
      lng: 0
      lat: 0
    @positionTarget =
      lng: 0
      lat: 0
    @distance = 5
    @distanceTarget = 5

  setPosition: ({lng, lat}) ->
    lng ?= @position.lng
    lat ?= @position.lat
    @position = {lng, lat}
    @positionTarget = {lng, lat}
    @updated = true

  setPositionTarget: ({lng, lat}) ->
    lng ?= @positionTarget.lng
    lat ?= @positionTarget.lat
    @positionTarget = {lng, lat}
    @moving = true

  movePositionTarget: ({lng, lat}) ->
    lng = @positionTarget.lng + (lng ? 0)
    lat = @positionTarget.lat + (lat ? 0)
    @setPositionTarget {lng, lat}

  setAltitude: (altitude) ->
    @setDistance altitude + 1

  setDistance: (@distance) ->
    @distanceTarget = @distance
    @updated = true

  setAltitudeTarget: (altitudeTarget) ->
    @setDistanceTarget altitudeTarget + 1

  setDistanceTarget: (@distanceTarget) ->
    @moving = true

  update: (deltaT) ->
    if @moving
      moved = false
      rotateDistance = Math.min(1, ROTATE_RATE * deltaT)
      if Math.abs(@positionTarget.lng - @position.lng) < MIN_TARGET_DELTA
        @position.lng = @positionTarget.lng
      else
        moved = true
        @position.lng += (@positionTarget.lng - @position.lng) * rotateDistance

      if Math.abs(@positionTarget.lat - @position.lat) < MIN_TARGET_DELTA
        @position.lat = @positionTarget.lat
      else
        moved = true
        @position.lat += (@positionTarget.lat - @position.lat) * rotateDistance

      if Math.abs(@distanceTarget - @distance) < MIN_TARGET_DELTA
        @distance = @distanceTarget
      else
        moved = true
        @distance += (@distanceTarget - @distance) * Math.min(1, DISTANCE_RATE * deltaT)
      @moving = moved
    result = @moving or @updated
    @updated = false

    if @orbiting
      orbitingUpdated = @orbiting.update(deltaT)
      result or= orbitingUpdated
      if result
        # TODO move into orbiting
        @matrix = llToRotationMatrix @orbiting.position.lng, @orbiting.position.lat

    result

  toCartesian: (target) ->
    if @orbiting
      llToXyz @position.lng, @position.lat, SIZE * @distance, target
      @matrix.multiplyVector3 target
      orbitingPosition = @orbiting.toCartesian new THREE.Vector3
      target.addSelf orbitingPosition
    else
      llToXyz @position.lng, @position.lat, SIZE * @distance, target

SimpleCameraController: class SimpleCameraController
  constructor: (@context) ->
    @positionCartesian = new THREE.Vector3
    @up = new THREE.Vector3 0, 1, 0

  update: (deltaT) ->
    if @satellite.update deltaT
      @satellite.toCartesian @positionCartesian
      @context.updateCamera @positionCartesian, @target, @up

shaders =
  earth:
    uniforms:
      texture:
        type: 't'
        value: 0
        texture: null
      atmosphereColor:
        type: 'c'
    vertexShader: """
      varying vec3 vNormal;
      varying vec2 vUv;
      void main() {
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        vNormal = normalize(normalMatrix * normal);
        vUv = uv;
      }
    """
    fragmentShader: """
      uniform sampler2D texture;
      varying vec3 vNormal;
      varying vec2 vUv;
      uniform vec3 atmosphereColor;
      void main() {
        vec3 diffuse = texture2D(texture, vUv).xyz;
        float intensity = 1.05 - dot(vNormal, vec3(0.0, 0.0, 1.0));
        vec3 atmosphere = atmosphereColor * pow(intensity, 3.0);
        gl_FragColor = vec4(diffuse + atmosphere, 1.0);
      }
    """
  atmosphere:
    uniforms:
      color:
        type: 'c'
    vertexShader: """
      varying vec3 vNormal;
      void main() {
        vNormal = normalize(normalMatrix * normal);
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    """
    fragmentShader: """
      varying vec3 vNormal;
      uniform vec3 color;
      void main() {
        float intensity = pow(0.5 - dot(vNormal, vec3(0, 0, 1.0)), 4.0);
        gl_FragColor = vec4(color, 0.6) * intensity;
      }
    """
  point:
    vertexShader: """
      varying vec4 f_color;
      attribute float size;
      attribute vec3 customPosition;

      #ifdef USE_SIZE_TARGET
        attribute float sizeTarget;
        uniform float sizeTargetMix;
      #endif

      #ifdef USE_CUSTOM_COLOR
        attribute vec3 customColor;
      #endif

      // found, randomly, at https://www.h3dapi.org:8090/MedX3D/trunk/MedX3D/src/shaders/StyleFunctions.glsl
      vec3 HSVtoRGB(float h, float s, float v) {
        if (s == 0.0) return vec3(v);

        h /= 60.0;
        int i = int(floor(h));
        float f = h - float(i);
        float p = v * (1.0 - s);
        float q = v * (1.0 - s * f);
        float t = v * (1.0 - s * (1.0 - f));

        if (i == 0) return vec3(v,t,p);
        if (i == 1) return vec3(q,v,p);
        if (i == 2) return vec3(p,v,t);
        if (i == 3) return vec3(p,q,v);
        if (i == 4) return vec3(t,p,v);
                    return vec3(v,p,q);
      }

      void main() {
        float mixedSize = size;
        #ifdef USE_SIZE_TARGET
          mixedSize = mix(size, sizeTarget, sizeTargetMix);
        #endif
        // look at the origin
        vec3 lz = normalize(-customPosition);
        if (length(lz) == 0.0) {
          lz.z = 1.0;
        }
        vec3 lup = vec3(0,1,0);
        vec3 lx = normalize(cross(lup, lz));
        if (length(lx) == 0.0) {
          lz.x = lx.x + 0.0001;
          lx = normalize(cross(lup, lz));
        }
        vec3 ly = normalize(cross(lz, lx));

        lz *= -mixedSize * #{SIZE.toFixed(1)};
        mat4 customMat = mat4(lx, 0,
                         ly, 0,
                         lz, 0,
                         customPosition,1);
        gl_Position =  projectionMatrix  *
                      modelViewMatrix *
                      customMat *
                      vec4(position.x, position.y, position.z,1);

        #ifdef USE_CUSTOM_COLOR
          f_color = vec4(customColor, 1.0);
        #endif
        #ifndef USE_CUSTOM_COLOR
          f_color = vec4(HSVtoRGB((0.6 - mixedSize * 0.5) * 360.0, 1.0, 1.0), 1.0);
        #endif
      }
    """
    fragmentShader: """
      varying vec4 f_color;
      void main() {
        gl_FragColor = f_color;
      }
    """
  particle:
    vertexShader: """
      attribute float size;
      uniform vec2 canvasSize;
      attribute vec3 particleColor;
      attribute float particleOpacity;
      attribute float textureNum;
      attribute vec2 textureScale;
      varying vec4 f_color;
      varying float f_textureNum;
      varying vec2 f_textureScale;

      void main() {
        vec4 mvPosition = modelViewMatrix * vec4( position, 1.0 );
        gl_Position = projectionMatrix * mvPosition;
        #ifdef USE_SIZEATTENUATION
          gl_PointSize = size * (canvasSize.y / length(mvPosition.xyz));
        #else
          gl_PointSize = size;
        #endif
        f_color = vec4(particleColor, particleOpacity);
        f_textureNum = textureNum;
        f_textureScale = textureScale;
      }
    """
    fragmentShader: """
      varying vec4 f_color;
      varying float f_textureNum;
      varying vec2 f_textureScale;

      void main() {
        vec4 color;
        if (f_textureNum < 0.0) {
          gl_FragColor = f_color;
        }
        else {
          vec2 position = vec2(gl_PointCoord.x, 1.0 - gl_PointCoord.y) * f_textureScale;
          if (position.x >= 0.0 && position.x <= 1.0 && position.y >= 0.0 && position.y <= 1.0) {
            // TEXTURE SELECTION
            gl_FragColor = f_color * color;
          }
          else {
            gl_FragColor = vec4(0,0,0,0);
          }
        }
      }
    """
