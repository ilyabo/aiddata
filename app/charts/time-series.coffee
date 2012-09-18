this.timeSeriesChart = ->

  title = ""
  width = 300
  height = 200
  dateProp = "date"
  interpolate = null #"monotone"
  showDots = true
  dotRadius = 2
  xticks = yticks = null
  marginLeft = 40
  ytickFormat = d3.format(",.0f")
  maxPropertyClasses = 9
  showLegend = false
  legendWidth = 150
  legendHeight = null  # will be set to height by default
  legendItemHeight = 15
  legendItemWidth = 80
  legendMarginLeft = 20
  legendMarginTop = 0
  properties = null
  showRule = false
  ruleDate = null
  eventListeners = {}

  # borrowed from chroma.js: chroma.brewer.Set1
  propColors = ["#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00", "#ffff33", "#a65628", "#f781bf", "#999999"]
  # Set3 (more pastel colors):
  #  ["#8dd3c7", "#ffffb3", "#bebada", "#fb8072", "#80b1d3", "#fdb462", "#b3de69", "#fccde5", "#d9d9d9", "#bc80bd", "#ccebc5", "#ffed6f"]


  # data is expected to be in the following form:
  # [{date:new Date(1978, 0), inbound:123, outbound:321}, ...]

  chart = (selection) -> init(selection)

  chart.title = (_) -> if (!arguments.length) then title else title = _; chart

  # which properties to visualize
  chart.properties = (_) -> if (!arguments.length) then properties else properties = _; chart

  chart.width = (_) -> if (!arguments.length) then width else width = _; chart

  chart.showDots = (_) -> if (!arguments.length) then showDots else showDots = _; chart

  chart.dotRadius = (_) -> if (!arguments.length) then dotRadius else dotRadius = _; chart

  chart.xticks = (_) -> if (!arguments.length) then xticks else xticks = _; chart

  chart.yticks = (_) -> if (!arguments.length) then yticks else yticks = _; chart

  chart.height = (_) -> if (!arguments.length) then height else height = _; chart

  chart.marginLeft = (_) -> if (!arguments.length) then marginLeft else marginLeft = _; chart

  chart.dateProp = (_) -> if (!arguments.length) then dateProp else dateProp = _; chart

  chart.interpolate = (_) -> if (!arguments.length) then interpolate else interpolate = _; chart

  chart.ytickFormat = (_) -> if (!arguments.length) then ytickFormat else ytickFormat = _; chart

  chart.showLegend = (_) -> if (!arguments.length) then showLegend else showLegend = _; chart

  chart.legendWidth = (_) -> if (!arguments.length) then legendWidth else legendWidth = _; chart

  chart.legendHeight = (_) -> if (!arguments.length) then legendHeight else legendHeight = _; chart

  chart.showRule = (_) -> if (!arguments.length) then showRule else showRule = _; chart

  chart.propColors = (_) -> if (!arguments.length) then propColors else propColors = _; chart

  chart.on = (event, listener) -> (eventListeners[event] ?= []).push(listener); chart

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

      listeners = eventListeners["rulemove"]
      if listeners?
        l(date) for l in listeners




  chart.update = (selection) ->
    # vis.selectAll("path.line").remove()
    # vis.selectAll("circle.dot").remove()

    vis.selectAll("g.prop").remove()
    vis.selectAll("g.legend").remove()

    data = selection.datum()
    vis.datum(data)
    updateScaleDomains(data)

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
    #vis.datum(data)

    dates = data.map (d) -> d[dateProp]

    nested = d3.nest()
      .key((d) -> d[dateProp])
      .rollup((a) -> a[0])  # assuming unique values for each date
      .map(data)

    props = properties ? propsOf data

    for prop, pi in props
      line = lineDrawer(prop)


      g = vis.append("g")
        .attr("class", "prop #{prop}")

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
        dots = g.selectAll("circle.dot")
          .data dates.filter (d) -> (not isNaN(y(nested[d]?[prop])))

        #console.log dots

        dots.enter().append("circle")
          .attr("class", "dot")
          .attr("r", dotRadius)
          .attr("stroke", propColors[pi % propColors.length])

        dots
          .attr("cx", (d) -> x(d))
          .attr("cy", (d) -> y(nested[d][prop]))

        dots.exit().remove()



    if showLegend

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
        .attr("width", 8)
        .attr("height", 8)
        .attr("fill", (d, pi) -> propColors[pi % propColors.length])

      item.append("text")
        .attr("x", 13)
        .attr("y", 4)
        .text((d, i) -> props[i])
        




  updateDuration = 1300

  x = y = null  # scales
  xAxis = yAxis = null
  svg = vis = null

  isNumber = (obj) -> (obj is +obj) or toString.call(obj) is '[object Number]'

  # list of properties of the data
  propsOf = (data) -> 
    props = {}
    for d in data
      for prop, val of d when ((prop isnt dateProp) and not(prop of props))
        props[prop] = true
    d3.keys(props)

    #(prop for prop, val of data[0] when prop isnt dateProp)


  updateScaleDomains = (data) ->
    maxVal = d3.max(
      propsOf(data).map(
        (prop) ->
          d3.max( data.map((d) -> d[prop]).filter(isNumber) )
      )
      .filter(isNumber)
    )
    y.domain([0, maxVal])

    #maxVal = d3.max(d3.values(data.map (d) -> Math.max(d.inbound ? 0, d.outbound ? 0)))
    dates = data.map (d) -> d[dateProp]
    x.domain([d3.min(dates), d3.max(dates)])
    #console.log y.domain()


  lineDrawer = (prop) ->
    d3.svg.line()
      .x((d) -> x(d[dateProp]))
      .y((d) -> y(d[prop]))
      .defined((d) -> !isNaN(d[prop]))
      .interpolate(interpolate)


  init = (selection) -> 

    if svg?
      chart.update(selection)
      return

    data = selection.datum()

    props = properties ? propsOf(data)

    margin = {top: 28, right: 8, bottom: 14, left: marginLeft}

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

    svg = selection
      .append("svg")
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

    if showRule
      foreground.on "mousemove", ->
        #r = outerDiv.select(".range")[0][0]
        # the handle must be in the middle of the mouse cursor => +3
        date = x.invert(d3.mouse(foreground[0][0])[0] + 3)
        chart.moveRule(date)  

      foreground.on "mouseout", ->
        chart.moveRule(null)


  
  chart


