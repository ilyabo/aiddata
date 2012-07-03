crossfilter.barChart = ->

  barChart = crossfilter.barChart
  barChart.id = 0  unless barChart.id
  margin =
    top: 10
    right: 10
    bottom: 20
    left: 10

  x = undefined
  y = d3.scale.linear().range([ 100, 0 ])
  id = barChart.id++
  axis = d3.svg.axis().orient("bottom")
  brush = d3.svg.brush()
  brushDirty = undefined
  dimension = undefined
  group = undefined
  round = undefined



  chart = (div) ->

    width = x.range()[1]
    height = y.range()[0]
    y.domain [ 0, group.top(1)[0].value ]



    barPath = (groups) ->
      path = []
      i = -1
      n = groups.length
      d = undefined
      while ++i < n
        d = groups[i]
        path.push "M", x(d.key), ",", height, "V", y(d.value), "h9V", height
      path.join ""

    resizePath = (d) ->
      e = +(d is "e")
      cx = (if e then 1 else -1)
      cy = height / 3
      "M" + (.5 * cx) + "," + cy +
      "A6,6 0 0 " + e + " " + (6.5 * cx) + "," + (cy + 6) +
      "V" + (2 * cy - 6) +
      "A6,6 0 0 " + e + " " + (.5 * cx) + "," + (2 * cy) +
      "Z" +
      "M" + (2.5 * cx) + "," + (cy + 8) +
      "V" + (2 * cy - 8) +
      "M" + (4.5 * cx) + "," + (cy + 8) +
      "V" + (2 * cy - 8)

    
    div.each ->
      div = d3.select(this)
      g = div.select("g")

      # Create the skeletal chart.
      if g.empty()
        div.select(".title").append("a")
            .attr("href", "javascript:reset(" + id + ")")
            .attr("class", "reset")
            .text("reset")
            .style("display", "none");

        g = div.append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
          .append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

        g.append("clipPath")
            .attr("id", "clip-" + id)
          .append("rect")
            .attr("width", width)
            .attr("height", height);

        g.selectAll(".bar")
            .data(["background", "foreground"])
          .enter().append("path")
            .attr("class", (d) -> d + " bar")
            .datum(group.all());

        g.selectAll(".foreground.bar")
            .attr("clip-path", "url(#clip-" + id + ")")

        g.append("g")
            .attr("class", "axis")
            .attr("transform", "translate(0," + height + ")")
            .call(axis)


        # Initialize the brush component with pretty resize handles.
        gBrush = g.append("g").attr("class", "brush").call(brush)
        gBrush.selectAll("rect").attr "height", height
        gBrush.selectAll(".resize").append("path").attr "d", resizePath


      # Only redraw the brush if set externally.
      if brushDirty
        brushDirty = false
        g.selectAll(".brush").call brush
        div.select(".title a").style "display", (if brush.empty() then "none" else null)
        if brush.empty()
          g.selectAll("#clip-" + id + " rect")
              .attr("x", 0)
              .attr("width", width)
        else
          extent = brush.extent()
          g.selectAll("#clip-" + id + " rect")
              .attr("x", x(extent[0]))
              .attr("width", x(extent[1]) - x(extent[0]))

      g.selectAll(".bar").attr "d", barPath




  brush.on "brushstart.chart", ->
    div = d3.select(@parentNode.parentNode.parentNode)
    div.select(".title a").style "display", null

  brush.on "brush.chart", ->
    g = d3.select(@parentNode)
    extent = brush.extent()

    if (round)
      g.select(".brush")
        .call(brush.extent(extent = extent.map(round)))
      .selectAll(".resize")
        .style("display", null)

    g.select("#clip-" + id + " rect")
        .attr("x", x(extent[0]))
        .attr("width", x(extent[1]) - x(extent[0]))

    dimension.filterRange extent

  brush.on "brushend.chart", ->
    if brush.empty()
      div = d3.select(@parentNode.parentNode.parentNode)
      div.select(".title a").style "display", "none"
      div.select("#clip-" + id + " rect").attr("x", null).attr "width", "100%"
      dimension.filterAll()

  chart.margin = (_) ->
    return margin  unless arguments.length
    margin = _
    chart

  chart.x = (_) ->
    return x  unless arguments.length
    x = _
    axis.scale x
    brush.x x
    chart

  chart.y = (_) ->
    return y  unless arguments.length
    y = _
    chart

  chart.dimension = (_) ->
    return dimension  unless arguments.length
    dimension = _
    chart

  chart.filter = (_) ->
    if _
      brush.extent _
      dimension.filterRange _
    else
      brush.clear()
      dimension.filterAll()
    brushDirty = true
    chart

  chart.group = (_) ->
    return group  unless arguments.length
    group = _
    chart

  chart.round = (_) ->
    return round  unless arguments.length
    round = _
    chart

  d3.rebind chart, brush, "on"