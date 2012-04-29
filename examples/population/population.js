// Generated by CoffeeScript 1.3.1
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
          var _j, _ref1, _results1;
          _results1 = [];
          for (i = _j = 0, _ref1 = data.length; _j <= _ref1; i = _j += 3) {
            lat = data[i];
            lng = data[i + 1];
            magnitude = data[i + 2];
            _results1.push({
              lat: lat,
              lng: lng,
              magnitude: magnitude
            });
          }
          return _results1;
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
    return earth.observeMouse();
  });

}).call(this);
