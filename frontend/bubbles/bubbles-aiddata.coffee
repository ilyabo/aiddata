bubblesChartWidth = $(document).width()*0.95
bubblesChartHeight = $(document).height()*0.8

svg = d3.select("body")
  .append("svg")
    .attr("width", bubblesChartWidth)
    .attr("height", bubblesChartHeight)
    .attr("class", "bubbles")


conf = 
  code:"code"
  lat:"Lat"
  lon:"Lon"
  flowOriginAttr: 'donor'
  flowDestAttr: 'recipient'
  nodeIdAttr: 'code'
  nodeLabelAttr: 'name'
  latAttr: 'Lat'
  lonAttr: 'Lon'
  flowMagnAttrs:
    aid:
      attrs: [1947..2011]
      explain: 'In #attr# there were #magnitude# ... from #origin# in #dest#'

state = 
  selMagnAttrGrp: "aid"
  selAttrIndex: 64



mapProj = winkelTripel()
mapProjPath = d3.geo.path().projection(mapProj)


projectNode = (node) ->  
  lon = node[conf.lonAttr]
  lat = node[conf.latAttr]
  if (isNumber(lon) and isNumber(lat))
    mapProj([lon, lat])
  else
    undefined



loadData()
  .csv('nodes', "#{dynamicDataPath}aiddata-nodes.csv")
  .csv('flows', "#{dynamicDataPath}aiddata-totals-d-r-y.csv")
  #.csv('originTotals', "#{dynamicDataPath}aiddata-donor-totals.csv")
  #.csv('destTotals', "#{dynamicDataPath}aiddata-recipient-totals.csv")
  .json('map', "data/world-countries.json")
  .csv('countries', "data/aiddata-countries.csv")
  .onload (data) ->

    fitProjection(mapProj, data.map, [[0,0],[bubblesChartWidth, bubblesChartHeight]], true)


    provideNodesWithTotals(data, conf)
    provideCountryNodesWithCoords(
      data.nodes, conf,
      data.countries, { code: "Code", lat: "Lat", lon: "Lon" }
    )


    state.totalsMax = calcMaxTotalMagnitudes(data, conf)


    max = state.totalsMax[state.selMagnAttrGrp]
    rscale = d3.scale.sqrt()
      .range([0, 50])
      .domain([0, Math.max(d3.max(max.inbound), d3.max(max.outbound))])


    hasFlows = (node, flowDirection) -> 
      totals = node.totals?[state.selMagnAttrGrp]?[flowDirection]
      (if totals? then d3.max(totals) > 0 else 0)

    nodesWithFlows = data.nodes.filter(
      (node) -> hasFlows(node, "inbound") or hasFlows(node, "outbound")
    )

    nodesWithLocation = nodesWithFlows.filter (node) -> projectNode(node)?


    bubbles = svg.selectAll("g.bubble")
        .data(nodesWithLocation)
      .enter()
        .append("g")
          .attr("class", "bubble")

    bubbles.append("circle")
      .attr("cx", (d) -> projectNode(d)[0])
      .attr("cy", (d) -> projectNode(d)[1])
      .attr("r", (d) -> rscale(d.totals[state.selMagnAttrGrp].inbound?[state.selAttrIndex] ? 0))
      .attr("fill", "#f00")







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