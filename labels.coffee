LABEL_SPACING = {x: 2, y: 4}

FADE_IN = 400
SHOW_DELAY = 1200
FADE_OUT = 100

MAX_ANGLE = Math.PI / 3
MIN_ANGLE = MAX_ANGLE * .9

overlaps = (a,b) ->
  a.x < b.x2 and a.x2 > b.x and
  a.y < b.y2 and a.y2 > b.y

globe.createLabels = ({labels, container, context}) ->
  startTime = + new Date
  visible = null
  labels = labels.map (label, i) ->
    circle = document.createElementNS container.namespaceURI, 'circle'
    circle.setAttribute 'r', 2
    text = document.createElementNS container.namespaceURI, 'text'
    text.textContent = label.name
    text2 = document.createElementNS container.namespaceURI, 'text'
    text2.setAttribute 'class', 'shadow'
    text2.textContent = label.name
    g = document.createElementNS container.namespaceURI, 'g'
    g.setAttribute('class', "scale#{label.scalerank}")
    g.appendChild circle
    g.appendChild text2
    g.appendChild text
    container.appendChild g

    bbox = text.getBBox()

    width: bbox.width + LABEL_SPACING.x * 2
    height: bbox.height + LABEL_SPACING.y * 2
    elt: g
    shown: startTime + 2000
    overlapped: startTime - 400
    opacity: 0
    earthLocation: context.createLocation label.lng, label.lat

  onupdate = ->
    updated = false
    t = + new Date
    # keep track of the visible labels. using a quadtree would be nicer
    visible = []

    labels.forEach (label) ->
      # only consider points on the front face of the globe
      angle = label.earthLocation.angle()
      if angle > Math.PI / 2
        label.opacity = 0
      else
        # TODO don't bother checking the position of points waiting to fade in and points that have recently faded out
        pos = label.earthLocation.screenPosition()
        label.x = pos.x - label.width / 2
        label.y = pos.y - label.height / 2
        label.x2 = label.x + label.width
        label.y2 = label.y + label.height

        if visible.some((match) -> overlaps match, label)
          unless label.overlapped?
            label.overlapped = t
            updated = true
          label.opacity = Math.min(1 - Math.max((t - label.overlapped) / FADE_OUT, 0), label.opacity)
          label.shown = null
        else
          label.overlapped = null
          unless label.shown?
            label.shown = t + SHOW_DELAY
            updated = true
          duration = t - label.shown
          if duration < 0
            updated = true
          label.opacity = Math.min(Math.max(duration / FADE_IN, label.opacity), 1)
          visible.push label

      if label.opacity > 0
        if label.opacity < 1
          updated = true
        maxOpacity = Math.min(1, (MIN_ANGLE - angle) / (MAX_ANGLE - MIN_ANGLE))
        label.elt.setAttribute 'style', 'display: inline; opacity: ' + label.opacity * maxOpacity
        label.elt.setAttribute 'transform', "translate(#{pos.x},#{pos.y})"
      else
        label.elt.setAttribute 'style', 'display: none'
    if updated
      context.updated()

  {onupdate}

