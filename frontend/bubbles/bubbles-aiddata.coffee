bubblesChartWidth = $(document).width()*0.95
bubblesChartHeight = $(document).height()*0.9 - 50

svg = d3.select("body")
  .append("svg")
    .attr("width", bubblesChartWidth)
    .attr("height", bubblesChartHeight)
    .attr("class", "bubbles")


conf = 
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

state = null




fmt = d3.format(",.0f")
bubbleTooltip = (d) ->
  format = (d) ->
    if (d >= 1e6)
      "$#{fmt(d / 1e6)} million"
    else
      "$#{fmt(d)}" 

  "<b>#{d.name}</b>" + 
  " in <b>#{state.selMagnAttr()}</b>" +
  (if d.outbound > 0 then "<br>donated #{format(d.outbound)}" else "") +
  (if d.inbound > 0 then "<br>received #{format(d.inbound)}" else "") 


mapProj = winkelTripel()
mapProjPath = d3.geo.path().projection(mapProj)


projectNode = (node) ->  
  lon = node[conf.lonAttr]
  lat = node[conf.latAttr]
  if (isNumber(lon) and isNumber(lat))
    mapProj([lon, lat])
  else
    undefined


force = d3.layout.force()
    .charge(0)
    .gravity(0)
    .size([bubblesChartWidth, bubblesChartHeight])

idToNode = {}


