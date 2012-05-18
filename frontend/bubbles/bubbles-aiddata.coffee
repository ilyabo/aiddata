bubblesChartWidth = $(document).width() * 0.95
bubblesChartHeight = $(document).height() - 200
nodesWithoutCoordsMarginBottom = 90


yearTicksWidth = bubblesChartWidth * 0.6
yearTicksLeft = yearTicksRight = 10
playButtonWidth = 40

lightVersionMode = $.browser.mozilla
if lightVersionMode
  dontUseForceLayout = true
  noAnimation = true
  flowMagnitudeThreshold = 1000*1e6-1
else
  dontUseForceLayout = false
  noAnimation = false
  flowMagnitudeThreshold = 0




svg = d3.select("#bubblesChart")
  .append("svg")
    .attr("width", bubblesChartWidth)
    .attr("height", bubblesChartHeight)
    .attr("class", "bubble")


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
stopAnimation = null



fmt = d3.format(",.0f")
magnitudeFormat = (d) ->
  if (d >= 1e6)
    "$#{fmt(d / 1e6)} million"
  else
    "$#{fmt(d)}" 

shortMagnitudeFormat = (d) -> magnitudeFormat(d).replace(" million", "M")

bubbleTooltip = (d) ->
  "<b>#{d[conf.nodeLabelAttr]}</b>" + 
  " in <b>#{state.selMagnAttr()}</b>" +
  (if d.outbound > 0 then "<br>donated #{magnitudeFormat(d.outbound)}" else "") +
  (if d.inbound > 0 then "<br>received #{magnitudeFormat(d.inbound)}" else "") 
  #"<div id=tseries></div>"


flowTooltip = (d) ->
  recipient = d.target.data[conf.nodeLabelAttr]
  donor = d.source.data[conf.nodeLabelAttr]

  "<b>#{recipient}</b> received<br>"+
  "<b>#{magnitudeFormat(d.data[state.selMagnAttr()])}</b> "+
  (if donor.length > 20 then "<span class=sm>from <b>#{donor}</b></span>" else "from <b>#{donor}</b>") +
  "  in #{state.selMagnAttr()} <br>"
  #"<div id=tseries></div>"



mapProj = winkelTripel()
mapProjPath = d3.geo.path().projection(mapProj)


dateFromMagnAttr = (magnAttr) -> new Date(magnAttr, 0)



createYearTicks = ->

  dates = state.magnAttrs().map (attr) -> dateFromMagnAttr(attr)

  x = d3.time.scale().domain([d3.min(dates), d3.max(dates)]).range([0, yearTicksWidth])          

  ticksSvg = d3.select("#yearTicks")
    .append("svg")
      .attr("width", yearTicksWidth + yearTicksLeft + yearTicksRight)
      .attr("height", 50)
    .append("g")
      .attr("transform", "translate(#{yearTicksLeft})")

  ###
  ticksSvg.append("rect")
    .attr("fill", "#eee")
    .attr("x", 0)
    .attr("y", 0)
    .attr("width", yearTicksWidth)
    .attr("height", 50)
  ###

  xAxis = d3.svg.axis()
    .scale(x)
    .ticks(12)
    .orient("bottom")
    .tickSize(8, 4, 0)
    .tickSubdivide(4)


  ticksSvg.append("g")
    .attr("class", "x axis")
    .call(xAxis)


  $("#yearSlider")
    .css("width", yearTicksWidth)
    .css("margin-left", yearTicksLeft)


  $("#yearSliderInner")
    .css("width", yearTicksWidth + yearTicksLeft + yearTicksRight)

  $("#yearSliderOuter")
    .css("width", yearTicksWidth + yearTicksLeft + yearTicksRight + playButtonWidth)
    .show()

  $("g.x.axis text").click ->
    stopAnimation()
    $("#yearSlider").slider('value', state.magnAttrs().indexOf( + $(this).text()))

  $("#play").hover(
    () -> $(this).addClass('ui-state-hover')
    ,
    () -> $(this).removeClass('ui-state-hover')
  )
  

shortenLabel = (labelText, maxLength) ->
  if labelText.length < maxLength
    labelText
  else
    labelText.substr(0, maxLength - 2) + ".."


