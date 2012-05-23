COLOR_THRESHOLD = 1.19
LAT_LINES = 250
LNG_LINES = 250

image = new Image
image.src = '../../natural-earth.jpg'
image.onload = ->
  canvas = $("<canvas width=#{image.width} height=#{image.height}/>")[0]
  ctx = canvas.getContext '2d'
  ctx.drawImage image, 0, 0
  pixels = ctx.getImageData(0, 0, canvas.width, canvas.height).data

  window.sample = (lng, lat) ->
    x = Math.floor((lng / 360 + 0.5) * canvas.width)
    y = Math.floor((lat / -180 + 0.5) * canvas.height)
    i = x * 4 + y * canvas.width * 4
    r = pixels[i] / 255
    g = pixels[i+1] / 255
    b = pixels[i+2] / 255
    {r,g,b}

  window.points = []

  earth = globe.create()

  earth.init container: document.body, atmosphere: false, globe: false, width: 800, height: 800

  for lat_line in [0...LAT_LINES]
    lat = 180 * (0.5 - lat_line / LAT_LINES)
    for lng_line in [0...LNG_LINES]
      lng = 360 * (lng_line / LNG_LINES - .5)

      phi = Math.random() * Math.PI * 2
      theta = Math.acos(Math.random() * 2 - 1)

      #lng = phi / Math.PI * 360
      #lat = theta / Math.PI * 180 - 90

      {r,g,b} = sample lng, lat
      color = new THREE.Color 0x00ffff
      color.setRGB r,g,b

      if r + g > COLOR_THRESHOLD
        points.push {lat, lng, color}

  particles = earth.createParticles particleCount: points.length, size: 2
  for {lat, lng, color}, i in points
    particle = particles.particles[i]
    particle.setPosition lng, lat
    particle.setColor color

  particles.add()

  earth.initAnimation()
  globe.observeMouse earth.satellite, earth.domElement
