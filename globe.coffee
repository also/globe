SIZE = 200

ROTATE_RATE = 0.1
DISTANCE_RATE = 0.3

MIN_DISTANCE = 350
MAX_DISTANCE = 1000

MAX_ROTATE_Y = Math.PI / 2
MIN_ROTATE_Y = -MAX_ROTATE_Y

ORIGIN = new THREE.Vector3 0, 0, 0

CIRCLE_IMAGE = (
  r = 25
  size = r * 2
  canvas = $("<canvas width='#{r*2}' height='#{r*2}'/>").get 0
  ctx = canvas.getContext '2d'
  ctx.fillStyle = '#fff'
  ctx.beginPath()
  ctx.arc r, r, r, 0, Math.PI * 2, true
  ctx.closePath()
  ctx.fill()
  canvas
)

llToXyz = (lng, lat, size=SIZE) ->
  phi = (90 - lat) * Math.PI / 180
  theta = (180 - lng) * Math.PI / 180

  pos = new THREE.Vector3
  pos.x = size * Math.sin(phi) * Math.cos(theta)
  pos.y = size * Math.cos(phi)
  pos.z = size * Math.sin(phi) * Math.sin(theta)

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

window.globe = create: ->
  camera = null
  renderer = null
  scene = null
  earthTexture = null

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
    globeTexture = opts.globeTexture ? 'world.jpg'
    backgroundColor = opts.backgroundColor ? 0x000000

    renderer = new THREE.WebGLRenderer antialias: true, preserveDrawingBuffer: opts.preserveDrawingBuffer
    renderer.setSize width, height
    opts.container?.appendChild renderer.domElement
    @domElement = renderer.domElement
    renderer.autoClear = false
    renderer.setClearColorHex backgroundColor, opts.backgroundOpacity ? 1

    camera = new THREE.PerspectiveCamera 30, width / height, 1, 10000
    camera.position.z = distance

    earthTexture = THREE.ImageUtils.loadTexture globeTexture, null, opts.onLoad

    scene = new THREE.Scene
    scene.add createEarth()
    if opts.atmosphere ? true
      scene.add createAtmosphere()

    if opts.stars
      scene.add createStars()

    scene.add camera

    renderer.clear()

  resize = (width, height) ->
    renderer.setSize width, height
    camera.aspect = width / height
    camera.updateProjectionMatrix()

  createEarth = ->
    shader = shaders.earth
    uniforms = THREE.UniformsUtils.clone(shader.uniforms)
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
    material = new THREE.ShaderMaterial(
      uniforms: uniforms
      vertexShader: shader.vertexShader
      fragmentShader: shader.fragmentShader
    )
    geometry = new THREE.SphereGeometry SIZE, 40, 30
    mesh = new THREE.Mesh geometry, material
    mesh.scale.set 1.1, 1.1, 1.1
    mesh.flipSided = true
    mesh.matrixAutoUpdate = false
    mesh.updateMatrix()
    mesh

  createStars = ->
    geometry = new THREE.Geometry
    for i in [1..800]
      # if you look closely, you can see clusters of stars above the poles
      lng = 180 - Math.random() * 360
      lat = 180 - Math.random() * 360
      pos = llToXyz lng, lat, SIZE * 5 + Math.random() * SIZE * 5
      v = new THREE.Vertex pos
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
    texture = new THREE.Texture CIRCLE_IMAGE
    texture.needsUpdate = true

    uniforms =
      texture:
        type: 't'
        value: 0
        texture: texture

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

    shader = shaders.particle

    material = new THREE.ShaderMaterial
      transparent: true
      vertexShader: shader.vertexShader
      fragmentShader: shader.fragmentShader
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

        p =
          altitude: 0
          reset: ->
            @setPosition 0,0
            @hide()
            @setSize opts.size ? 1
            @setColor new THREE.Color opts.color ? 0xffffff
            @setOpacity 1
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
          hide: -> @setAltitude -1

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

  createPointMesh = (opts={}) ->
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

    createPoint = (lat, lng, pointGeometry=defaultPointGeometry) ->
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

    {points, createPoint, add, setSizes, setSizeTargets, setSizeTargetMix, mix}

  observeMouse = ->
    mouseDown = null
    rotationTargetDown = null

    $domElement = $(renderer.domElement)
    $domElement.bind 'mousewheel', (e) ->
      moveZoomTarget(e.originalEvent.wheelDeltaY * 0.3)
      e.preventDefault()

    removeMouseMoveEventListeners = ->
      $domElement
        .unbind('mousemove')
        .unbind('mouseup')
        .unbind('mouseout')

    $domElement.bind 'mousedown', (e) ->
      e.preventDefault()
      $domElement.bind 'mousemove', (e) ->
        mouse = x: -e.clientX, y: e.clientY
        zoomDamp = distance / 1000

        rotationTarget.x = targetDown.x + (mouse.x - mouseDown.x) * 0.005 * zoomDamp
        rotationTarget.y = targetDown.y + (mouse.y - mouseDown.y) * 0.005 * zoomDamp

        rotationTarget.y = Math.max MIN_ROTATE_Y, Math.min(MAX_ROTATE_Y, rotationTarget.y)

      $domElement.bind 'mouseup', (e) ->
        removeMouseMoveEventListeners()
        $domElement.css 'cursor', ''

      $domElement.bind 'mouseout', (e) ->
        removeMouseMoveEventListeners()

      mouseDown = x: -e.clientX, y: e.clientY
      targetDown = x: rotationTarget.x, y: rotationTarget.y

      $domElement.css 'cursor', 'move'

  initAnimation = ->
    window.requestAnimationFrame animate, renderer.domElement

  updatePosition = ->
    rotation.x += (rotationTarget.x - rotation.x) * ROTATE_RATE
    rotation.y += (rotationTarget.y - rotation.y) * ROTATE_RATE
    distance += (distanceTarget - distance) * DISTANCE_RATE

    camera.position.x = distance * Math.sin(rotation.x) * Math.cos(rotation.y)
    camera.position.y = distance * Math.sin(rotation.y)
    camera.position.z = distance * Math.cos(rotation.x) * Math.cos(rotation.y)

    # you need to update lookAt every frame
    camera.lookAt scene.position

  render = ->
    updatePosition()
    renderer.clear()

    renderer.render scene, camera

  animate = (t) ->
    render()
    initAnimation()

  moveZoomTarget = (amount) ->
    distanceTarget -= amount
    distanceTarget = Math.max Math.min(distanceTarget, MAX_DISTANCE), MIN_DISTANCE

  setZoomTarget = (zoom) ->
    distanceTarget = zoom

  setZoom = (zoom) ->
    distance = distanceTarget = zoom

  setRotation = (x, y) ->
    rotation = {x, y}
    rotationTarget = {x, y}

  setRotationTarget = (x, y) ->
    x ?= rotationTarget.x
    y ?= rotationTarget.y
    rotationTarget = {x, y}

  moveRotationTarget = (x, y) ->
    rotationTarget.x += x
    rotationTarget.y += y

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
    createPointMesh,
    createParticles
  }

