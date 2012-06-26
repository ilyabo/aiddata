
nameAttr = "key"
childrenAttr = "values"
valueAttr = "amount"

margin =
  top: 20
  right: 20
  bottom: 20
  left: 240

width = 500 - margin.right - margin.left
height = 300 - margin.top - margin.bottom
x = d3.scale.linear().range([ 0, width ])
barHeight = 15
#z = d3.scale.ordinal().range([ "steelblue", "#ccc" ])
duration = 300
delay = 25

hierarchy = d3.layout.partition()
  .value((d) -> d[valueAttr])
  .children((d) -> d[childrenAttr])  # the sorted child list is stored in .children
                                     # thus .children is used further on
  #.sort((a,b) -> b[valueAttr] - a[valueAttr])

xAxis = d3.svg.axis().scale(x)
  .orient("top")
  .ticks(3)
  .tickFormat(formatMagnitude)


breadcrumb = d3.select("#purposeBars")
  .append("ul")
    .attr("class", "breadcrumb")



barClass = (d) -> if d.children? then "bar hasChildren" else "bar"


down = (d, i) ->
  return  if not d.children or @__transition__
  end = duration + d.children.length * delay
  exit = svg.selectAll(".enter").attr("class", "exit")
  
  exit.selectAll("rect").filter((p) -> p is d ).style "fill-opacity", 1e-6

  enter = bar(d).attr("transform", stack(i)).style("opacity", 1)
  enter.select("text").style "fill-opacity", 1e-6

  enter.select("rect")
    .attr("class", "bar")
    #.style "fill", z(true)

  x.domain([ 0, d3.max(d.children, (d) -> d[valueAttr] ) ]).nice()

  svg.selectAll(".x.axis").transition().duration(duration).call xAxis

  enterTransition = enter.transition().duration(duration).delay((d, i) ->
    i * delay
  ).attr("transform", (d, i) -> "translate(0," + barHeight * i * 1.2 + ")" )

  enterTransition.select("text")
    .style("fill-opacity", 1)

  enterTransition.select("rect")
    #.classed("bar", true)
    .attr("class", barClass)
    .attr("width", (d) -> x(d[valueAttr]))
    #.style("fill", (d) -> z(d.children?))
    #.classed("hasChildren", d.children?)


  exitTransition = exit.transition()
    .duration(duration)
    .style("opacity", 1e-6)
    .remove()

  exitTransition.selectAll("rect")
    .attr("width", (d) -> x(d[valueAttr]))

  svg.select(".background").data([ d ]).transition().duration(end)
  d.index = i

  updateBreadcrumb(d)





up = (d) ->
  return  if not d.parent or @__transition__
  
  end = duration + d.children.length * delay
  exit = svg.selectAll(".enter").attr("class", "exit")
  
  enter = bar(d.parent)
    .attr("transform", (d, i) -> "translate(0," + barHeight * i * 1.2 + ")")
    .style("opacity", 1e-6)


  enter.select("rect")
  .attr("class", barClass)
    #.style("fill", (d) -> z(!!d.children))
    .filter((p) -> p is d)
    .style "fill-opacity", 1e-6

  x.domain([ 0, d3.max(d.parent[childrenAttr], (d) -> d[valueAttr]) ]).nice()



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

  ###
  exitTransition.select("rect").attr("width", (d) ->
    x d[valueAttr]
  ).style "fill", z(true)
  ###

  enterTransition.select("rect")
    .attr("class", barClass)
    .attr("width", (d) -> x(d[valueAttr]))


  exit.transition().duration(end).remove()
  svg.select(".background").data([ d.parent ]).transition().duration end

  updateBreadcrumb(d.parent)



bar = (d) ->
  b = svg.insert("g", ".y.axis")
      .attr("class", "enter")
      .attr("transform", "translate(0,5)")
    .selectAll("g")
      .data(d.children)
        .enter()
        .append("g")
    .style("cursor", (d) ->
      (if not d.children then null else "pointer")
    ).on("click", down)


  b.append("text")
    .attr("x", -6)
    .attr("y", barHeight / 2)
    .attr("dy", ".35em")
    .attr("text-anchor", "end")
    .text (d) -> d[nameAttr]

  b.append("rect")
    .attr("x", 1)
    .attr("width", (d) -> x(d[valueAttr]))
    .attr("height", barHeight)

  return b


stack = (i) ->
  x0 = 0
  (d) ->
    tx = "translate(" + x0 + "," + barHeight * i * 1.2 + ")"
    x0 += x(d[valueAttr])
    tx



svg = d3.select("#purposeBars")
  .append("svg")
    .attr("width", width + margin.right + margin.left)
    .attr("height", height + margin.top + margin.bottom)
  .append("g")
    .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

svg.append("rect")
  .attr("class", "background")
  .attr("width", width)
  .attr("height", height)
  .on("click", up)

svg.append("g").attr "class", "x axis"
svg.append("g").attr("class", "y axis").append("line").attr "y1", "100%"



breadcrumbPath = (currentNode) ->
  path = []
  cur = currentNode
  while cur?
    path.push cur
    cur = cur.parent 
  path.reverse()


  


updateBreadcrumb = (currentNode) ->
  # enter
  li = breadcrumb.selectAll("li")
    .data(breadcrumbPath currentNode)

  lil = li.enter().append("li")

  lil.append("a")
      .attr("href", "#")
      .text((d) -> d[nameAttr])
  lil.append("span").attr("class", "divider").text("/")

  # update
  breadcrumb.selectAll("li a")
    .attr("href", "#")
    .text((d) -> d[nameAttr])

  # remove
  li.exit().remove()



  console.log d3.selectAll("#purposeBars ul.breadcrumb li")

  ###
  bc = d3.select("#purposeBars .breadcrumb")
  d3.enter() 
  ###    

  

  


  ###
  bc.append("li")
    .attr("class", "title")
    .text("Filter by purpose:")

  li = bc.append("li")

  li.append("a")
        .attr("href", "#")
        .text("Commodity Aid And General Program Assistance")
  li.append("span")
        .attr("class", "divider")
        .text("/")


  bc.append("li")
      .append("a")
        .attr("href", "#")
        .text("Food aid/Food security programmes - 52010")
  ###

###
  <li>
    <a href="#">Home</a> <span class="divider">/</span>
  </li>
  <li>
    <a href="#">Library</a> <span class="divider">/</span>
  </li>
  <li class="active">Data</li>
<
###

###
$("#purposeBars .breadcrumb").append("""
  <li>
    <a href="#">Home</a> <span class="divider">/</span>
  </li>
  <li>
    <a href="#">Library</a> <span class="divider">/</span>
  </li>
  <li class="active">Data</li>"""
)
###


d3.csv "aiddata-purposes-with-totals.csv/2009", (csv) ->

  data = nestPurposeDataByCategories(csv)
  removeSingleChildNodes(data)
  provideWithTotalAmount(data)

  hierarchy.nodes(data)
  x.domain([ 0, data[valueAttr] ]).nice()
  down data, 0




