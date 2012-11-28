
this.barHierarchyChart = () ->

  nameAttr = "name"
  keyAttr = "key"
  childrenAttr = "children"
  valueAccessor = (d) -> d["value"]
  valueFormat = d3.format(",.0f")
  width = height = null
  breadcrumbText = (d) -> d[nameAttr]
  barHeight = 12
  barSpacing = null
  labelsFormat = (d) -> d[nameAttr]
  labelsTooltipFormat = (d) -> d[nameAttr]
  leafsSelectable = false

  fullwidth = 550
  fullheight = 300

  


  chart = (selection) -> init(selection)

  chart.width = (_) -> if (!arguments.length) then fullwidth else fullwidth = _; chart

  chart.height = (_) -> if (!arguments.length) then fullheight else fullheight = _; chart

  chart.barHeight = (_) -> if (!arguments.length) then barHeight else barHeight = _; chart

  chart.labelsWidth = (_) -> if (!arguments.length) then margin.left else margin.left = _; chart

  chart.labelsFormat = (_) -> if (!arguments.length) then labelsFormat else labelsFormat = _; chart

  chart.labelsTooltipFormat = (_) -> if (!arguments.length) then labelsTooltipFormat else labelsTooltipFormat = _; chart

  chart.nameAttr = (_) -> if (!arguments.length) then nameAttr else nameAttr = _; chart

  chart.childrenAttr = (_) -> if (!arguments.length) then childrenAttr else childrenAttr = _; chart

  chart.leafsSelectable = (_) -> if (!arguments.length) then leafsSelectable else leafsSelectable = (if _ then true else false); chart

  chart.values = (_) ->
    if (!arguments.length)
      valueAccessor
    else 
      valueAccessor = (if typeof _ is "function" then _ else (d) -> d[_])
      if vis? then updateValues()
      chart

  chart.valueFormat = (_) -> if (!arguments.length) then valueFormat else valueFormat = _; chart

  chart.breadcrumbText = (_) -> if (!arguments.length) then breadcrumbText else breadcrumbText = _; chart


  dispatch = d3.dispatch("select")

  # Expose the dispatch's "on" method.
  d3.rebind(chart, dispatch, "on");


  currentNode = null
  data = null
  svg = vis = breadcrumb = breadcrumbCaption = null

  margin =
    top: 20
    right: 20
    bottom: 5 
    left: 150

  x = null



    #bar(currentNode).transition().duration(duration).attr("transform", barTranslate)


  #z = d3.scale.ordinal().range([ "steelblue", "#ccc" ])
  duration = 300
  delay = 25

  comparator = (a,b) -> valueAccessor(b) - valueAccessor(a)
  hierarchy = d3.layout.partition()
    .value(valueAccessor)
    .children((d) -> d[childrenAttr])  # the sorted child list is stored in .children
                                       # thus .children is used further on
    .sort(comparator)


  xAxis = null

  findNodeByKey = (key, data) ->
    recurse = (node) ->
      return node if (node[keyAttr] is key)
      if node[childrenAttr]?
        for child in node[childrenAttr]
          found = recurse(child)
          return found if found?
      return null
    recurse(data)


  isUpdate = false

  init = (selection) ->
    barSpacing = barHeight * 0.2
    width = fullwidth - margin.right - margin.left
    height = fullheight - margin.top - margin.bottom

    svg = selection.select("svg")
    isUpdate = not svg.empty()

    if isUpdate
      vis = svg.select("g.vis")
    else
      x = d3.scale.linear().range([ 0, width ])
      xAxis = d3.svg.axis().scale(x)
        .orient("top")
        .ticks(3)
        .tickFormat(valueFormat)
      initVis(selection)


    data = selection.datum()
    if isUpdate
      # keep the same node selected
      currentNode = findNodeByKey(currentNode[keyAttr], data) ? data
      #children = (if currentNode.children? then currentNode.children else [currentNode])
      #vis.selectAll("g.barg").data(children).selectAll("rect").data((d) -> d)
    else
      currentNode = data

    hierarchy.nodes(data)
    x.domain([ 0, valueAccessor(data) ]).nice()


    down currentNode, 0, true
    # if isUpdate
    #   updateValues(0)
    # else
    #   down data, 0, true



  initVis = (selection) ->
    unless isUpdate
      selection.attr("class", "barHierarchy")
      initBreadcrumb(selection)

      svg = selection.append("svg")
      
      svg.attr("width", width + margin.right + margin.left)
         .attr("height", height + margin.top + margin.bottom)


      vis = svg.append("g")
        .attr("class", "vis")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

      vis.append("rect")
        .attr("class", "background")
        .attr("width", width)
        .attr("height", height)
        .on("click", up)

      vis.append("g").attr("class", "x axis")
      vis.append("g").attr("class", "y axis").append("line").attr "y1", "100%"


  barTranslate = (d, i) -> "translate(0," + (barHeight + barSpacing) * i + ")"


  # update upon the change of the represented value (e.g. year)
  updateValues = do ->
    duration = 500
    shortDuration = 50

    update = ->
      children = (if currentNode.children? then currentNode.children else [currentNode])

      # bar ordering
      if currentNode.children?
        vis.selectAll("g.barg")
          .sort(comparator)
          .transition()
            .duration(duration)
            .attr("transform", barTranslate)

      # x axis scale
      x.domain([ 0, d3.max(children, valueAccessor ) ]).nice()
      vis.selectAll(".x.axis")
        .transition()
          .duration(duration)
          .call xAxis

      # bar widths in the new scale
      vis.selectAll("rect")
        .transition()
          .duration(duration)
          .attr("width", (d) -> x(valueAccessor(d)))

    prev = 0

    # only update if at least endTransitionDelay passed since the last value change
    maybeUpdate = ->
      if (Date.now() - prev >= delay) then update()
      return true  # causes the timer to stop


    (delay = 1000) ->
      updateBreadcrumbCaption(currentNode)
      vis.selectAll("rect")
        .transition()
          .duration(shortDuration)
          .attr("width", (d) -> x(valueAccessor(d)))

      prev = Date.now()
      d3.timer maybeUpdate, delay



  down = (d, i, init = false) ->
    return  if (!leafsSelectable and !d.children) or @__transition__
    end = duration + (if d.children then d.children.length else 1)* delay
    exit = vis.selectAll(".enter").attr("class", "exit")
    
    exit.selectAll("rect")
      .filter((p) -> p is d )
      .style "fill-opacity", 1e-6

    enter = bar(d).attr("transform", stack(i))
      .style("opacity", 1)
    enter.select("text")
      .style("fill-opacity", 1e-6)

    #enter.select("rect")
    #  .attr("class", "bar")
    #  .style "fill", z(true)

    x.domain([ 0, d3.max((if d.children? then d.children else [d]), valueAccessor ) ]).nice()

    vis.selectAll(".x.axis").transition().duration(duration).call xAxis

    enterTransition = enter
      .sort(comparator)
      .transition()
        .duration(duration)
        .delay((d, i) -> i * delay)
        .attr("transform", barTranslate)

    enterTransition.select("text")
      .style("fill-opacity", 1)

    enterTransition.select("rect")
      #.classed("bar", true)
      .attr("width", (d) -> x(valueAccessor(d)))
      #.style("fill", (d) -> z(d.children?))
      #.classed("selectable", d.children?)


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
    dispatch.select.apply(chart, [d]) unless init






  up = (d) ->
    return  if not d.parent or @__transition__
    
    end = duration + (if d.children? then d.children.length else 1) * delay
    exit = vis.selectAll(".enter").attr("class", "exit")
    
    enter = bar(d.parent)
      .sort(comparator)
      .attr("transform", barTranslate)
      .style("opacity", 1e-6)


    enter.select("rect")
      #.style("fill", (d) -> z(!!d.children))
      .filter((p) -> p is d)
      .style "fill-opacity", 1e-6

    x.domain([ 0, d3.max(d.parent[childrenAttr], valueAccessor) ]).nice()



    vis.selectAll(".x.axis")
      .transition()
        .duration(duration)
        .call xAxis

    enterTransition = enter.transition().duration(end).style("opacity", 1)

    enterTransition.select("rect")
      .attr("width", (d) -> x(valueAccessor(d)))
      .each "end", (p) -> d3.select(this).style "fill-opacity", null  if p is d


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
      .attr("width", (d) -> x(valueAccessor(d)))


    exit.transition().duration(end).remove()
    vis.select(".background").data([ d.parent ]).transition().duration end

    currentNode = d.parent
    updateBreadcrumb(d.parent)
    updateVisHeight(d.parent)
    dispatch.select.apply(chart, [d.parent])


  bar = (d) ->
    b = vis.insert("g", ".y.axis")
        .attr("class", "enter")
        .attr("transform", "translate(0,5)")
      .selectAll("g.barg")
        .data(if d.children? then d.children else [d])
          .enter()
      .append("g")
        .attr("class", "barg")
        .on("mouseover", -> d3.select(this).classed("highlight", true))
        .on("mouseout", -> d3.select(this).classed("highlight", false))

    if d.children? then b.on("click", (d) -> 
      d3.select(this).classed("highlight", false)
      down(d)
    )

    ###
    .style("cursor", (d) ->
      (if not d.children then null else "pointer")
    )
    ###

    b.append("svg:title")
        .text(labelsTooltipFormat)

    b.append("text")
      .attr("class",
        if d.children?
          ((d) -> if d.children? or leafsSelectable then "barLabel selectable" else "barLabel") 
        else "barLabel"
      )
      .attr("x", -6)
      .attr("y", barHeight / 2)
      .attr("dy", ".35em")
      .attr("text-anchor", "end")
      .text(labelsFormat)

    b.append("rect")
      .attr("class", 
        if d.children?
          ((d) -> if d.children? or leafsSelectable then "bar selectable" else "bar") 
        else "bar"
      )
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
    breadcrumbCaption.select("div.total").text(breadcrumbText(node))


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
      .text(labelsFormat)
      .on "click", (d, i) ->
        if (i < path.length - 1) then up(path[i + 1]) #d.children[0])

    updateBreadcrumbCaption(node)

    # remove
    li.exit().remove()



  updateVisHeight = (d) ->
    h = (if d.children then d.children.length else 1) * (barHeight + barSpacing) #+ margin.top + margin.bottom
    svg.transition()
      .duration(duration)
      .attr("height", h + margin.top + margin.bottom)


  initBreadcrumb = (selection) ->
    breadcrumb = selection
      .append("div")
        .attr("class", "breadcrumb")
        .style("width", fullwidth + "px")

    breadcrumb.append("ul")

    breadcrumbCaption = selection
      .append("div")
        .attr("class", "caption")

    breadcrumbCaption.append("div").attr("class", "title")
    breadcrumbCaption.append("div").attr("class", "total")






  chart



