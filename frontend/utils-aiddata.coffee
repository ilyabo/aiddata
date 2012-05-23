root = exports ? this


fmt = d3.format(",.0f")

root.magnitudeFormat = (d) ->
  if (d >= 1e6)
    "$#{fmt(d / 1e6)} million"
  else
    "$#{fmt(d)}" 

root.shortMagnitudeFormat = (d) -> magnitudeFormat(d).replace(" million", "M")
