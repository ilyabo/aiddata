random = (x) ->
  value = 0
  values = []
  i = 0
  last = undefined
  context.metric ((start, stop, step, callback) ->
    start = +start
    stop = +stop

    last = start  if isNaN(last)
    while last < stop
      last += step
      value = Math.max(-10, Math.min(10, value + .8 * Math.random() - .4 + .2 * Math.cos(i += x * .02)))
      values.push value
    callback null, values = values.slice((start - stop) / step)
  ), "row" + x


context = cubism.context().step(1.6e9).size(1280)

d3.select("#horizonChart").selectAll(".axis")
    .data([ "top", "bottom" ])
  .enter()
    .append("div")
    .attr("class", (d) ->
      d + " axis"
    ).each (d) ->
      d3.select(this).call context.axis().ticks(12).orient(d)

d3.select("#horizonChart").append("div").attr("class", "rule").call context.rule()
d3.select("#horizonChart").selectAll(".horizon")
  .data(d3.range(1, 50).map(random))
    .enter()
  .insert("div", ".bottom")
    .attr("class", "horizon")
    .call context.horizon().extent([ -10, 10 ])

context.on "focus", (i) ->
  d3.selectAll(".value").style "right", (if not i? then null else context.size() - i + "px")