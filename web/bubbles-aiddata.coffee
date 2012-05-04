loadData()
  .csv('nodes', "#{dynamicDataPath}aiddata-nodes.csv")
  .csv('flows', "#{dynamicDataPath}aiddata-totals-d-r-y.csv")
  #.csv('originTotals', "#{dynamicDataPath}aiddata-donor-totals.csv")
  #.csv('destTotals', "#{dynamicDataPath}aiddata-recipient-totals.csv")
  #.json('map', "data/world-countries.json")
  .csv('countries', "data/aiddata-countries.csv")
  .onload (data) ->


    svg = selection.append("svg")
          .attr("width", ffprintsChartWidth)
          .attr("height", ffprintsChartHeight)
          .attr("class", "ffprints")

    
    countriesByCode = {}
    for c in data.countries
      countriesByCode[c.Code] = c

    for node in data.nodes
      c = countriesByCode[node.code]
      if c?
        node.Lat = c.Lat
        node.Lon = c.Lon




###
color = d3.scale.linear()
    .domain([d3.min(data), d3.max(data)])
    .range(["#aad", "#556"]) 

force = d3.layout.force()
    .charge(0)
    .gravity(0)
    .size([960, 500])

svg = d3.select("#chart").append("svg")
    .attr("width", 960 + 100)
    .attr("height", 500 + 100)
  .append("g")
    .attr("transform", "translate(50,50)")

d3.json "../data/us-state-centroids.json", (states) ->
  project = d3.geo.albersUsa()
  idToNode = {}
  links = []

  nodes = states.features.map (d) ->
    xy = project(d.geometry.coordinates)
    return idToNode[d.id] = {
      x: xy[0],
      y: xy[1],
      gravity: {x: xy[0], y: xy[1]},
      r: Math.sqrt(data[+d.id] * 5000),
      value: data[+d.id]
    }
  


  force
      .nodes(nodes)
      .links(links)
      .start()
      .on("tick", (e) -> 
        
        k = e.alpha
        kg = k * .02


        nodes.forEach((a, i) -> {
          // Apply gravity forces.
          a.x += (a.gravity.x - a.x) * kg
          a.y += (a.gravity.y - a.y) * kg
          nodes.slice(i + 1).forEach((b) -> {
            // Check for collisions.
            dx = a.x - b.x,
                dy = a.y - b.y,
                l = Math.sqrt(dx * dx + dy * dy),
                d = a.r + b.r
            if (l < d) {
              l = (l - d) / l * k
              dx *= l
              dy *= l
              a.x -= dx
              a.y -= dy
              b.x += dx
              b.y += dy
            }
          })
        })

        svg.selectAll("circle")
            .attr("cx", (d) ->  { return d.x })
            .attr("cy", (d) ->  { return d.y })

  svg.selectAll("circle")
      .data(nodes)
    .enter().append("circle")
      .style("fill", (d) ->  { return color(d.value) })
      .attr("cx", (d) ->  { return d.x })
      .attr("cy", (d) ->  { return d.y })
      .attr("r", (d, i) -> { return d.r })
###