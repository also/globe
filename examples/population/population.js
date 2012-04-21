(function() {
  var HEIGHT, WIDTH;

  WIDTH = 1024;

  HEIGHT = 768;

  $.getJSON('population909500.json', function(json) {
    var bar, chart, data, earth, i, lat, lng, magnitude, pop, population, populations, year, _i, _len, _ref;
    populations = (function() {
      var _i, _len, _ref, _results;
      _results = [];
      for (_i = 0, _len = json.length; _i < _len; _i++) {
        _ref = json[_i], year = _ref[0], data = _ref[1];
        population = (function() {
          var _ref2, _results2;
          _results2 = [];
          for (i = 0, _ref2 = data.length; i <= _ref2; i += 3) {
            lat = data[i];
            lng = data[i + 1];
            magnitude = data[i + 2];
            _results2.push({
              lat: lat,
              lng: lng,
              magnitude: magnitude
            });
          }
          return _results2;
        })();
        population.year = year;
        _results.push(population);
      }
      return _results;
    })();
    earth = globe.create();
    earth.init({
      container: document.body,
      globeTexture: '../../world.jpg',
      width: WIDTH,
      height: HEIGHT
    });
    chart = earth.createBarChart();
    _ref = populations[0];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      pop = _ref[_i];
      bar = chart.createBar(pop.lng, pop.lat);
      bar.setSize(pop.magnitude);
    }
    chart.add();
    earth.setZoomTarget(900);
    earth.setRotation(Math.PI, 0.7);
    earth.initAnimation();
    return earth.observeMouse(document.body);
  });

}).call(this);