shaders =
  earth:
    uniforms:
      texture:
        type: 't'
        value: 0
        texture: null
    vertexShader: """
      varying vec3 vNormal;
      varying vec2 vUv;
      void main() {
        gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
        vNormal = normalize( normalMatrix * normal );
        vUv = uv;
      }
    """
    fragmentShader: """
      uniform sampler2D texture;
      varying vec3 vNormal;
      varying vec2 vUv;
      void main() {
        vec3 diffuse = texture2D( texture, vUv ).xyz;
        float intensity = 1.05 - dot( vNormal, vec3( 0.0, 0.0, 1.0 ) );
        vec3 atmosphere = vec3( 1.0, 1.0, 1.0 ) * pow( intensity, 3.0 );
        gl_FragColor = vec4( diffuse + atmosphere, 1.0 );
      }
    """
  atmosphere:
    uniforms: {}
    vertexShader: """
      varying vec3 vNormal;
      void main() {
        vNormal = normalize( normalMatrix * normal );
        gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
      }
    """
    fragmentShader: """
      varying vec3 vNormal;
      void main() {
        float intensity = pow( 0.8 - dot( vNormal, vec3( 0, 0, 1.0 ) ), 12.0 );
        gl_FragColor = vec4( 1.0, 1.0, 1.0, 1.0 ) * intensity;
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
      vec3 HSVtoRGB(float h, float s, float v ) {
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
      varying vec4 f_color;
      varying float f_opacity;

      void main() {
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        gl_PointSize = size;
        f_opacity = particleOpacity;
        f_color = vec4(particleColor, 1);
      }
    """
    fragmentShader: """
      uniform sampler2D texture;
      varying vec4 f_color;
      varying float f_opacity;

      void main() {
        gl_FragColor = vec4(f_color.xyz, f_opacity) * texture2D(texture, gl_PointCoord);
      }
    """
