SIZE = 200

ROTATE_RATE = 0.005
DISTANCE_RATE = 0.015

MIN_DISTANCE = 350
MAX_DISTANCE = 1000

MAX_ROTATE_Y = Math.PI / 2
MIN_ROTATE_Y = -MAX_ROTATE_Y

ORIGIN = new THREE.Vector3 0, 0, 0

MIN_TARGET_DELTA = 0.0001

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

llToXyz = (lng, lat, size=SIZE) ->
  phi = (90 - lat) * Math.PI / 180
  theta = (180 - lng) * Math.PI / 180

  pos = new THREE.Vector3
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
  earthTexture = null
  atmosphereColor = null
  width = height = null
  onupdate = null
  cameraPositionNormalized = new THREE.Vector3
  forceUpdate = false
  previousTime = null
  projector = new THREE.Projector

  distance = 100000
  distanceTarget = 1000

  rotation =
    x: 0
    y: 0

  rotationTarget =
    x: Math.PI * 3/2
    y: Math.PI / 6.0

  init = (opts={}) ->
    width = opts.width ? 800
    height = opts.height ? 600
    backgroundColor = opts.backgroundColor ? 0x000000
    atmosphereColor = opts.atmosphereColor ? 0xffffff
    onupdate = opts.onupdate

    renderer = new THREE.WebGLRenderer antialias: true, preserveDrawingBuffer: opts.preserveDrawingBuffer
    renderer.setSize width, height
    opts.container?.appendChild renderer.domElement
    @domElement = renderer.domElement
    renderer.autoClear = false
    renderer.setClearColorHex backgroundColor, opts.backgroundOpacity ? 1

    camera = new THREE.PerspectiveCamera 30, width / height, 1, 10000
    camera.position.z = distance

    scene = new THREE.Scene
    if opts.atmosphere ? true
      scene.add createAtmosphere()
    else
      atmosphereColor = 0

    if opts.globe ? true
      earthTexture = THREE.ImageUtils.loadTexture opts.globeTexture ? 'world.jpg', null, opts.onLoad
      scene.add createEarth()

    if opts.stars
      scene.add createStars()

    scene.add camera

    renderer.clear()

  resize = (w, h) ->
    width = w
    height = h
    renderer.setSize width, height
    camera.aspect = width / height
    camera.updateProjectionMatrix()

  createEarth = ->
    shader = shaders.earth
    uniforms = THREE.UniformsUtils.clone(shader.uniforms)
    uniforms.atmosphereColor.value = new THREE.Color atmosphereColor
    uniforms.texture.texture = earthTexture
    material = new THREE.ShaderMaterial(
      uniforms: uniforms
      vertexShader: shader.vertexShader
      fragmentShader: shader.fragmentShader
    )

    geometry = new THREE.SphereGeometry SIZE, 40, 30
    mesh = new THREE.Mesh geometry, material

    # https://github.com/mrdoob/three.js/issues/1123
    mesh.rotation.y = Math.PI
    mesh.updateMatrix()

    mesh.matrixAutoUpdate = false
    mesh

  createAtmosphere = ->
    shader = shaders.atmosphere
    uniforms = THREE.UniformsUtils.clone(shader.uniforms)
    uniforms.color.value = new THREE.Color atmosphereColor
    material = new THREE.ShaderMaterial(
      uniforms: uniforms
      vertexShader: shader.vertexShader
      fragmentShader: shader.fragmentShader
    )
    geometry = new THREE.SphereGeometry SIZE, 40, 30
    mesh = new THREE.Mesh geometry, material
    mesh.scale.set 1.4, 1.4, 1.4
    mesh.flipSided = true
    mesh.matrixAutoUpdate = false
    mesh.updateMatrix()
    mesh

  createStars = ->
    geometry = new THREE.Geometry
    for i in [1..800]
      v = new THREE.Vertex srand(SIZE * 10 + Math.random() * SIZE * 5)
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

  createParticles = (opts) ->
    textures = opts.textures ? {default: opts.texture ? CIRCLE_IMAGE}

    fragmentShaderTextures = ""
    fragmentShaderTextureSelection = []

    uniforms = {}
    num = 0
    for name, image of textures
      uniformName = "texture_#{num}"
      image.num = num
      texture = new THREE.Texture image
      texture.needsUpdate = true
      # FIXME figure out why this is necessary
      # https://github.com/also/globe/issues/7
      texture.minFilter = THREE.LinearFilter
      uniforms[uniformName] =
        type: 't'
        value: num
        texture: texture
      fragmentShaderTextures += "uniform sampler2D #{uniformName};\n"
      fragmentShaderTextureSelection.push "if (f_textureNum == #{num}.0) {color = texture2D(#{uniformName}, vec2(gl_PointCoord.x, 1.0 - gl_PointCoord.y));}"
      num += 1

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

    shader = shaders.particle
    fragmentShader = fragmentShaderTextures + shader.fragmentShader.replace('// TEXTURE SELECTION', fragmentShaderTextureSelection.join('\n else\n '))

    material = new THREE.ShaderMaterial
      transparent: true
      vertexShader: shader.vertexShader
      fragmentShader: fragmentShader
      attributes: attributes
      uniforms: uniforms

    geometry = new THREE.Geometry

    particles = for i in [0...opts.particleCount]
      v = new THREE.Vertex
      do (v, i) ->
        position = new THREE.Vector3
        normalizedPosition = new THREE.Vector3
        altitude = 0
        origin = destination = null
        slerpP = null

        setTextureNum = (num) ->
          attributes.textureNum.value[i] = num
          attributes.textureNum.needsUpdate = true

        p =
          altitude: 0
          reset: ->
            @setPosition 0,0
            @setSize opts.size ? 1
            @setColor new THREE.Color opts.color ? 0xffffff
            @setOpacity opts.opacity ? 1
            setTextureNum 0
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
            v.position = position
            geometry.__dirtyVertices = true
          setTexture: (name) ->
            num = textures[name].num
            setTextureNum num

        updateSlerp = ->
          if origin? and destination?
            slerpP = slerp origin, destination
            p.distance = Math.acos(origin.clone().dot(destination)) / Math.PI

        p.reset()

        geometry.vertices.push(v)
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
    defaultPointGeometry.vertices.forEach (v) -> v.position.z += 0.5

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

      attributes.customPosition.value[i] = pos for i in [vertexOffset...vertexOffset + vertexCount]
      attributes.customPosition.needsUpdate = true

      setSize = (@size) ->
        attributes.size.value[i] = size for i in [vertexOffset...vertexOffset + vertexCount]
        attributes.size.needsUpdate = true

      setSizeTarget = (@sizeTarget) ->
        attributes.sizeTarget.value[i] = sizeTarget for i in [vertexOffset...vertexOffset + vertexCount]
        attributes.sizeTarget.needsUpdate = true

      mix = (sizeTargetMix) ->
        @setSize @size + (@sizeTarget - @size) * sizeTargetMix

      setColor = (color) ->
        attributes.customColor.value[i] = color for i in [vertexOffset...vertexOffset + vertexCount]
        attributes.customColor.needsUpdate = true

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

  observeMouse = (target=renderer.domElement)->
    mouseDown = null
    targetDown = null
    rotationTargetDown = null

    $domElement = $(target)
    $domElement.bind 'mousewheel', (e) ->
      moveZoomTarget(e.originalEvent.wheelDeltaY * 0.3)
      e.preventDefault()

    mouseup = (e) ->
      removeMouseMoveEventListeners()
      $domElement.css 'cursor', ''

    mousemove = (e) ->
      mouse = x: -e.clientX, y: e.clientY
      zoomDamp = distance / 1000

      rotationTarget.x = targetDown.x + (mouse.x - mouseDown.x) * 0.005 * zoomDamp
      rotationTarget.y = targetDown.y + (mouse.y - mouseDown.y) * 0.005 * zoomDamp

      rotationTarget.y = Math.max MIN_ROTATE_Y, Math.min(MAX_ROTATE_Y, rotationTarget.y)

    removeMouseMoveEventListeners = ->
      $domElement
        .unbind('mousemove')
        .unbind('mouseup', mouseup)

    $domElement.bind 'mousedown', (e) ->
      e.preventDefault()
      $domElement.bind 'mousemove', mousemove

      $domElement.bind 'mouseup', mouseup

      $domElement.bind 'mouseleave', (e) ->
        removeMouseMoveEventListeners()

      mouseDown = x: -e.clientX, y: e.clientY
      targetDown = x: rotationTarget.x, y: rotationTarget.y

      $domElement.css 'cursor', 'move'

  initAnimation = ->
    previousTime = + new Date
    nextFrame()

  updatePosition = (time) ->
    deltaT = time - previousTime
    updated = false
    if Math.abs(rotationTarget.x - rotation.x) < MIN_TARGET_DELTA
      rotation.x = rotationTarget.x
    else
      updated = true
      rotation.x += (rotationTarget.x - rotation.x) * Math.min(1, ROTATE_RATE * deltaT)
    if Math.abs(rotationTarget.y - rotation.y) < MIN_TARGET_DELTA
      rotation.y = rotationTarget.y
    else
      updated = true
      rotation.y += (rotationTarget.y - rotation.y) * Math.min(1, ROTATE_RATE * deltaT)
    if Math.abs(distanceTarget - distance) < MIN_TARGET_DELTA
      distance = distanceTarget
    else
      updated = true
      distance += (distanceTarget - distance) * Math.min(1, DISTANCE_RATE * deltaT)

    camera.position.x = distance * Math.sin(rotation.x) * Math.cos(rotation.y)
    camera.position.y = distance * Math.sin(rotation.y)
    camera.position.z = distance * Math.cos(rotation.x) * Math.cos(rotation.y)

    # you need to update lookAt every frame

    if updated or forceUpdate
      cameraPositionNormalized.copy(camera.position).normalize()
      camera.lookAt scene.position
      forceUpdate = false
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

  moveZoomTarget = (amount, clamp=true) ->
    distanceTarget -= amount
    if clamp
      distanceTarget = Math.max Math.min(distanceTarget, MAX_DISTANCE), MIN_DISTANCE

  setZoomTarget = (zoom) ->
    distanceTarget = zoom

  setZoom = (zoom) ->
    distance = distanceTarget = zoom
    forceUpdate = true

  setRotation = (x, y) ->
    rotation = {x, y}
    rotationTarget = {x, y}
    forceUpdate = true

  setRotationTarget = (x, y) ->
    x ?= rotationTarget.x
    y ?= rotationTarget.y
    rotationTarget = {x, y}

  moveRotationTarget = (x, y) ->
    rotationTarget.x += x
    rotationTarget.y += y

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

  {
    init,
    initAnimation,
    resize,
    render,
    observeMouse,
    setZoom,
    setZoomTarget,
    moveZoomTarget,
    setRotation,
    setRotationTarget,
    moveRotationTarget,
    createBarChart,
    createParticles,
    updated,
    createLocation
  }

circle: CIRCLE_IMAGE

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
      attribute vec3 particleColor;
      attribute float particleOpacity;
      attribute float textureNum;
      varying vec4 f_color;
      varying float f_textureNum;

      void main() {
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        gl_PointSize = size;
        f_color = vec4(particleColor, particleOpacity);
        f_textureNum = textureNum;
      }
    """
    fragmentShader: """
      varying vec4 f_color;
      varying float f_textureNum;

      void main() {
        vec4 color;
        // TEXTURE SELECTION
        gl_FragColor = f_color * color;
      }
    """
