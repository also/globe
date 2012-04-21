(function() {
  var CIRCLE_IMAGE, DISTANCE_RATE, MAX_DISTANCE, MAX_ROTATE_Y, MIN_DISTANCE, MIN_ROTATE_Y, MIN_TARGET_DELTA, ORIGIN, ROTATE_RATE, SIZE, llToXyz, shaders, slerp, srand;

  SIZE = 200;

  ROTATE_RATE = 0.005;

  DISTANCE_RATE = 0.015;

  MIN_DISTANCE = 350;

  MAX_DISTANCE = 1000;

  MAX_ROTATE_Y = Math.PI / 2;

  MIN_ROTATE_Y = -MAX_ROTATE_Y;

  ORIGIN = new THREE.Vector3(0, 0, 0);

  MIN_TARGET_DELTA = 0.0001;

  CIRCLE_IMAGE = (function() {
    var canvas, ctx, r, size;
    size = 64;
    r = size / 2;
    canvas = $("<canvas width='" + size + "' height='" + size + "'/>").get(0);
    ctx = canvas.getContext('2d');
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(r, r, r, 0, Math.PI * 2, true);
    ctx.closePath();
    ctx.fill();
    return canvas;
  })();

  llToXyz = function(lng, lat, size) {
    var phi, pos, theta;
    if (size == null) size = SIZE;
    phi = (90 - lat) * Math.PI / 180;
    theta = (180 - lng) * Math.PI / 180;
    pos = new THREE.Vector3;
    pos.x = size * Math.sin(phi) * Math.cos(theta);
    pos.y = size * Math.cos(phi);
    pos.z = size * Math.sin(phi) * Math.sin(theta);
    return pos;
  };

  srand = function(radius) {
    var pos, r, t, z;
    if (radius == null) radius = SIZE;
    pos = new THREE.Vector3;
    z = Math.random() * 2 - 1;
    t = Math.random() * Math.PI * 2;
    r = Math.sqrt(1 - z * z) * radius;
    pos.z = radius * z;
    pos.x = r * Math.cos(t);
    pos.y = r * Math.sin(t);
    return pos;
  };

  slerp = function(p0, p1, t) {
    var fn, omega, sinOmega;
    omega = Math.acos(p0.clone().normalize().dot(p1.clone().normalize()));
    sinOmega = Math.sin(omega);
    fn = function(t) {
      var _p0, _p1;
      _p0 = p0.clone();
      _p1 = p1.clone();
      _p0.multiplyScalar(Math.sin((1 - t) * omega) / sinOmega).addSelf(_p1.multiplyScalar(Math.sin(t * omega) / sinOmega));
      return _p0;
    };
    if (t != null) {
      return fn(t);
    } else {
      return fn;
    }
  };

  window.globe = {
    create: function() {
      var animate, atmosphereColor, camera, cameraPositionNormalized, createAtmosphere, createEarth, createLocation, createParticles, createPointMesh, createStars, distance, distanceTarget, earthTexture, forceUpdate, height, init, initAnimation, moveRotationTarget, moveZoomTarget, observeMouse, onupdate, previousTime, projector, render, renderer, resize, rotation, rotationTarget, scene, sceneAtmosphere, setRotation, setRotationTarget, setZoom, setZoomTarget, updatePosition, updated, width;
      camera = null;
      renderer = null;
      scene = null;
      sceneAtmosphere = null;
      earthTexture = null;
      atmosphereColor = null;
      width = height = null;
      onupdate = null;
      cameraPositionNormalized = new THREE.Vector3;
      forceUpdate = false;
      previousTime = null;
      projector = new THREE.Projector;
      distance = 100000;
      distanceTarget = 1000;
      rotation = {
        x: 0,
        y: 0
      };
      rotationTarget = {
        x: Math.PI * 3 / 2,
        y: Math.PI / 6.0
      };
      init = function(opts) {
        var backgroundColor, _ref, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8;
        if (opts == null) opts = {};
        width = (_ref = opts.width) != null ? _ref : 800;
        height = (_ref2 = opts.height) != null ? _ref2 : 600;
        backgroundColor = (_ref3 = opts.backgroundColor) != null ? _ref3 : 0x000000;
        atmosphereColor = (_ref4 = opts.atmosphereColor) != null ? _ref4 : 0xffffff;
        onupdate = opts.onupdate;
        renderer = new THREE.WebGLRenderer({
          antialias: true,
          preserveDrawingBuffer: opts.preserveDrawingBuffer
        });
        renderer.setSize(width, height);
        if ((_ref5 = opts.container) != null) {
          _ref5.appendChild(renderer.domElement);
        }
        this.domElement = renderer.domElement;
        renderer.autoClear = false;
        renderer.setClearColorHex(backgroundColor, (_ref6 = opts.backgroundOpacity) != null ? _ref6 : 1);
        camera = new THREE.PerspectiveCamera(30, width / height, 1, 10000);
        camera.position.z = distance;
        earthTexture = THREE.ImageUtils.loadTexture((_ref7 = opts.globeTexture) != null ? _ref7 : 'natural-earth.jpg', null, opts.onLoad);
        scene = new THREE.Scene;
        sceneAtmosphere = new THREE.Scene;
        scene.add(createEarth());
        if ((_ref8 = true || opts.atmosphere) != null ? _ref8 : true) {
          sceneAtmosphere.add(createAtmosphere());
        }
        if (opts.stars || true) scene.add(createStars());
        scene.add(camera);
        return renderer.clear();
      };
      resize = function(w, h) {
        width = w;
        height = h;
        renderer.setSize(width, height);
        camera.aspect = width / height;
        return camera.updateProjectionMatrix();
      };
      createEarth = function() {
        var geometry, material, mesh, shader, uniforms;
        shader = shaders.earth;
        uniforms = THREE.UniformsUtils.clone(shader.uniforms);
        uniforms.texture.texture = earthTexture;
        material = new THREE.ShaderMaterial({
          uniforms: uniforms,
          vertexShader: shader.vertexShader,
          fragmentShader: shader.fragmentShader
        });
        geometry = new THREE.SphereGeometry(SIZE, 40, 30);
        mesh = new THREE.Mesh(geometry, material);
        mesh.rotation.y = Math.PI;
        mesh.updateMatrix();
        mesh.matrixAutoUpdate = false;
        return mesh;
      };
      createAtmosphere = function() {
        var geometry, material, mesh, shader, uniforms;
        shader = shaders.atmosphere;
        uniforms = THREE.UniformsUtils.clone(shader.uniforms);
        uniforms.color.value = new THREE.Color(atmosphereColor);
        material = new THREE.ShaderMaterial({
          uniforms: uniforms,
          vertexShader: shader.vertexShader,
          fragmentShader: shader.fragmentShader
        });
        geometry = new THREE.SphereGeometry(SIZE, 40, 30);
        mesh = new THREE.Mesh(geometry, material);
        mesh.scale.set(1.4, 1.4, 1.4);
        mesh.flipSided = true;
        mesh.matrixAutoUpdate = false;
        mesh.updateMatrix();
        return mesh;
      };
      createStars = function() {
        var geometry, i, material, ps, texture, v;
        geometry = new THREE.Geometry;
        for (i = 1; i <= 800; i++) {
          v = new THREE.Vertex(srand(SIZE * 10 + Math.random() * SIZE * 5));
          geometry.vertices.push(v);
        }
        texture = new THREE.Texture(CIRCLE_IMAGE);
        texture.needsUpdate = true;
        material = new THREE.ParticleBasicMaterial({
          size: 12,
          map: texture,
          blending: THREE.AdditiveBlending,
          transparent: true
        });
        material.color.setHSV(.65, .0, .5);
        ps = new THREE.ParticleSystem(geometry, material);
        ps.updateMatrix();
        return ps;
      };
      createParticles = function(opts) {
        var add, attributes, geometry, i, material, particles, shader, texture, uniforms, v, _ref;
        texture = new THREE.Texture((_ref = opts.texture) != null ? _ref : CIRCLE_IMAGE);
        texture.needsUpdate = true;
        uniforms = {
          texture: {
            type: 't',
            value: 0,
            texture: texture
          }
        };
        attributes = {
          size: {
            type: 'f',
            value: []
          },
          particleColor: {
            type: 'c',
            value: []
          },
          particleOpacity: {
            type: 'f',
            value: []
          }
        };
        shader = shaders.particle;
        material = new THREE.ShaderMaterial({
          transparent: true,
          vertexShader: shader.vertexShader,
          fragmentShader: shader.fragmentShader,
          attributes: attributes,
          uniforms: uniforms
        });
        geometry = new THREE.Geometry;
        particles = (function() {
          var _ref2, _results;
          _results = [];
          for (i = 0, _ref2 = opts.particleCount; 0 <= _ref2 ? i < _ref2 : i > _ref2; 0 <= _ref2 ? i++ : i--) {
            v = new THREE.Vertex;
            _results.push((function(v, i) {
              var altitude, destination, normalizedPosition, origin, p, position, slerpP, updateSlerp;
              position = new THREE.Vector3;
              normalizedPosition = new THREE.Vector3;
              altitude = 0;
              origin = destination = null;
              slerpP = null;
              p = {
                altitude: 0,
                reset: function() {
                  var _ref3, _ref4;
                  this.setPosition(0, 0);
                  this.hide();
                  this.setSize((_ref3 = opts.size) != null ? _ref3 : 1);
                  this.setColor(new THREE.Color((_ref4 = opts.color) != null ? _ref4 : 0xffffff));
                  return this.setOpacity(1);
                },
                setPosition: function(lng, lat) {
                  normalizedPosition.copy(llToXyz(lng, lat, 1));
                  return this.setAltitude(altitude);
                },
                setSize: function(size) {
                  attributes.size.value[i] = size;
                  return attributes.size.needsUpdate = true;
                },
                setColor: function(color) {
                  attributes.particleColor.value[i] = color;
                  return attributes.particleColor.needsUpdate = true;
                },
                setOpacity: function(opacity) {
                  attributes.particleOpacity.value[i] = opacity;
                  return attributes.particleOpacity.needsUpdate = true;
                },
                setOrigin: function(lng, lat) {
                  origin = llToXyz(lng, lat, 1);
                  return updateSlerp();
                },
                setDestination: function(lng, lat) {
                  destination = llToXyz(lng, lat, 1);
                  return updateSlerp();
                },
                setPositionMix: function(t) {
                  normalizedPosition = slerpP(t);
                  return this.setAltitude(altitude);
                },
                setAltitude: function(altitude) {
                  position.copy(normalizedPosition).multiplyScalar(SIZE * (1 + altitude));
                  v.position = position;
                  return geometry.__dirtyVertices = true;
                },
                hide: function() {
                  return this.setAltitude(-1);
                }
              };
              updateSlerp = function() {
                if ((origin != null) && (destination != null)) {
                  slerpP = slerp(origin, destination);
                  return p.distance = Math.acos(origin.clone().dot(destination)) / Math.PI;
                }
              };
              p.reset();
              geometry.vertices.push(v);
              return p;
            })(v, i));
          }
          return _results;
        })();
        add = function() {
          var ps;
          ps = new THREE.ParticleSystem(geometry, material);
          ps.sortParticles = true;
          return scene.add(ps);
        };
        return {
          add: add,
          particles: particles
        };
      };
      createPointMesh = function(opts) {
        var add, attributes, createPoint, defaultPointColor, defaultPointGeometry, geometry, mix, points, setSizeTargetMix, setSizeTargets, setSizes, uniforms, _ref;
        if (opts == null) opts = {};
        points = [];
        defaultPointColor = new THREE.Color;
        if ((_ref = opts.defaultDimension) == null) opts.defaultDimension = 0.75;
        defaultPointGeometry = new THREE.CubeGeometry(opts.defaultDimension, opts.defaultDimension, 1);
        defaultPointGeometry.vertices.forEach(function(v) {
          return v.position.z += 0.5;
        });
        geometry = new THREE.Geometry;
        geometry.dynamic = true;
        uniforms = {};
        attributes = {
          size: {
            type: 'f',
            value: []
          },
          customPosition: {
            type: 'v3',
            value: []
          }
        };
        if (opts.customColor) {
          attributes.customColor = {
            type: 'c',
            value: []
          };
        }
        if (opts.sizeTarget) {
          attributes.sizeTarget = {
            type: 'f',
            value: []
          };
          uniforms.sizeTargetMix = {
            type: 'f',
            value: 0
          };
        }
        createPoint = function(lat, lng, pointGeometry) {
          var i, mix, p, pos, setColor, setSize, setSizeTarget, vertexCount, vertexOffset, _ref2;
          if (pointGeometry == null) pointGeometry = defaultPointGeometry;
          vertexOffset = geometry.vertices.length;
          vertexCount = pointGeometry.vertices.length;
          THREE.GeometryUtils.merge(geometry, pointGeometry);
          pos = llToXyz(lng, lat);
          for (i = vertexOffset, _ref2 = vertexOffset + vertexCount; vertexOffset <= _ref2 ? i < _ref2 : i > _ref2; vertexOffset <= _ref2 ? i++ : i--) {
            attributes.customPosition.value[i] = pos;
          }
          attributes.customPosition.needsUpdate = true;
          setSize = function(size) {
            var i, _ref3;
            this.size = size;
            for (i = vertexOffset, _ref3 = vertexOffset + vertexCount; vertexOffset <= _ref3 ? i < _ref3 : i > _ref3; vertexOffset <= _ref3 ? i++ : i--) {
              attributes.size.value[i] = size;
            }
            return attributes.size.needsUpdate = true;
          };
          setSizeTarget = function(sizeTarget) {
            var i, _ref3;
            this.sizeTarget = sizeTarget;
            for (i = vertexOffset, _ref3 = vertexOffset + vertexCount; vertexOffset <= _ref3 ? i < _ref3 : i > _ref3; vertexOffset <= _ref3 ? i++ : i--) {
              attributes.sizeTarget.value[i] = sizeTarget;
            }
            return attributes.sizeTarget.needsUpdate = true;
          };
          mix = function(sizeTargetMix) {
            return this.setSize(this.size + (this.sizeTarget - this.size) * sizeTargetMix);
          };
          setColor = function(color) {
            var i, _ref3;
            for (i = vertexOffset, _ref3 = vertexOffset + vertexCount; vertexOffset <= _ref3 ? i < _ref3 : i > _ref3; vertexOffset <= _ref3 ? i++ : i--) {
              attributes.customColor.value[i] = color;
            }
            return attributes.customColor.needsUpdate = true;
          };
          p = {
            setSize: setSize,
            setSizeTarget: setSizeTarget,
            mix: mix,
            setColor: setColor
          };
          p.setSize(0);
          if (opts.sizeTarget) p.setSizeTarget(0);
          if (opts.customColor) p.setColor(defaultPointColor);
          points.push(p);
          return p;
        };
        setSizes = function(sizes, m) {
          var i, s, _len, _results;
          if (m == null) m = 1;
          _results = [];
          for (i = 0, _len = sizes.length; i < _len; i++) {
            s = sizes[i];
            _results.push(points[i].setSize(s * m));
          }
          return _results;
        };
        setSizeTargets = function(sizeTargets, m) {
          var i, t, _len, _results;
          if (m == null) m = 1;
          _results = [];
          for (i = 0, _len = sizeTargets.length; i < _len; i++) {
            t = sizeTargets[i];
            _results.push(points[i].setSizeTarget(t * m));
          }
          return _results;
        };
        setSizeTargetMix = function(sizeTargetMix) {
          this.sizeTargetMix = sizeTargetMix;
          return uniforms.sizeTargetMix.value = sizeTargetMix;
        };
        mix = function(sizeTargetMix) {
          var p, _i, _len, _ref2;
          if (sizeTargetMix == null) {
            sizeTargetMix = (_ref2 = this.sizeTargetMix) != null ? _ref2 : 0;
          }
          for (_i = 0, _len = points.length; _i < _len; _i++) {
            p = points[_i];
            p.mix(sizeTargetMix);
          }
          return this.setSizeTargetMix(0);
        };
        add = function() {
          var vertexShader;
          vertexShader = shaders.point.vertexShader;
          if (opts.customColor) {
            vertexShader = "#define USE_CUSTOM_COLOR;\n" + vertexShader;
          }
          if (opts.sizeTarget) {
            vertexShader = "#define USE_SIZE_TARGET;\n" + vertexShader;
          }
          return scene.add(new THREE.Mesh(geometry, new THREE.ShaderMaterial({
            uniforms: uniforms,
            attributes: attributes,
            vertexShader: vertexShader,
            fragmentShader: shaders.point.fragmentShader
          })));
        };
        return {
          points: points,
          createPoint: createPoint,
          add: add,
          setSizes: setSizes,
          setSizeTargets: setSizeTargets,
          setSizeTargetMix: setSizeTargetMix,
          mix: mix
        };
      };
      observeMouse = function(target) {
        var $domElement, mouseDown, mousemove, mouseup, removeMouseMoveEventListeners, rotationTargetDown, targetDown;
        if (target == null) target = renderer.domElement;
        mouseDown = null;
        targetDown = null;
        rotationTargetDown = null;
        $domElement = $(target);
        $domElement.bind('mousewheel', function(e) {
          moveZoomTarget(e.originalEvent.wheelDeltaY * 0.3);
          return e.preventDefault();
        });
        mouseup = function(e) {
          removeMouseMoveEventListeners();
          return $domElement.css('cursor', '');
        };
        mousemove = function(e) {
          var mouse, zoomDamp;
          mouse = {
            x: -e.clientX,
            y: e.clientY
          };
          zoomDamp = distance / 1000;
          rotationTarget.x = targetDown.x + (mouse.x - mouseDown.x) * 0.005 * zoomDamp;
          rotationTarget.y = targetDown.y + (mouse.y - mouseDown.y) * 0.005 * zoomDamp;
          return rotationTarget.y = Math.max(MIN_ROTATE_Y, Math.min(MAX_ROTATE_Y, rotationTarget.y));
        };
        removeMouseMoveEventListeners = function() {
          return $domElement.unbind('mousemove').unbind('mouseup', mouseup);
        };
        return $domElement.bind('mousedown', function(e) {
          e.preventDefault();
          $domElement.bind('mousemove', mousemove);
          $domElement.bind('mouseup', mouseup);
          $domElement.bind('mouseleave', function(e) {
            return removeMouseMoveEventListeners();
          });
          mouseDown = {
            x: -e.clientX,
            y: e.clientY
          };
          targetDown = {
            x: rotationTarget.x,
            y: rotationTarget.y
          };
          return $domElement.css('cursor', 'move');
        });
      };
      initAnimation = function() {
        previousTime = +(new Date);
        return window.requestAnimationFrame(animate, renderer.domElement);
      };
      updatePosition = function() {
        var deltaT, time, updated;
        time = new Date;
        deltaT = time - previousTime;
        updated = false;
        if (Math.abs(rotationTarget.x - rotation.x) < MIN_TARGET_DELTA) {
          rotation.x = rotationTarget.x;
        } else {
          updated = true;
          rotation.x += (rotationTarget.x - rotation.x) * Math.min(1, ROTATE_RATE * deltaT);
        }
        if (Math.abs(rotationTarget.y - rotation.y) < MIN_TARGET_DELTA) {
          rotation.y = rotationTarget.y;
        } else {
          updated = true;
          rotation.y += (rotationTarget.y - rotation.y) * Math.min(1, ROTATE_RATE * deltaT);
        }
        if (Math.abs(distanceTarget - distance) < MIN_TARGET_DELTA) {
          distance = distanceTarget;
        } else {
          updated = true;
          distance += (distanceTarget - distance) * Math.min(1, DISTANCE_RATE * deltaT);
        }
        camera.position.x = distance * Math.sin(rotation.x) * Math.cos(rotation.y);
        camera.position.y = distance * Math.sin(rotation.y);
        camera.position.z = distance * Math.cos(rotation.x) * Math.cos(rotation.y);
        if (updated || forceUpdate) {
          cameraPositionNormalized.copy(camera.position).normalize();
          camera.lookAt(scene.position);
          forceUpdate = false;
          if (typeof onupdate === "function") onupdate();
        }
        return previousTime = time;
      };
      render = function() {
        updatePosition();
        renderer.clear();
        renderer.render(scene, camera);
        return renderer.render(sceneAtmosphere, camera);
      };
      animate = function(t) {
        render();
        return initAnimation();
      };
      moveZoomTarget = function(amount) {
        distanceTarget -= amount;
        return distanceTarget = Math.max(Math.min(distanceTarget, MAX_DISTANCE), MIN_DISTANCE);
      };
      setZoomTarget = function(zoom) {
        return distanceTarget = zoom;
      };
      setZoom = function(zoom) {
        return distance = distanceTarget = zoom;
      };
      setRotation = function(x, y) {
        rotation = {
          x: x,
          y: y
        };
        return rotationTarget = {
          x: x,
          y: y
        };
      };
      setRotationTarget = function(x, y) {
        if (x == null) x = rotationTarget.x;
        if (y == null) y = rotationTarget.y;
        return rotationTarget = {
          x: x,
          y: y
        };
      };
      moveRotationTarget = function(x, y) {
        rotationTarget.x += x;
        return rotationTarget.y += y;
      };
      createLocation = function(lng, lat) {
        var pos, posNormalized, projectedPos;
        pos = llToXyz(lng, lat);
        projectedPos = pos.clone();
        posNormalized = pos.clone().normalize();
        return {
          angle: function() {
            return Math.acos(posNormalized.dot(cameraPositionNormalized));
          },
          screenPosition: function() {
            var screen;
            projectedPos.copy(pos);
            screen = projector.projectVector(projectedPos, camera);
            return {
              x: width * (screen.x + 1) / 2,
              y: height * (-screen.y + 1) / 2
            };
          }
        };
      };
      updated = function() {
        return forceUpdate = true;
      };
      return {
        init: init,
        initAnimation: initAnimation,
        resize: resize,
        render: render,
        observeMouse: observeMouse,
        setZoom: setZoom,
        setZoomTarget: setZoomTarget,
        moveZoomTarget: moveZoomTarget,
        setRotation: setRotation,
        setRotationTarget: setRotationTarget,
        moveRotationTarget: moveRotationTarget,
        createPointMesh: createPointMesh,
        createParticles: createParticles,
        updated: updated,
        createLocation: createLocation
      };
    }
  };

  shaders = {
    earth: {
      uniforms: {
        texture: {
          type: 't',
          value: 0,
          texture: null
        }
      },
      vertexShader: "varying vec3 vNormal;\nvarying vec2 vUv;\nvoid main() {\n  gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );\n  vNormal = normalize( normalMatrix * normal );\n  vUv = uv;\n}",
      fragmentShader: "uniform sampler2D texture;\nvarying vec3 vNormal;\nvarying vec2 vUv;\nvoid main() {\n  vec3 diffuse = texture2D( texture, vUv ).xyz;\n  float intensity = 1.05 - dot( vNormal, vec3( 0.0, 0.0, 1.0 ) );\n  vec3 atmosphere = vec3( 1.0, 1.0, 1.0 ) * pow( intensity, 3.0 );\n  gl_FragColor = vec4( diffuse + atmosphere, 1.0 );\n}"
    },
    atmosphere: {
      uniforms: {
        color: {
          type: 'c'
        }
      },
      vertexShader: "varying vec3 vNormal;\nvoid main() {\n  vNormal = normalize( normalMatrix * normal );\n  gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );\n}",
      fragmentShader: "varying vec3 vNormal;\nuniform vec3 color;\nvoid main() {\n  float intensity = pow( 0.5 - dot( vNormal, vec3( 0, 0, 1.0 ) ), 4.0 );\n  gl_FragColor = vec4( color, 0.6 ) * intensity;\n}"
    },
    point: {
      vertexShader: "varying vec4 f_color;\nattribute float size;\nattribute vec3 customPosition;\n\n#ifdef USE_SIZE_TARGET\n  attribute float sizeTarget;\n  uniform float sizeTargetMix;\n#endif\n\n#ifdef USE_CUSTOM_COLOR\n  attribute vec3 customColor;\n#endif\n\n// found, randomly, at https://www.h3dapi.org:8090/MedX3D/trunk/MedX3D/src/shaders/StyleFunctions.glsl\nvec3 HSVtoRGB(float h, float s, float v ) {\n  if (s == 0.0) return vec3(v);\n\n  h /= 60.0;\n  int i = int(floor(h));\n  float f = h - float(i);\n  float p = v * (1.0 - s);\n  float q = v * (1.0 - s * f);\n  float t = v * (1.0 - s * (1.0 - f));\n\n  if (i == 0) return vec3(v,t,p);\n  if (i == 1) return vec3(q,v,p);\n  if (i == 2) return vec3(p,v,t);\n  if (i == 3) return vec3(p,q,v);\n  if (i == 4) return vec3(t,p,v);\n              return vec3(v,p,q);\n}\n\nvoid main() {\n  float mixedSize = size;\n  #ifdef USE_SIZE_TARGET\n    mixedSize = mix(size, sizeTarget, sizeTargetMix);\n  #endif\n  // look at the origin\n  vec3 lz = normalize(-customPosition);\n  if (length(lz) == 0.0) {\n    lz.z = 1.0;\n  }\n  vec3 lup = vec3(0,1,0);\n  vec3 lx = normalize(cross(lup, lz));\n  if (length(lx) == 0.0) {\n    lz.x = lx.x + 0.0001;\n    lx = normalize(cross(lup, lz));\n  }\n  vec3 ly = normalize(cross(lz, lx));\n\n  lz *= -mixedSize * " + (SIZE.toFixed(1)) + ";\n  mat4 customMat = mat4(lx, 0,\n                   ly, 0,\n                   lz, 0,\n                   customPosition,1);\n  gl_Position =  projectionMatrix  *\n                modelViewMatrix *\n                customMat *\n                vec4(position.x, position.y, position.z,1);\n\n  #ifdef USE_CUSTOM_COLOR\n    f_color = vec4(customColor, 1.0);\n  #endif\n  #ifndef USE_CUSTOM_COLOR\n    f_color = vec4(HSVtoRGB((0.6 - mixedSize * 0.5) * 360.0, 1.0, 1.0), 1.0);\n  #endif\n}",
      fragmentShader: "varying vec4 f_color;\nvoid main() {\n  gl_FragColor = f_color;\n}"
    },
    particle: {
      vertexShader: "attribute float size;\nattribute vec3 particleColor;\nattribute float particleOpacity;\nvarying vec4 f_color;\nvarying float f_opacity;\n\nvoid main() {\n  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);\n  gl_PointSize = size;\n  f_opacity = particleOpacity;\n  f_color = vec4(particleColor, 1);\n}",
      fragmentShader: "uniform sampler2D texture;\nvarying vec4 f_color;\nvarying float f_opacity;\n\nvoid main() {\n  gl_FragColor = vec4(f_color.xyz, f_opacity) * texture2D(texture, 1.0 - gl_PointCoord);\n}"
    }
  };

}).call(this);
