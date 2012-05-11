WIDTH = 1024
HEIGHT = 768

$.getJSON 'population909500.json', (json) ->
  populations = for [year, data] in json
    population = for i in [0..data.length] by 3
      lat = data[i]
      lng = data[i + 1]
      magnitude = data[i + 2]
      {lat, lng, magnitude}
    population.year = year
    population


  earth = globe.create()

  earth.init container: document.body, globeTexture: '../../world.jpg', width: WIDTH, height: HEIGHT

  chart = earth.createBarChart()
  for pop in populations[0]
    bar = chart.createBar pop.lng, pop.lat
    bar.setSize pop.magnitude

  chart.add()

  earth.initAnimation()
  globe.observeMouse earth.satellite, earth.domElement
