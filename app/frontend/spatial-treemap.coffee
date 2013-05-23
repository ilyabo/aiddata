this.spatialTreemap = ->

  width = 500
  height = 500
  margin = { top:10, right:0, bottom:0, left:10 }

  chart = (selection) -> init(selection)

  chart.width = (_) -> if (!arguments.length) then width else width = _; chart
  chart.height = (_) -> if (!arguments.length) then height else height = _; chart


  init = (selection) -> 

    data = selection.datum()

    w = width - margin.left - margin.right
    h = height - margin.top - margin.bottom


    svg = selection.append("svg")
      .attr("width", width)
      .attr("height", height)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")")


    g = svg.selectAll("g.node").data(data)

    genter = g.enter()
      .append("g")
        .attr("transform", (d) -> "translate(#{d.Lon},#{d.Lat})")

    genter.append("rect")
      .attr("x", 0)
      .attr("x", 0)
      .attr("width", 20)
      .attr("height", 10)
      .attr("stroke", "black")


    console.log data



  chart
