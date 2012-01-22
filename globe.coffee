SIZE = 200

ROTATE_RATE = 0.1
DISTANCE_RATE = 0.3

MIN_DISTANCE = 350
MAX_DISTANCE = 1000

MAX_CUBE_SIZE = SIZE

MAX_ROTATE_Y = Math.PI / 2
MIN_ROTATE_Y = -MAX_ROTATE_Y

ORIGIN = new THREE.Vector3 0, 0, 0

window.globe = create: ->
  camera = null
  renderer = null
  scene = null
  earthTexture = null
  points = null
  pointAttributes = null
  defaultPointColor = new THREE.Color
  defaultPointGeometry = new THREE.CubeGeometry 0.75, 0.75, 1
  defaultPointGeometry.vertices.forEach (v) -> v.position.z += 0.5

  distance = 100000
  distanceTarget = 1000

  rotation =
    x: 0
    y: 0

  rotationTarget =
    x: Math.PI * 3/2
    y: Math.PI / 6.0

  init = (callback) ->
    # FIXME
    width = 800
    height = 600

    renderer = new THREE.WebGLRenderer antialias: true
    renderer.setSize width, height
    document.body.appendChild renderer.domElement
    renderer.autoClear = false
    renderer.setClearColorHex 0x000000, 1.0

    camera = new THREE.PerspectiveCamera 30, width / height, 1, 10000
    camera.position.z = distance

    # TODO don't hardcode path
    earthTexture = THREE.ImageUtils.loadTexture 'world.jpg', null, callback

    scene = new THREE.Scene
    scene.add createEarth()
    scene.add createAtmosphere()
    scene.add camera

    points = new THREE.Geometry
    # making the geometry dynamic is necessary to have three.js update custom
    # attributes on the mesh created from the geometry. weird. this changed at
    # some point after https://github.com/mrdoob/three.js/issues/267 when
    # dynamic was set on the mesh
    points.dynamic = true

    pointAttributes =
      size:
        type: 'f'
        value: []
      customPosition:
        type: 'v3'
        value: []
      customColor:
        type: 'c'
        value: []

    renderer.clear()

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

  createPoint = (lat, lng, geometry=defaultPointGeometry) ->
    phi = (90 - lat) * Math.PI / 180
    theta = (180 - lng) * Math.PI / 180

    pos = new THREE.Vector3
    pos.x = SIZE * Math.sin(phi) * Math.cos(theta)
    pos.y = SIZE * Math.cos(phi)
    pos.z = SIZE * Math.sin(phi) * Math.sin(theta)

    vertexOffset = points.vertices.length
    vertexCount = geometry.vertices.length

    pointAttributes.customPosition.value[i] = pos for i in [vertexOffset..vertexOffset + vertexCount]
    pointAttributes.customPosition.needsUpdate = true

    setSize = (size) ->
      pointAttributes.size.value[i] = size for i in [vertexOffset..vertexOffset + vertexCount]
      pointAttributes.size.needsUpdate = true

    setColor = (color) ->
      pointAttributes.customColor.value[i] = color for i in [vertexOffset..vertexOffset + vertexCount]
      pointAttributes.customColor.needsUpdate = true

    setColor defaultPointColor

    THREE.GeometryUtils.merge points, geometry

    {setSize, setColor}

  addPoints = ->
    scene.add new THREE.Mesh points, new THREE.ShaderMaterial(
      attributes: pointAttributes
      vertexShader: shaders.point.vertexShader
      fragmentShader: shaders.point.fragmentShader
    )

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

  animate = (t) ->
    updatePosition()
    camera.position.x = distance * Math.sin(rotation.x) * Math.cos(rotation.y)
    camera.position.y = distance * Math.sin(rotation.y)
    camera.position.z = distance * Math.cos(rotation.x) * Math.cos(rotation.y)

    # you need to update lookAt every frame
    camera.lookAt scene.position

    renderer.clear()

    renderer.render scene, camera

    initAnimation()

  moveZoomTarget = (amount) ->
    distanceTarget -= amount
    distanceTarget = Math.max Math.min(distanceTarget, MAX_DISTANCE), MIN_DISTANCE

  zoom = (zoom) ->
    distance = distanceTarget = zoom

  rotate = (x, y) ->
    rotation = rotationTarget = {x, y}

  {init, initAnimation, observeMouse, zoom, moveZoomTarget, rotate, createPoint, addPoints}

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
      attribute vec3 customColor;

      void main() {
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

        lz *= -size * #{SIZE.toFixed(1)};
        mat4 customMat = mat4(lx, 0,
                         ly, 0,
                         lz, 0,
                         customPosition,1);
        gl_Position =  projectionMatrix  *
                      modelViewMatrix *
                      customMat *
                      vec4(position.x, position.y, position.z,1);
        f_color = vec4(customColor, 1.0);
      }
    """
    fragmentShader: """
      varying vec4 f_color;
      void main() {
        gl_FragColor = f_color;
      }
    """
