(function() {
  var HEIGHT, WIDTH, compare;

  WIDTH = 1024;

  HEIGHT = 768;

  compare = function(a, b) {
    var label;
    label = a.labelrank - b.labelrank;
    if (label !== 0) {
      return label;
    } else {
      return b.pop_max - a.pop_max;
    }
  };

  $.getJSON('cities.json', function(json) {
    var cities, citiesElt, earth;
    citiesElt = document.getElementById('cities');
    citiesElt.setAttribute('width', WIDTH);
    citiesElt.setAttribute('height', HEIGHT);
    earth = globe.create();
    cities = globe.createLabels({
      labels: json.filter(function(city) {
        return city.scalerank <= 2;
      }).sort(compare),
      container: citiesElt,
      context: earth
    });
    earth.init({
      container: document.body,
      atmosphereColor: 0x70A9D1,
      globeTexture: '../../../ne.png',
      onupdate: cities.onupdate,
      width: WIDTH,
      height: HEIGHT
    });
    earth.setZoomTarget(900);
    earth.setRotation(Math.PI, 0.7);
    earth.initAnimation();
    return earth.observeMouse(document.body);
  });

}).call(this);
