nameAttr = "key"
childrenAttr = "values"
valueAttr = "amount"

margin =
  top: 20
  right: 20
  bottom: 20
  left: 120

width = 960 - margin.right - margin.left
height = 500 - margin.top - margin.bottom
x = d3.scale.linear().range([ 0, width ])
y = 20
z = d3.scale.ordinal().range([ "steelblue", "#ccc" ])
duration = 750
delay = 25

hierarchy = d3.layout.partition()
  .value((d) -> d[valueAttr])
  .sort((a,b) -> a[valueAttr] - b[valueAttr])

xAxis = d3.svg.axis().scale(x)
  .orient("top")
  .tickFormat(formatMagnitude)



down = (d, i) ->
  return  if not d[childrenAttr] or @__transition__
  end = duration + d[childrenAttr].length * delay
  exit = svg.selectAll(".enter").attr("class", "exit")
  
  exit.selectAll("rect").filter((p) -> p is d ).style "fill-opacity", 1e-6

  enter = bar(d).attr("transform", stack(i)).style("opacity", 1)
  enter.select("text").style "fill-opacity", 1e-6
  enter.select("rect").style "fill", z(true)

  x.domain([ 0, d3.max(d[childrenAttr], (d) -> d[valueAttr] ) ]).nice()

  svg.selectAll(".x.axis").transition().duration(duration).call xAxis
  enterTransition = enter.transition().duration(duration).delay((d, i) ->
    i * delay
  ).attr("transform", (d, i) -> "translate(0," + y * i * 1.2 + ")" )

  enterTransition.select("text").style "fill-opacity", 1
  enterTransition.select("rect").attr("width", (d) ->
    x d[valueAttr]
  ).style "fill", (d) ->
    z !!d[childrenAttr]

  exitTransition = exit.transition().duration(duration).style("opacity", 1e-6).remove()
  exitTransition.selectAll("rect").attr "width", (d) ->
    x d[valueAttr]

  svg.select(".background").data([ d ]).transition().duration end
  d.index = i


up = (d) ->
  return  if not d.parent or @__transition__
  
  end = duration + d[childrenAttr].length * delay
  exit = svg.selectAll(".enter").attr("class", "exit")
  
  enter = bar(d.parent)
    .attr("transform", (d, i) -> "translate(0," + y * i * 1.2 + ")")
    .style("opacity", 1e-6)


  enter.select("rect")
    .style("fill", (d) -> z(!!d[childrenAttr]))
    .filter((p) -> p is d)
    .style "fill-opacity", 1e-6

  x.domain([ 0, d3.max(d.parent[childrenAttr], (d) -> d[valueAttr]) ])
    .nice()

  svg.selectAll(".x.axis").transition().duration(duration).call xAxis
  enterTransition = enter.transition().duration(end).style("opacity", 1)
  enterTransition.select("rect").attr("width", (d) ->
    x(d[valueAttr])
  ).each "end", (p) ->
    d3.select(this).style "fill-opacity", null  if p is d

  exitTransition = exit.selectAll("g").transition().duration(duration).delay((d, i) ->
    i * delay
  ).attr("transform", stack(d.index))
  exitTransition.select("text").style "fill-opacity", 1e-6
  exitTransition.select("rect").attr("width", (d) ->
    x d[valueAttr]
  ).style "fill", z(true)
  exit.transition().duration(end).remove()
  svg.select(".background").data([ d.parent ]).transition().duration end


bar = (d) ->
  bar = svg.insert("g", ".y.axis").attr("class", "enter").attr("transform", "translate(0,5)").selectAll("g").data(d[childrenAttr]).enter().append("g").style("cursor", (d) ->
    (if not d[childrenAttr] then null else "pointer")
  ).on("click", down)
  bar.append("text").attr("x", -6).attr("y", y / 2).attr("dy", ".35em").attr("text-anchor", "end").text (d) ->
    d[nameAttr]

  bar.append("rect").attr("width", (d) ->
    x d[valueAttr]
  ).attr "height", y
  bar

stack = (i) ->
  x0 = 0
  (d) ->
    tx = "translate(" + x0 + "," + y * i * 1.2 + ")"
    x0 += x(d[valueAttr])
    tx



svg = d3.select("#purposeBars").append("svg").attr("width", width + margin.right + margin.left).attr("height", height + margin.top + margin.bottom).append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")")
svg.append("rect").attr("class", "background").attr("width", width).attr("height", height).on "click", up
svg.append("g").attr "class", "x axis"
svg.append("g").attr("class", "y axis").append("line").attr "y1", "100%"




d3.csv "aiddata-purposes-with-totals.csv/2005", (csv) ->

  data = nestPurposeDataByCategories(csv)
  removeSingleChildNodes(data)
  provideWithTotalAmount(data)

  console.log data
  hierarchy.nodes data
  x.domain([ 0, data[valueAttr] ]).nice()
  down data, 0



