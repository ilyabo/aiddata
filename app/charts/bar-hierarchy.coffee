
this.barHierarchyChart = () ->

  nameAttr = "name" 
  childrenAttr = "children"
  valueAccessor = (d) -> d["value"]
  valueFormat = d3.format(",.0f")
  width = height = null
  currentNodeDescription = (d) -> d[nameAttr]
  barHeight = 12
  barSpacing = null
  labelsFormat = (d) -> d[nameAttr]
  labelsTooltipFormat = (d) -> d[nameAttr]



  chart = (selection) -> init(selection)

  chart.width = (_) -> if (!arguments.length) then fullwidth else fullwidth = _; chart

  chart.height = (_) -> if (!arguments.length) then fullheight else fullheight = _; chart

  chart.barHeight = (_) -> if (!arguments.length) then barHeight else barHeight = _; chart

  chart.labelsWidth = (_) -> if (!arguments.length) then margin.left else margin.left = _; chart

  chart.labelsFormat = (_) -> if (!arguments.length) then labelsFormat else labelsFormat = _; chart

  chart.labelsTooltipFormat = (_) -> if (!arguments.length) then labelsTooltipFormat else labelsTooltipFormat = _; chart

  chart.nameAttr = (_) -> if (!arguments.length) then nameAttr else nameAttr = _; chart

  chart.childrenAttr = (_) -> if (!arguments.length) then childrenAttr else childrenAttr = _; chart

  chart.values = (_) ->
    if (!arguments.length)
      valueAccessor
    else 
      valueAccessor = (if typeof _ is "function" then _ else (d) -> d[_])
      if vis?
        x.domain([ 0, d3.max(currentNode.children, valueAccessor ) ]).nice()
        updateBreadcrumbCaption(currentNode)
        vis.selectAll(".x.axis").transition().duration(50).call xAxis
        vis.selectAll("rect")
          .transition().duration(50)
          .attr("width", (d) -> x(valueAccessor(d)))
        vis.selectAll("g.barg").transition().duration(50).attr("transform", (d,i) -> stack(i))
      chart

  chart.valueFormat = (_) -> if (!arguments.length) then valueFormat else valueFormat = _; chart

  chart.currentNodeDescription = (_) -> if (!arguments.length) then currentNodeDescription else currentNodeDescription = _; chart

  currentNode = null
  data = null
  svg = vis = breadcrumb = null

  margin =
    top: 20
    right: 20
    bottom: 5 
    left: 150

  fullwidth = 550
  fullheight = 300

  x = null



  #z = d3.scale.ordinal().range([ "steelblue", "#ccc" ])
  duration = 300
  delay = 25


  hierarchy = d3.layout.partition()
    .value(valueAccessor)
    .children((d) -> d[childrenAttr])  # the sorted child list is stored in .children
                                       # thus .children is used further on
    .sort((a,b) -> valueAccessor(b) - valueAccessor(a))

  xAxis = null

 

  init = (selection) ->
    barSpacing = barHeight * 0.2
    width = fullwidth - margin.right - margin.left
    height = fullheight - margin.top - margin.bottom
    x = d3.scale.linear().range([ 0, width ])


    initVis(selection)
    data = selection.datum()
    currentNodeData = data


    xAxis = d3.svg.axis().scale(x)
      .orient("top")
      .ticks(3)
      .tickFormat(valueFormat)

    hierarchy.nodes(data)
    x.domain([ 0, valueAccessor(data) ]).nice()
    down data, 0



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

    x.domain([ 0, d3.max(d.children, valueAccessor ) ]).nice()

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
      .attr("width", (d) -> x(valueAccessor(d)))
      #.style("fill", (d) -> z(d.children?))
      #.classed("hasChildren", d.children?)


    exitTransition = exit.transition()
      .duration(duration)
      .style("opacity", 1e-6)
      .remove()

    exitTransition.selectAll("rect")
      .attr("width", (d) -> x(valueAccessor(d)))

    vis.select(".background").data([ d ]).transition().duration(end)
    d.index = i

    currentNode = d
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

    x.domain([ 0, d3.max(d.parent[childrenAttr], valueAccessor) ]).nice()



    vis.selectAll(".x.axis").transition().duration(duration).call xAxis
    enterTransition = enter.transition().duration(end).style("opacity", 1)

    enterTransition.select("rect").attr("width", (d) ->
      x(valueAccessor(d))
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
      .attr("width", (d) -> x(valueAccessor(d)))


    exit.transition().duration(end).remove()
    vis.select(".background").data([ d.parent ]).transition().duration end

    currentNode = d.parent
    updateBreadcrumb(d.parent)
    updateVisHeight(d.parent)




  bar = (d) ->
    b = vis.insert("g", ".y.axis")
        .attr("class", "enter")
        .attr("transform", "translate(0,5)")
      .selectAll("g")
        .attr("class", "barg")
        .data(d.children)
          .enter()
          .append("g")
        .on("click", down)
        ###
        .style("cursor", (d) ->
          (if not d.children then null else "pointer")
        )
        ###

    b.append("svg:title")
        .text(labelsTooltipFormat)

    b.append("text")
      .attr("x", -6)
      .attr("y", barHeight / 2)
      .attr("dy", ".35em")
      .attr("text-anchor", "end")
      .attr("class", labelClass)
      .text(labelsFormat)

    b.append("rect")
      .attr("x", 1)
      .attr("width", (d) -> x(valueAccessor(d)))
      .attr("height", barHeight)

    return b


  stack = (i) ->
    x0 = 0
    (d) ->
      tx = barTranslate(d, i)
      x0 += x(valueAccessor(d))
      tx





  breadcrumbPath = (node) ->
    path = []
    cur = node
    while cur?
      path.push cur
      cur = cur.parent 
    path.reverse()


    

  updateBreadcrumbCaption = (node) ->
    ###
    li.selectAll("li.total")
    ###
    caption = breadcrumb.select("div.caption")
    #caption.select("div.title").text(node[nameAttr])

    caption.select("div.total").text(currentNodeDescription(node))


  updateBreadcrumb = (node) ->
    
    path = breadcrumbPath node

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
      .classed("sel", (d) -> d == node)

    breadcrumbList.selectAll("li.node a")
      .attr("href", "#")
      .text((d) -> d[nameAttr])
      .on "click", (d, i) ->  
        if (d != node) then up(d.children[0])

    updateBreadcrumbCaption(node)

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






  chart



