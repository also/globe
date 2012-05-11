WIDTH = 1024
HEIGHT = 768

compare = (a,b) ->
  label = a.labelrank - b.labelrank
  if label != 0
    label
  else
    b.pop_max - a.pop_max

$.getJSON 'cities.json', (json) ->
  citiesElt = document.getElementById 'cities'
  citiesElt.setAttribute('width', WIDTH)
  citiesElt.setAttribute('height', HEIGHT)
  earth = globe.create()
  cities = globe.createLabels
    labels: json.filter((city) -> city.scalerank <= 2).sort(compare)
    container: citiesElt
    context: earth

  earth.init container: document.body, atmosphereColor: 0x70A9D1, globeTexture: '../../natural-earth.jpg', onupdate: cities.onupdate, width: WIDTH, height: HEIGHT
  earth.initAnimation()
  globe.observeMouse earth.satellite, citiesElt
