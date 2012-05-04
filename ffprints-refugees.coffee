width = $(document).width() * .95
height = width / 2
chart =
  ffprintsChart()
    .width(width).height(height)
    .flowOriginAttr('Origin')
    .flowDestAttr('Dest')
    .nodeIdAttr('Code')
    .latAttr('Lat')
    .lonAttr('Lon')
    .flowMagnitudeAttrs
      refugees:
        attrs: [1975..2009],
        explain: 'In #attr# there were #magnitude# refugees from #origin# in #dest#'

$(document).ready ->
  $('#useForce').click -> chart.useForce()
  $('#useGeoNodePositions').click -> chart.useGeoNodePositions()
  ###
  $("#slider")
    .slider
      orientation: 'horizontal'
      #range: true
      min: 0.01
      max: 0.2
      value: 0.1
      #values: [25, 75]
      step:0.01
      change: (e, ui) -> chart.forceK $("#slider").slider("option", "value")
  ###
