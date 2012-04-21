(function() {
  var FADE_IN, FADE_OUT, LABEL_SPACING, MAX_ANGLE, MIN_ANGLE, SHOW_DELAY, overlaps;

  LABEL_SPACING = {
    x: 2,
    y: 4
  };

  FADE_IN = 400;

  SHOW_DELAY = 1200;

  FADE_OUT = 100;

  MAX_ANGLE = Math.PI / 3;

  MIN_ANGLE = MAX_ANGLE * .9;

  overlaps = function(a, b) {
    return a.x < b.x2 && a.x2 > b.x && a.y < b.y2 && a.y2 > b.y;
  };

  globe.createLabels = function(_arg) {
    var container, context, labels, onupdate, startTime, visible;
    labels = _arg.labels, container = _arg.container, context = _arg.context;
    startTime = +(new Date);
    visible = null;
    labels = labels.map(function(label, i) {
      var bbox, circle, g, text, text2;
      circle = document.createElementNS(container.namespaceURI, 'circle');
      circle.setAttribute('r', 2);
      text = document.createElementNS(container.namespaceURI, 'text');
      text.textContent = label.name;
      text2 = document.createElementNS(container.namespaceURI, 'text');
      text2.setAttribute('class', 'shadow');
      text2.textContent = label.name;
      g = document.createElementNS(container.namespaceURI, 'g');
      g.setAttribute('class', "scale" + label.scalerank);
      g.appendChild(circle);
      g.appendChild(text2);
      g.appendChild(text);
      container.appendChild(g);
      bbox = text.getBBox();
      return {
        width: bbox.width + LABEL_SPACING.x * 2,
        height: bbox.height + LABEL_SPACING.y * 2,
        elt: g,
        shown: startTime + 2000,
        overlapped: startTime - 400,
        opacity: 0,
        earthLocation: context.createLocation(label.lng, label.lat)
      };
    });
    onupdate = function() {
      var t, updated;
      updated = false;
      t = +(new Date);
      visible = [];
      labels.forEach(function(label) {
        var angle, duration, maxOpacity, pos;
        angle = label.earthLocation.angle();
        if (angle > Math.PI / 2) {
          label.opacity = 0;
        } else {
          pos = label.earthLocation.screenPosition();
          label.x = pos.x - label.width / 2;
          label.y = pos.y - label.height / 2;
          label.x2 = label.x + label.width;
          label.y2 = label.y + label.height;
          if (visible.some(function(match) {
            return overlaps(match, label);
          })) {
            if (label.overlapped == null) {
              label.overlapped = t;
              updated = true;
            }
            label.opacity = Math.min(1 - Math.max((t - label.overlapped) / FADE_OUT, 0), label.opacity);
            label.shown = null;
          } else {
            label.overlapped = null;
            if (label.shown == null) {
              label.shown = t + SHOW_DELAY;
              updated = true;
            }
            duration = t - label.shown;
            if (duration < 0) updated = true;
            label.opacity = Math.min(Math.max(duration / FADE_IN, label.opacity), 1);
            visible.push(label);
          }
        }
        if (label.opacity > 0) {
          if (label.opacity < 1) updated = true;
          maxOpacity = Math.min(1, (MIN_ANGLE - angle) / (MAX_ANGLE - MIN_ANGLE));
          label.elt.setAttribute('style', 'display: inline; opacity: ' + label.opacity * maxOpacity);
          return label.elt.setAttribute('transform', "translate(" + pos.x + "," + pos.y + ")");
        } else {
          return label.elt.setAttribute('style', 'display: none');
        }
      });
      if (updated) return context.updated();
    };
    return {
      onupdate: onupdate
    };
  };

}).call(this);
