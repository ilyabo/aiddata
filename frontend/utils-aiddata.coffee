root = exports ? this


fmt = d3.format(",.0f")

root.formatMagnitudeLong = (d) -> "$#{fmt(d)}"

root.formatMagnitude = root.magnitudeFormat = (d) ->
  if (d >= 1e15)
    "$#{fmt(d / 1e15)}P"
  else if (d >= 1e12)
    "$#{fmt(d / 1e12)}T"
  else if (d >= 1e9)
    "$#{fmt(d / 1e9)}G"
  else if (d >= 1e6)
    "$#{fmt(d / 1e6)}M"
  else if (d >= 1e3)
    "$#{fmt(d / 1e3)}k"
  else
    "$#{fmt(d)}" 

root.formatMagnitudeShort = root.shortMagnitudeFormat = (d) -> formatMagnitude(d)
