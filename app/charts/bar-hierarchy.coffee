
this.barHierarchyChart = () ->

  nameAttr = "name" 
  childrenAttr = "children"
  valueAttr = "value"
  valueFormat = d3.format(",.0f")

  currentNodeDescription = (currentNode) -> currentNode[nameAttr]


  data = null
  svg = vis = breadcrumb = null

  margin =
    top: 20
    right: 20
    bottom: 5 
    left: 150

  fullwidth = 550
  fullheight = 300

  width = height = null
  x = null

  barHeight = 12
  barSpacing = null


  #z = d3.scale.ordinal().range([ "steelblue", "#ccc" ])
  duration = 300
  delay = 25


  hierarchy = d3.layout.partition()
    .value((d) -> d[valueAttr])
    .children((d) -> d[childrenAttr])  # the sorted child list is stored in .children
                                       # thus .children is used further on
    #.sort((a,b) -> b[valueAttr] - a[valueAttr])

  xAxis = null

 
  leafNodeClass = (d, nodeClass, leafClass) ->
    if d.children? then nodeClass else leafClass

  barClass = (d) -> leafNodeClass(d, "bar hasChildren", "bar")
  labelClass = (d) -> leafNodeClass(d, "barLabel hasChildren", "barLabel")
  barTranslate = (d, i) -> "translate(0," + (barHeight + barSpacing) * i + ")"


  down = (d, i) ->
    return  if not d.children or @__transition__
    end = duration + d.children.length * delay
    exit = vis.selectAll(".enter").attr("class", "exit")
    
    exit.selectAll("rect").filter((p) -> p is d ).style "fill-opacity", 1e-6

    enter = bar(d).attr("transform", stack(i))
      .style("opacity", 1)
    enter.select("text")
      .style("fill-opacity", 1e-6)

    enter.select("rect")
      .attr("class", "bar")
      #.style "fill", z(true)

    x.domain([ 0, d3.max(d.children, (d) -> d[valueAttr] ) ]).nice()

    vis.selectAll(".x.axis").transition().duration(duration).call xAxis

    enterTransition = enter.transition()
      .duration(duration)
      .delay((d, i) -> i * delay)
      .attr("transform", barTranslate)

    enterTransition.select("text")
      .attr("class", labelClass)
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

    vis.select(".background").data([ d ]).transition().duration(end)
    d.index = i

    updateBreadcrumb(d)
    updateVisHeight(d)






  up = (d) ->
    return  if not d.parent or @__transition__
    
    end = duration + d.children.length * delay
    exit = vis.selectAll(".enter").attr("class", "exit")
    
    enter = bar(d.parent)
      .attr("transform", barTranslate)
      .style("opacity", 1e-6)


    enter.select("rect")
    .attr("class", barClass)
      #.style("fill", (d) -> z(!!d.children))
      .filter((p) -> p is d)
      .style "fill-opacity", 1e-6

    x.domain([ 0, d3.max(d.parent[childrenAttr], (d) -> d[valueAttr]) ]).nice()



    vis.selectAll(".x.axis").transition().duration(duration).call xAxis
    enterTransition = enter.transition().duration(end).style("opacity", 1)

    enterTransition.select("rect").attr("width", (d) ->
      x(d[valueAttr])
    ).each "end", (p) ->
      d3.select(this).style "fill-opacity", null  if p is d

    exitTransition = exit.selectAll("g").transition().duration(duration).delay((d, i) ->
      i * delay
    ).attr("transform", stack(d.index))

    exitTransition.select("text")
      .style("fill-opacity", 1e-6)

    ###
    exitTransition.select("rect").attr("width", (d) ->
      x d[valueAttr]
    ).style "fill", z(true)
    ###

    enterTransition.select("rect")
      .attr("class", barClass)
      .attr("width", (d) -> x(d[valueAttr]))


    exit.transition().duration(end).remove()
    vis.select(".background").data([ d.parent ]).transition().duration end

    updateBreadcrumb(d.parent)
    updateVisHeight(d.parent)




  bar = (d) ->
    b = vis.insert("g", ".y.axis")
        .attr("class", "enter")
        .attr("transform", "translate(0,5)")
      .selectAll("g")
        .data(d.children)
          .enter()
          .append("g")
        .on("click", down)
        ###
        .style("cursor", (d) ->
          (if not d.children then null else "pointer")
        )
        ###


    b.append("text")
      .attr("x", -6)
      .attr("y", barHeight / 2)
      .attr("dy", ".35em")
      .attr("text-anchor", "end")
      .attr("class", labelClass)
      .text (d) -> d[nameAttr]

    b.append("rect")
      .attr("x", 1)
      .attr("width", (d) -> x(d[valueAttr]))
      .attr("height", barHeight)

    return b


  stack = (i) ->
    x0 = 0
    (d) ->
      tx = barTranslate(d, i)
      x0 += x(d[valueAttr])
      tx





  breadcrumbPath = (currentNode) ->
    path = []
    cur = currentNode
    while cur?
      path.push cur
      cur = cur.parent 
    path.reverse()


    


  updateBreadcrumb = (currentNode) ->
    
    path = breadcrumbPath currentNode

    breadcrumbList = breadcrumb.select("ul")
    # enter
    li = breadcrumbList.selectAll("li.node")
      .data(path)
    
    lie = li.enter()

    newli = lie.append("li")
      .attr("class", "node")

    newli.append("span")
      .attr("class", (d,i) -> if (i > 0) then "divider" else "first")
      .text((d, i) -> if (i > 0) then "/" else "")
    newli.append("a")
      .attr("href", "#")

    ###
    lie.append("li")
      .attr("class", "total")
    ###

    # update
    breadcrumbList.selectAll("li.node")
      .classed("sel", (d) -> d == currentNode)

    breadcrumbList.selectAll("li.node a")
      .attr("href", "#")
      .text((d) -> d[nameAttr])
      .on "click", (d, i) ->  
        if (d != currentNode) then up(d.children[0])

    ###
    li.selectAll("li.total")
    ###
    caption = breadcrumb.select("div.caption")
    #caption.select("div.title").text(currentNode[nameAttr])

    caption.select("div.total").text(currentNodeDescription(currentNode))


    # remove
    li.exit().remove()



  updateVisHeight = (d) ->
    h = (d.children.length) * (barHeight + barSpacing) #+ margin.top + margin.bottom
    svg.transition()
      .duration(duration)
      .attr("height", h + margin.top + margin.bottom)


  initBreadcrumb = (selection) ->
    breadcrumb = selection
      .append("div")
        .attr("class", "breadcrumb")
    
    breadcrumb.append("ul")

    breadcrumbCaption = breadcrumb
      .append("div")
        .attr("class", "caption")

    breadcrumbCaption.append("div").attr("class", "title")
    breadcrumbCaption.append("div").attr("class", "total")


  initVis = (selection) ->
    selection.attr("class", "barHierarchy")
    initBreadcrumb(selection)

    svg = selection
      .append("svg")
        .attr("width", width + margin.right + margin.left)
        .attr("height", height + margin.top + margin.bottom)

    vis = svg.append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

    vis.append("rect")
      .attr("class", "background")
      .attr("width", width)
      .attr("height", height)
      .on("click", up)

    vis.append("g").attr("class", "x axis")
    vis.append("g").attr("class", "y axis").append("line").attr "y1", "100%"





  chart = (selection) ->
    barSpacing = barHeight * 0.2
    width = fullwidth - margin.right - margin.left
    height = fullheight - margin.top - margin.bottom
    x = d3.scale.linear().range([ 0, width ])


    initVis(selection)
    data = selection.datum()



    xAxis = d3.svg.axis().scale(x)
      .orient("top")
      .ticks(3)
      .tickFormat(valueFormat)

    hierarchy.nodes(data)
    x.domain([ 0, data[valueAttr] ]).nice()
    down data, 0


  chart.width = (_) -> if (!arguments.length) then fullwidth else fullwidth = _; chart

  chart.height = (_) -> if (!arguments.length) then fullheight else fullheight = _; chart

  chart.barHeight = (_) -> if (!arguments.length) then barHeight else barHeight = _; chart

  chart.labelsWidth = (_) -> if (!arguments.length) then margin.left else margin.left = _; chart

  chart.nameAttr = (_) -> if (!arguments.length) then nameAttr else nameAttr = _; chart

  chart.childrenAttr = (_) -> if (!arguments.length) then childrenAttr else childrenAttr = _; chart

  chart.valueAttr = (_) -> if (!arguments.length) then valueAttr else valueAttr = _; chart

  chart.valueFormat = (_) -> if (!arguments.length) then valueFormat else valueFormat = _; chart

  chart.currentNodeDescription = (_) -> if (!arguments.length) then currentNodeDescription else currentNodeDescription = _; chart


  chart



