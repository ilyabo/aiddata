this.timeSeries = ->

  title = ""
  width = 300
  height = 200

  x = tg = null

  # data is expected to be in the following form:
  # [{date:new Date(1978, 0), inbound:123, outbound:321}, ...]

  chart = (selection) ->
    data = selection.datum()

    margin = {top: 28, right: 8, bottom: 14, left: 46}

    w = width - margin.left - margin.right
    h = height - margin.top - margin.bottom

    hasIn = data[0]?.inbound?
    hasOut = data[0]?.outbound?

    dates = data.map (d) -> d.date
    maxVal = d3.max(d3.values(data.map (d) -> Math.max(d.inbound ? 0, d.outbound ? 0)))
    x = d3.time.scale().domain([d3.min(dates), d3.max(dates)]).range([0, w])          
    y = d3.scale.linear().domain([0, maxVal]).range([h, 0])

    xAxis = d3.svg.axis()
      .scale(x)
      .ticks(Math.max(1, Math.round(w/30)))
      .orient("bottom")
      .tickSize(3, 0, 0)

    yAxis = d3.svg.axis()
      .ticks(Math.max(1, Math.round(h/18)))
      .scale(y)
      .orient("left")
      .tickFormat(shortMagnitudeFormat)
      .tickSize(-w, 0, 0)

    tsvg = selection
      .append("svg")
        .datum(data)
        .attr("width", w + margin.left + margin.right)
        .attr("height", h + margin.top + margin.bottom)
    
    tsvg.append("text")  
      .attr("class", "title")
      .attr("x",  margin.left + w/2)
      .attr("y", 20)
      .attr("text-anchor", "middle")
      .text(title)

    tg = tsvg.append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

    tg.append("rect")
      .attr("class", "background")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", w)
      .attr("height", h)

    tg.append("g")
      .attr("class", "y axis")
      .call(yAxis)

    tg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + h + ")")
      .call(xAxis)

    selDateLine = tg.append("line")
      .attr("class", "selDate")
      .attr("y1", -3)
      .attr("y2", h + 6)

    ###
    updateYear = ->
      tg.selectAll("line.selDate")
        .attr("x1", x(data[state.selAttrIndex].date))
        .attr("x2", x(data[state.selAttrIndex].date))

    updateYear()
    $(selDateLine[0]).bind("updateYear", updateYear)
    ###


    if hasIn
      linein = d3.svg.line()
        .x((d) -> x(d.date))
        .y((d) -> y(d.inbound))
      
      gin = tg.append("g").attr("class", "in")

      gin.append("path")
        .attr("class", "line")
        .attr("d", linein)

      ###
      gin.append("circle")
        .attr("class","selAttrValue")
        .attr("cx", x(data[state.selAttrIndex].date))
        .attr("cy", y(data[state.selAttrIndex].inbound))
        .attr("r", 2)
      ###


    if hasOut
      lineout = d3.svg.line()
        .x((d) -> x(d.date))
        .y((d) -> y(d.outbound))
      
      gout = tg.append("g").attr("class", "out")

      gout.append("path")
        .attr("class", "line")
        .attr("d", lineout)

      ###
      gout.append("circle")
        .attr("class","selAttrValue")
        .attr("cx", x(data[state.selAttrIndex].date))
        .attr("cy", y(data[state.selAttrIndex].outbound))
        .attr("r", 2)
      ###

    tg.append("rect")
      .attr("class", "foreground")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", w)
      .attr("height", h + margin.bottom)

    ###
    .on 'mousemove', (d) ->
      selection.setSelDateTo(x.invert(d3.mouse(this)[0]), true)
    ###





  chart.width = (_) -> if (!arguments.length) then width else width = _; chart

  chart.height = (_) -> if (!arguments.length) then height else height = _; chart

  chart.title = (_) -> if (!arguments.length) then title else title = _; chart

  chart.selectDate = (date) ->
    tg.selectAll("line.selDate")
      .attr("x1", x(date))
      .attr("x2", x(date))



  chart