loadData()
  .csv('nodes', "#{dynamicDataPath}aiddata-nodes.csv")
  .csv('flows', "#{dynamicDataPath}aiddata-totals-d-r-y.csv")
  #.csv('originTotals', "#{dynamicDataPath}aiddata-donor-totals.csv")
  #.csv('destTotals', "#{dynamicDataPath}aiddata-recipient-totals.csv")
  .json('map', "data/world-countries.json")
  .csv('countries', "data/aiddata-countries.csv")
  .onload (data) ->

    fitProjection(mapProj, data.map, [[0,50],[bubblesChartWidth, bubblesChartHeight*0.6]], true)

    state = initFlowData(conf)
    state.selMagnAttrGrp = "aid"
    state.selAttrIndex = state.magnAttrs().length - 1



    provideNodesWithTotals(data, conf)
    provideCountryNodesWithCoords(
      data.nodes, { code: conf.nodeIdAttr, lat: conf.latAttr, lon: conf.lonAttr},
      data.countries, { code: "Code", lat: "Lat", lon: "Lon" }
    )


    state.totalsMax = calcMaxTotalMagnitudes(data, conf)


    max = state.totalsMax[state.selMagnAttrGrp]
    rscale = d3.scale.sqrt()
      .range([0, Math.min(bubblesChartWidth/10, bubblesChartHeight/5)])
      .domain([0, Math.max(d3.max(max.inbound), d3.max(max.outbound))])


    hasFlows = (node, flowDirection) -> 
      totals = node.totals?[state.selMagnAttrGrp]?[flowDirection]
      (if totals? then d3.max(totals) > 0 else 0)

    nodesWithFlows = data.nodes.filter(
      (node) -> hasFlows(node, "inbound") or hasFlows(node, "outbound")
    )

    #nodesWithLocation = nodesWithFlows.filter (node) -> projectNode(node)?

    #nodesWithoutLocationX = 0

    nodes = nodesWithFlows.map (d) ->
      xy = projectNode(d)

      idToNode[d[conf.nodeIdAttr]] =
        data : d
        name: d[conf.nodeLabelAttr] 
        code: d[conf.nodeIdAttr]
        x: xy?[0]
        y: xy?[1]
        gravity: {x: xy?[0], y: xy?[1]}

    updateNodeSizes = ->
      for n in nodes
        d = n.data
        n.inbound = d.totals[state.selMagnAttrGrp].inbound?[state.selAttrIndex] ? 0
        n.outbound = d.totals[state.selMagnAttrGrp].outbound?[state.selAttrIndex] ? 0
        n.rin = rscale(n.inbound)
        n.rout = rscale(n.outbound)
        n.r = Math.max(n.rin, n.rout)


    updateNodeSizes()

    placeNodesWithoutCoords = (nodes) ->
      totalw = 0
      for n in nodes
        if not n.x? or not n.y? then totalw += 2 * n.r
      x = 0
      for n in nodes
        if not n.x? or not n.y?
          n.x = x + n.r + (bubblesChartWidth - totalw)/2
          n.y = bubblesChartHeight - 100
          n.gravity = {x: n.x, y: n.y}
          x += 2 * n.r

    placeNodesWithoutCoords(nodes)


    force
        .nodes(nodes)
        #.links(links)
        .start()
        .on("tick", (e) -> 
          
          k = e.alpha
          kg = k * .02


          nodes.forEach((a, i) ->
            # Apply gravity forces
            a.x += (a.gravity.x - a.x) * kg
            a.y += (a.gravity.y - a.y) * kg
            nodes.slice(i + 1).forEach((b) -> 
              # Check for collisions.
              dx = a.x - b.x
              dy = a.y - b.y
              l = Math.sqrt(dx * dx + dy * dy)
              d = a.r + b.r
              if (l < d)
                l = (l - d) / l * k
                dx *= l
                dy *= l
                a.x -= dx
                a.y -= dy
                b.x += dx
                b.y += dy
            )
          )

          svg.selectAll("g.bubble")
            .attr("transform", (d) -> "translate(#{d.x},#{d.y})")
    )
    svg.append("g")
      .attr("class", "map")
      .selectAll('path')
        .data(data.map.features)
      .enter().append('path')
        .attr('d', mapProjPath)
        .attr("fill", "#f0f0f0")



    bubbles = svg.selectAll("g.bubble")
        .data(nodes)
      .enter()
        .append("g")
          .attr("class", "bubble")

    bubbles.append("circle")
      .attr("class", "rin")
      .attr("opacity", 0.5)
      .attr("fill", "#f00")
      .attr("stroke", "#ccc")

    bubbles.append("circle")
      .attr("class", "rout")
      .attr("opacity", 0.5)
      .attr("fill", "#00f")
      .attr("stroke", "#ccc")


    bubbles.append("text")
      .attr("class", "nodeLabel")
      .attr("y", 5)
      .attr("font-size", 9)
      .attr("text-anchor", "middle")
      .text((d)-> if d.code.length < 7 then d.code else d.code.substring(0,5)+".." )




    svg.append("text")
      .attr("id", "yearText")
      .attr("x", 20)
      .attr("y", bubblesChartHeight - 60)
        .text(state.selMagnAttr())

    updateYear = (e, ui, noAnim) ->
      unless state.selAttrIndex == ui.value
        state.selAttrIndex = ui.value
        update(noAnim)

    update = (noAnim) ->
      updateNodeSizes()
      duration = if noAnim then 0 else 

      svg.selectAll("#yearText")
        .text(state.selMagnAttr())

      bubbles.selectAll("circle.rin")
        .transition()
        .duration(duration)
        .attr("r", (d) -> d.rin)
      
      bubbles.selectAll("circle.rout")
        .transition()
        .duration(duration)
        .attr("r", (d) -> d.rout)

      bubbles.selectAll("text.nodeLabel")
        .attr("visibility", (d) -> if d.r > 10 then "visible" else "hidden")

      force.start()

    update()


    $("#yearSlider")
      .slider
        min: 0
        max: state.magnAttrs().length - 1
        value: state.magnAttrs().length - 1
        slide: (e, ui) -> updateYear(e, ui, true)
        change: (e, ui) -> updateYear(e, ui, false)

    #$("#playButton").button()

    $('g.bubble').tipsy
      gravity: 'w'
      html: true
      title: ->
        bubbleTooltip(d3.select(this).data()[0])