# data is expected to be in the following form:
# [{date:new Date(1978, 0), inbound:123, outbound:321}, ...]
createTimeSeries = (parent, data, title) ->
  margin = {top: 28, right: 8, bottom: 14, left: 46}
  w = 250 - margin.left - margin.right
  h = 120 - margin.top - margin.bottom

  hasIn = data[0]?.inbound?
  hasOut = data[0]?.outbound?

  dates = data.map (d) -> d.date
  maxVal = d3.max(d3.values(data.map (d) -> Math.max(d.inbound ? 0, d.outbound ? 0)))
  x = d3.time.scale().domain([d3.min(dates), d3.max(dates)]).range([0, w])          
  y = d3.scale.linear().domain([0, maxVal]).range([h, 0])

  xAxis = d3.svg.axis()
    .scale(x)
    .ticks(5)
    .orient("bottom")
    .tickSize(3, 0, 0)

  yAxis = d3.svg.axis()
    .ticks(4)
    .scale(y)
    .orient("left")
    .tickFormat(shortMagnitudeFormat)
    .tickSize(-w, 0, 0)

  tsvg = parent
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

  tseries = tsvg.append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

  tseries.append("rect")
    .attr("class", "background")
    .attr("x", 0)
    .attr("y", 0)
    .attr("width", w)
    .attr("height", h)

  tseries.append("g")
    .attr("class", "y axis")
    .call(yAxis)

  tseries.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + h + ")")
    .call(xAxis)


  if hasIn
    linein = d3.svg.line()
      .x((d) -> x(d.date))
      .y((d) -> y(d.inbound))
    
    gin = tseries.append("g").attr("class", "in")

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
    
    gout = tseries.append("g").attr("class", "out")

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


