initAnimation = ->
  g = globe.create()
  g.init container: document.body, globeTexture: '../../natural-earth.jpg', atmosphere: false

  particles = g.createParticles particleCount: 5000, size: 5, opacity: 0
  particles.add()
  particleBuffer = new globe.ParticleBuffer particles

  nextFrame = (t) ->
    # TODO use srand instead
    # TODO more points
    point = 
      lng: Math.random() * 360 - 180
      lat: Math.random() * 180 - 90
    particleBuffer.allocate [point], (point, particle) ->
      particle.reset()
      particle.setOpacity 1
      particle.setPosition point.lng, point.lat
      particle.startT = t
      particle.endT = t + 1000
      particle.removeT = t + 1000

    particleBuffer.update t, (particle) ->
      pos = (t - particle.startT) / (particle.removeT - particle.startT)
      particle.setAltitude pos
      if pos > 0.9
        particle.setOpacity (1 - pos) / 0.1

  startTime = Date.now()

  animate = ->
    window.requestAnimationFrame (t) ->
      nextFrame t - startTime
      animate()

  animate()

  globe.observeMouse(g.satellite, g.domElement)
  g.initAnimation()

$ initAnimation
