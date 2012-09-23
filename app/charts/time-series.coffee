this.timeSeriesChart = ->

  title = ""
  width = 300
  height = 200
  dateProp = "date"
  valueProp = "value"
  interpolate = null # default is "monotone"
  showDots = true
  dotRadius = 2
  xticks = yticks = null
  marginLeft = 40
  marginRight = 8
  ytickFormat = d3.format(",.0f")
  showLegend = false
  indexedMode = false
  legendWidth = 150
  legendHeight = null  # will be set to height by default
  legendItemHeight = 15
  legendItemWidth = 80
  legendMarginLeft = 20
  legendMarginTop = 0
  #properties = null
  showRule = false
  ruleDate = null
  valueDomain = dateDomain = null

  eventListeners = {}

  propColors = d3.scale.category10()

  # borrowed from chroma.js: chroma.brewer.Set1
  # ["#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00", "#ffff33", "#a65628", "#f781bf", "#999999"]
  # Set3 (more pastel colors):
  #  ["#8dd3c7", "#ffffb3", "#bebada", "#fb8072", "#80b1d3", "#fdb462", "#b3de69", "#fccde5", "#d9d9d9", "#bc80bd", "#ccebc5", "#ffed6f"]


  # data is expected to be in the following form:
  # [{date:Date, inbound:123, outbound:321}, ...]
  #
  # either:  [ { date:Date, value:123 },  { date:Date, value:123 }, ... ] for one property
  # or { 
  #    prop1: [ { date:Date, value:123 },  { date:Date, value:123 }, ... ]
  #    prop2: [ { date:Date, value:123 },  { date:Date, value:123 }, ... ]
  # }

  chart = (selection) -> init(selection)

  chart.title = (_) -> if (!arguments.length) then title else title = _; chart

  chart.dateProp = (_) -> if (!arguments.length) then dateProp else dateProp = _; chart

  chart.valueProp = (_) -> if (!arguments.length) then valueProp else valueProp = _; chart

  chart.dateDomain = (_) -> if (!arguments.length) then dateDomain else dateDomain = _; chart

  chart.valueDomain = (_) -> if (!arguments.length) then valueDomain else valueDomain = _; chart

  getValueProp = (prop) ->
    if typeof valueProp is "function"
      valueProp.call this, prop
    else
      valueProp

  # which properties to visualize
  #chart.properties = (_) -> if (!arguments.length) then properties else properties = _; chart

  chart.width = (_) -> if (!arguments.length) then width else width = _; chart

  chart.showDots = (_) -> if (!arguments.length) then showDots else showDots = _; chart

  chart.dotRadius = (_) -> if (!arguments.length) then dotRadius else dotRadius = _; chart

  chart.xticks = (_) -> if (!arguments.length) then xticks else xticks = _; chart

  chart.yticks = (_) -> if (!arguments.length) then yticks else yticks = _; chart

  chart.height = (_) -> if (!arguments.length) then height else height = _; chart

  chart.marginLeft = (_) -> if (!arguments.length) then marginLeft else marginLeft = _; chart

  chart.marginRight = (_) -> if (!arguments.length) then marginRight else marginRight = _; chart

  chart.interpolate = (_) -> if (!arguments.length) then interpolate else interpolate = _; chart

  chart.ytickFormat = (_) -> if (!arguments.length) then ytickFormat else ytickFormat = _; chart

  chart.showLegend = (_) -> if (!arguments.length) then showLegend else showLegend = (if _ then true else false); chart

  chart.indexedMode = (_) -> if (!arguments.length) then indexedMode else indexedMode = (if _ then true else false); chart

  chart.showRule = (_) -> if (!arguments.length) then showRule else showRule = (if _ then true else false); chart

  chart.legendWidth = (_) -> if (!arguments.length) then legendWidth else legendWidth = _; chart

  chart.legendHeight = (_) -> if (!arguments.length) then legendHeight else legendHeight = _; chart


  chart.propColors = (_) -> if (!arguments.length) then propColors else propColors = _; chart

  # Supported events: "rulemove", "mouseover", "mouseout", "click"
  chart.on = (eventName, listener) -> 
    (eventListeners[eventName] ?= []).push(listener); chart

  fire = (eventName, args...) -> 
    listeners = eventListeners[eventName]
    if listeners?
      l.apply(chart, args) for l in listeners


  chart.moveRule = (date) ->
    if date isnt ruleDate
      rule = vis.selectAll("line.rule")
      if date?
        rule.attr("visibility", "visible")
          .attr("x1", x(date))
          .attr("x2", x(date))
      else
        rule.attr("visibility", "hidden")

      ruleDate = date

      fire("rulemove", date)


  propData = (data) -> (if (data instanceof Array) then { value: data } else data)


  chart.update = (selection) ->

    data = propData(selection.datum())
    vis.datum(data)

    updateScaleDomains(data)

    # vis.selectAll("path.line").remove()
    # vis.selectAll("circle.dot").remove()

    vis.selectAll("g.prop").remove()
    vis.selectAll("g.legend").remove()


    vis.selectAll(".x.axis")
    #    .transition()
    #      .duration(updateDuration)
          .call xAxis

    vis.selectAll(".y.axis")
    #    .transition()
    #      .duration(updateDuration)
          .call yAxis

    #enter(data)
    update(data)


  # enter = (data) ->
  #   # dates = data.map (d) -> d[dateProp]

  #   for prop, pi in propsOf(data)
  #     line = lineDrawer(prop)

  #     g = vis.append("g")
  #       .attr("class", "prop #{prop}")

  #     g.append("path")
  #       .attr("class", "line")
  #       .attr("d", line)
  #       .attr("stroke", propColors[pi % propColors.length])

  #     # if showDots
  #     #   dots = g.selectAll("circle.dot")
  #     #     .data(dates.filter (d) -> (not isNaN(y(nested[d]?[prop]))))

  #     #   dots.enter().append("circle")
  #     #     .attr("class", "dot")
  #     #     .attr("r", dotRadius)


  update = (data, duration = updateDuration) ->
    
    data = propData(data)

    pi = -1
    for prop, entries of data
      pi++

      g = vis.append("g").datum(entries)
        .attr("class", "prop pi_#{pi}")

      line = d3.svg.line()
        .x((d) -> x(d[dateProp]))
        .y((d) -> y(d[getValueProp(prop)]))
        .defined((d) -> vp = getValueProp(prop); d[vp]? and !isNaN(d[vp]))
        .interpolate(interpolate)


      g.append("path")
        .attr("class", "line")
        .attr("d", line)
        .attr("stroke", propColors[pi % propColors.length])


      # g = vis.select("g.#{prop}")
      
      # g.select("path")
      #     #.transition()
      #      # .duration(duration)
      #     .attr("d", line)


      if showDots
        dots = g.selectAll("circle.dot").data(entries)

        dots.enter().append("circle")
          .attr("class", "dot")
          .attr("r", dotRadius)
          .attr("stroke", propColors[pi % propColors.length])

        dots
          .attr("cx", (d) -> x(d[dateProp]))
          .attr("cy", (d) -> y(d[getValueProp(prop)]))

        dots.exit().remove()


    if showLegend

      props = d3.keys(data)

      legend = vis.append("g")
        .attr("class", "legend")
        .attr("transform", "translate(#{width - marginLeft + legendMarginLeft},#{legendMarginTop})")


      colSize = Math.floor(legendHeight/legendItemHeight)

      item = legend.selectAll("g.legendItem")
        .data(props)
      .enter().append("g")
        .attr("class", "legendItem")
        .attr("transform", (d, i) -> 
          col = Math.floor(i/colSize) 
          row = i % colSize
          "translate(#{col * legendItemWidth},#{row * legendItemHeight})")

      item.append("rect")
        .attr("x", 0)
        .attr("y", 0)
        .attr("rx", 2)
        .attr("ry", 2)
        .attr("width", 8)
        .attr("height", 8)
        .attr("fill", (d, pi) -> propColors[pi % propColors.length])

      item.append("text")
        .attr("x", 13)
        .attr("y", 4)
        .text((d) -> d)
        

  updateDuration = 1300

  x = y = null  # scales
  xAxis = yAxis = null
  svg = vis = null

  isNumber = (obj) -> (obj is +obj) or toString.call(obj) is '[object Number]'



  updateScaleDomains = (data) ->

    if valueDomain?
      y.domain(valueDomain)
    else
      valueExtents = (d3.extent(values, (d) -> d[getValueProp(prop)]) for prop, values of data)
      valueExtent = [ d3.min(valueExtents, (d) -> d[0]), d3.max(valueExtents, (d) -> d[1]) ] 
      y.domain([ Math.min(0, valueExtent[0]),  valueExtent[1] ])


    if dateDomain?
      x.domain(dateDomain)
    else
      dateExtents = (d3.extent(values, (d) -> d[dateProp]) for prop, values of data)
      dateExtent = [ d3.min(dateExtents, (d) -> d[0]), d3.max(dateExtents, (d) -> d[1]) ] 
      x.domain([ dateExtent[0],  dateExtent[1] ])




  init = (selection) -> 

    element = selection
    data = propData(selection.datum())

    if svg?
      chart.update(selection)
      return


    margin = {top: 28, right: marginRight, bottom: 14, left: marginLeft}

    legendHeight ?= height - margin.top - margin.bottom

    w = width - margin.left - margin.right
    h = height - margin.top - margin.bottom


    x = d3.time.scale().range([0, w])          
    y = d3.scale.linear().range([h, 0])

    updateScaleDomains(data)

    xAxis = d3.svg.axis()
      .scale(x)
      .ticks(xticks ? Math.max(1, Math.round(w/30)))
      .orient("bottom")
      .tickSize(3, 0, 0)

    yAxis = d3.svg.axis()
      .ticks(yticks ? Math.max(1, Math.round(h/18)))
      .scale(y)
      .orient("left")
      .tickFormat(ytickFormat)
      .tickSize(-w, 0, 0)

    svg = element.append("svg")
        .attr("width", w + margin.left + margin.right + 
                      (if showLegend then legendWidth else 0))
        .attr("height", 
          Math.max(h + margin.top + margin.bottom, legendHeight + margin.top + margin.bottom))

    svg.append("text")  
      .attr("class", "title")
      .attr("x",  margin.left + w/2)
      .attr("y", 20)
      .attr("text-anchor", "middle")
      .text(title)

    vis = svg.append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

    vis.append("rect")
      .attr("class", "background")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", w)
      .attr("height", h)

    vis.append("g")
      .attr("class", "y axis")
      .call(yAxis)

    vis.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + h + ")")
      .call(xAxis)

    ruleLine = vis.append("line")
      .attr("visibility", "hidden")
      .attr("class", "rule")
      .attr("y1", -3)
      .attr("y2", h + 6)

    ###
    updateYear = ->
      vis.selectAll("line.rule")
        .attr("x1", x(data[state.selAttrIndex][dateProp]))
        .attr("x2", x(data[state.selAttrIndex][dateProp]))

    updateYear()
    $(ruleLine[0]).bind("updateYear", updateYear)
    ###

    #enter(data)
    update(data, 0)

    foreground = vis.append("rect")
      .attr("class", "foreground")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", w)
      .attr("height", h + margin.bottom)
      .on("mouseover", -> fire "mouseover", svg)
      .on("click", -> fire "click", svg)
      .on("mouseout", -> 
        fire("mouseout", svg)
        if showRule
          chart.moveRule(null)
      )


    if showRule
      foreground.on "mousemove", ->
        #r = outerDiv.select(".range")[0][0]
        # the handle must be in the middle of the mouse cursor => +3
        date = x.invert(d3.mouse(foreground[0][0])[0] + 3)
        chart.moveRule(date)  

      


  
  chart