TimeSeries = 
  id: (type, i) -> 'tseries'+ type + i

  exists: (type, i) -> $("#" + TimeSeries.id(type, i)).length > 0

  create: (type, i) ->
    id = TimeSeries.id(type, i)
    $("#tseriesPanel").append('<div id="'+id+'" class="tseries"></div>')
    return $("#"+id).get(0)

  remove: (type, i) -> $("#"+TimeSeries.id(type, i)).remove()

  removeAllExcept: (type, i) ->  $("#tseriesPanel .tseries").not("#" + TimeSeries.id(type, i)).remove()



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


    provideNodesWithTotals(data, conf)
    provideCountryNodesWithCoords(
      data.nodes, { code: conf.nodeIdAttr, lat: conf.latAttr, lon: conf.lonAttr},
      data.countries, { code: "Code", lat: "Lat", lon: "Lon" }
    )

    state = initFlowData(conf)
    state.selMagnAttrGrp = "aid"
    state.selAttrIndex =  state.magnAttrs().length - 7  # state.magnAttrs().length - 1
    state.totalsMax = calcMaxTotalMagnitudes(data, conf)


    maxTotalMagnitudes = state.totalsMax[state.selMagnAttrGrp]
    maxTotalMagnitude = Math.max(d3.max(maxTotalMagnitudes.inbound), d3.max(maxTotalMagnitudes.outbound))

    rscale = d3.scale.sqrt()
      .range([0, Math.min(bubblesChartWidth/20, bubblesChartHeight/10)])
      .domain([0, maxTotalMagnitude])
    maxr = rscale.range()[1]

    fwscale = d3.scale.sqrt() #.linear()
      .range([0,  maxr *2])
      .domain([0, maxTotalMagnitude])

    #timescale = d3.time.scale().domain([d3.min(dates), d3.max(dates)]).range([0, w])          
  


    createYearTicks()

    svg.append("rect")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", bubblesChartWidth)
      .attr("height", bubblesChartHeight)
      .attr("fill", "white")
      .on 'click', (d) -> clearNodeSelection()


    fitProjection(mapProj, data.map, [[0,20],[bubblesChartWidth, bubblesChartHeight*0.8]], true)







    hasFlows = (node, flowDirection) -> 
      totals = node.totals?[state.selMagnAttrGrp]?[flowDirection]
      (if totals? then d3.max(totals) > flowMagnitudeThreshold else false)

    nodesWithFlows = data.nodes.filter(
      (node) -> hasFlows(node, "inbound") or hasFlows(node, "outbound")
    )

    #nodesWithLocation = nodesWithFlows.filter (node) -> projectNode(node)?

    #nodesWithoutLocationX = 0

    nodes = nodesWithFlows.map (d) ->
      xy = projectNode(d)

      maxin = d3.max(d.totals[state.selMagnAttrGrp].inbound ? [0])
      maxout = d3.max(d.totals[state.selMagnAttrGrp].outbound ? [0])

      idToNode[d[conf.nodeIdAttr]] =
        data : d
        max : Math.max(maxin, maxout)
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
        n.maxr = rscale(n.max)


    updateNodeSizes()

    placeNodesWithoutCoords = (nodes) ->
      squeezeFactor = 0.75
      totalw = 0
      for n in nodes
        if not n.x? or not n.y? then totalw += 2 * n.maxr * squeezeFactor
      x = 0
      for n in nodes
        if not n.x? or not n.y?
          n.x = x + n.maxr * squeezeFactor + (bubblesChartWidth - totalw)/2
          n.y = bubblesChartHeight - nodesWithoutCoordsMarginBottom
          n.gravity = {x: n.x, y: n.y}
          x += 2 * n.maxr * squeezeFactor

    placeNodesWithoutCoords(nodes)


    nodeById = (id) ->
      #if not idToNode[id]? then console.log "Warning: No node by id '#{id}' found"
      idToNode[id]

    links = []
    data.flows.forEach (f) ->
      src = nodeById(f[conf.flowOriginAttr])
      target = nodeById(f[conf.flowDestAttr])
      if src? and target?
        link = 
          source: src
          target: target
          data: f 
        
        (src.outlinks ?= []).push link
        (target.inlinks ?= []).push link
        links.push link

    v = (d) -> +d.data[state.selMagnAttr()]

    force
        .nodes(nodes)
        #.links(links)
        #.linkStrength(0)
        #.linkDistance(1)
        #.start()
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

          flows.selectAll("line")
            .attr("x1", (d) -> d.source.x )
            .attr("y1", (d) -> d.source.y )
            .attr("x2", (d) -> d.target.x )
            .attr("y2", (d) -> d.target.y )
    )


    svg.append("g")
      .attr("class", "map")
      .selectAll('path')
        .data(data.map.features)
      .enter().append('path')
        .attr('d', mapProjPath)
        .attr("fill", "#f0f0f0")
        .on 'click', (d) -> clearNodeSelection()

    flows = svg.append("g")
      .attr("class", "flows")



    selectedNode = null

    showFlowsOf = (bbl) ->
      d = d3.select(bbl).data()?[0]
      ###
      ffwscale = d3.scale.linear()
        .range([0, rscale.range()[1]/2])
        .domain([0, Math.max(d3.max(max.inbound), d3.max(max.outbound))])
      ###

      if (d.outlinks?)
        flows.selectAll("line.out")
            .data(d.outlinks) #.filter (d) -> v(d) > 0)
          .enter().append("svg:line")
            .attr("class", "out")
            #.attr("stroke", outboundColor)
            #.attr("opacity", 0.5)


      if (d.inlinks?)
        flows.selectAll("line.in")
            .data(d.inlinks) #.filter (d) -> v(d) > 0)
          .enter().append("svg:line")
            .attr("class", "in")
            #.attr("stroke", inboundColor)
            #.attr("opacity",0.5)

      createFlowTimeSeries = (flow, d, i) ->
        data = state.magnAttrs().map (attr) => 
            date: dateFromMagnAttr(attr)
            inbound: if d3.select(flow).classed("in") then +d.data[attr]
            outbound: if d3.select(flow).classed("out") then +d.data[attr]

        if not TimeSeries.exists("flow", i)
          tseries = TimeSeries.create("flow", i)
          recipient = d.target.data[conf.nodeLabelAttr]
          donor = d.source.data[conf.nodeLabelAttr]

          flowLabel = shortenLabel(donor, 20) + " -> " + shortenLabel(recipient, 20)
          createTimeSeries(d3.select(tseries), data, flowLabel)


      flows.selectAll("line")
        .attr("x1", (d) -> d.source.x)
        .attr("y1", (d) -> d.source.y)
        .attr("x2", (d) -> d.target.x)
        .attr("y2", (d) -> d.target.y)
        .attr("stroke-width", (d) -> fwscale(v(d)))
        .attr("visibility", (d) -> if v(d) > 0 then "visible" else "hidden")
        .on "mouseover", (d, i) ->
          if this.parentNode?
            this.parentNode.appendChild(this)

          $(this).tipsy("show")
          $("#tseriesPanel").add('<div id="tseries"></div>')

          createFlowTimeSeries(this, d, i)

          $(tipsy.$tip)
              .css('top', d3.event.pageY-($(tipsy.$tip).outerHeight()/2))
              .css('left', d3.event.pageX + 10)


        .on "mouseout", (d, i) ->
          $(this).tipsy("hide")
          TimeSeries.remove("flow", i)


      $('line').tipsy
        gravity: 'w'
        opacity: 0.9
        html: true
        trigger: "manual"
        title: ->
          flowTooltip(d3.select(this).data()[0])



    createNodeTimeSeries = (node, d, i) ->
      data = state.magnAttrs().map (attr, i) -> 
          date: dateFromMagnAttr(attr)
          inbound: d.data.totals[state.selMagnAttrGrp]?.inbound?[i] ? 0
          outbound: d.data.totals[state.selMagnAttrGrp]?.outbound?[i] ? 0

      if not TimeSeries.exists("node", i)
        tseries = TimeSeries.create("node", i)
        nodeLabel = d3.select(node).data()[0][conf.nodeLabelAttr]
        createTimeSeries(d3.select(tseries), data, shortenLabel(nodeLabel, 40))


    bubble = svg.selectAll("g.bubble")
        .data(nodes)
      .enter()
        .append("g")
          .attr("class", "bubble")
          .attr("transform", (d) -> "translate(#{d.x},#{d.y})")
          .on 'click', (d, i) ->

            if selectedNode == this
              TimeSeries.remove("node", i)
              selectedNode = null
              d3.select(this).selectAll("circle").classed("selected", false)
            else 
              if selectedNode != null
                TimeSeries.removeAllExcept("node", i)
                d3.select(selectedNode).selectAll("circle").classed("selected", false)
                flows.selectAll("line").remove()
              else
                createNodeTimeSeries(this, d, i)  
              selectedNode = this
              d3.select(this).selectAll("circle").classed("selected", true)
              showFlowsOf this


          .on 'mouseover', (d, i) ->
            d3.select(this).classed("highlighted", true)
            if selectedNode == null
              showFlowsOf this

            createNodeTimeSeries(this, d, i)

            $(this).tipsy("show")
            $(tipsy.$tip)  # fix vertical position
                .css('top', d3.event.pageY-($(tipsy.$tip).outerHeight()/2))



          .on 'mouseout', (d, i) ->
            d3.select(this).classed("highlighted", false)

            if selectedNode == null
              flows.selectAll("line").remove()

            if selectedNode != this
              TimeSeries.remove("node", i)
  
            $(this).tipsy("hide")


    clearNodeSelection = ->
      if selectedNode != null
        d3.select(selectedNode).selectAll("circle").classed("selected", false)
        flows.selectAll("line").remove()
        selectedNode = null

    $(document).keyup (e) -> if e.keyCode == 27 then clearNodeSelection()


    bubble.append("circle")
      .attr("class", "rin")
      #.attr("opacity", 0.5)
      #.attr("fill", "#f00")

    bubble.append("circle")
      .attr("class", "rout")
      #.attr("opacity", 0.5)
      #.attr("fill", "#00f")


    bubble.append("text")
      .attr("class", "nodeLabel")
      .attr("y", 5)
      .attr("font-size", 9)
      .attr("text-anchor", "middle")
      .text((d)-> if d.code.length < 7 then d.code else d.code.substring(0,5)+".." )




    svg.append("text")
      .attr("id", "yearText")
      .attr("font-size", bubblesChartWidth/15)
      .attr("x", bubblesChartWidth - 20)
      .attr("y", 100)
      .attr("text-anchor", "end")
        .text(state.selMagnAttr())

    updateYear = (e, ui, noAnim) ->
      unless state.selAttrIndex == ui.value
        state.selAttrIndex = ui.value
        update(noAnim)

    update = (noAnim) ->
      updateNodeSizes()
      duration = if noAnim or noAnimation then 0 else 200

      svg.selectAll("#yearText")
        .text(state.selMagnAttr())

      bubble.selectAll("circle.rin")
        .transition()
        .duration(duration)
        .attr("r", (d) -> d.rin)
      
      bubble.selectAll("circle.rout")
        .transition()
        .duration(duration)
        .attr("r", (d) -> d.rout)

      bubble.selectAll("text.nodeLabel")
        .attr("visibility", (d) -> if d.r > 10 then "visible" else "hidden")

      flows.selectAll("line")
        .transition()
        .duration(duration)
        .attr("stroke-width", (d) -> fwscale(v(d)))
        .attr("visibility", (d) -> if v(d) > 0 then "visible" else "hidden")

      unless dontUseForceLayout
       force.start()

    update()


    $("#yearSlider")
      .slider
        min: 0
        max: state.magnAttrs().length - 1
        value: state.selAttrIndex
        slide: (e, ui) -> stopAnimation(); updateYear(e, ui, false)
        change: (e, ui) -> updateYear(e, ui, false)

    $("#yearSlider").focus()

    #$("#playButton").button()

    $('g.bubble').tipsy
      gravity: 'w'
      html: true
      opacity: 0.9
      trigger: "manual"
      title: ->
        bubbleTooltip(d3.select(this).data()[0])



    timer = undefined

    stopAnimation = ->
      clearInterval(timer)
      timer = undefined
      $("#play span")
        .removeClass("ui-icon-pause")
        .addClass("ui-icon-play")


    $("#play").click ->
      if timer
        stopAnimation()
      else
        $("#play span")
          .removeClass("ui-icon-play")
          .addClass("ui-icon-pause")

        if state.selAttrIndex == state.magnAttrs().length - 1
          state.selAttrIndex = 0
        else
          state.selAttrIndex++

        $("#yearSlider").slider('value', state.selAttrIndex)
        update()

        timer = setInterval(->
          if (state.selAttrIndex >= state.magnAttrs().length - 1) 
            stopAnimation()
          else
            state.selAttrIndex++
            $("#yearSlider").slider('value', state.selAttrIndex)
            update()

        , 900)


