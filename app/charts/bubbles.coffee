this.bubblesChart = ->


  bubblesChartWidth = $(document).width() - 50
  bubblesChartHeight = $(document).height() - 70
  conf = null


  #############################################################################################
  #############################################################################################
  #############################################################################################

  chart = (selection) -> init(selection)

  chart.conf = (_) -> if (!arguments.length) then conf else conf = _; chart

  chart.width = (_) -> if (!arguments.length) then bubblesChartWidth else bubblesChartWidth = _; chart

  chart.height = (_) -> if (!arguments.length) then bubblesChartHeight else bubblesChartHeight = _; chart



  tseriesw = 250 #bubblesChartWidth*0.25
  tseriesh = 100 #bubblesChartHeight*0.18
  tseriesMarginLeft = 33  

  nodesWithoutCoordsMarginBottom = 50


  ###
  yearTicksWidth = bubblesChartWidth * 0.6
  yearTicksLeft = yearTicksRight = 10
  playButtonWidth = 40
  ###

  lightVersionMode = false #$.browser.mozilla
  if lightVersionMode
    dontUseForceLayout = true
    noAnimation = true
    flowMagnitudeThreshold = 1000*1e6-1
  else
    dontUseForceLayout = false
    noAnimation = false
    flowMagnitudeThreshold = 0



  state = null
  stopAnimation = null


  mapProj = winkelTripel()
  mapProjPath = d3.geo.path().projection(mapProj)

  force = d3.layout.force()
      .charge(0)
      .gravity(0)
      .size([bubblesChartWidth, bubblesChartHeight])



  shortenLabel = (labelText, maxLength) ->
    if labelText.length < maxLength
      labelText
    else
      labelText.substr(0, maxLength - 2) + ".."


  dateFromMagnAttr = (magnAttr) -> new Date(magnAttr, 0)
  dateFromMagnAttrInd = (magnAttrIndex) -> dateFromMagnAttr(state.magnAttrs()[magnAttrIndex])



  # data is expected to be in the following form:
  # [{date:new Date(1978, 0), inbound:123, outbound:321}, ...]
  createTimeSeries = (tseriesDiv, data, title, dir) ->
    

    dateDomain = [ dateFromMagnAttrInd(0), dateFromMagnAttrInd(state.magnAttrs().length - 1) ]

    tschart = timeSeriesChart()
      .dateDomain(dateDomain)
      .propColors(["lightcoral", "steelblue"])
      .width(tseriesw)
      .height(tseriesh)
      .dotRadius(1)
      .marginLeft(tseriesMarginLeft)
      .title(title)
      .ytickFormat(shortMagnitudeFormat)
      #.propColors(["lightcoral","steelblue"])

    # tschart.propColors switch dir
    #   when "in" then ["lightcoral"]
    #   when "out" then ["steelblue"]
    #   else ["lightcoral","steelblue"]

    d3.select(tseriesDiv).datum(data).call(tschart)

    updateYear = -> tschart.moveRule(dateFromMagnAttrInd(state.selAttrIndex))
    updateYear()
    $(tseriesDiv).bind "updateYear", updateYear




  class DivPanel

    constructor: (@panelDivId) -> 
      @div = $("#" + @panelDivId)
      unless @div.length > 0 
        throw new Error("Element with id '#{@panelDivId}' not found")

    find : (did) -> $(@div).children("[data-id="+did+"]")

    findNot : (did) -> $(@div).children(":not([data-id="+did+"])")

    addNew : (did, cssClass) -> 
      $(@div).append('<div data-id="'+did+'" class="'+cssClass+'"></div>')
      @find(did).get(0)

    remove : (did) -> @find(did).remove()

    removeOthers : (did) -> @findNot(did).remove()

    contains : (did) -> @find(did).length > 0


  tseriesPanel = new DivPanel("tseriesPanel")




  projectNode = (node) ->  
    lon = node[conf.lonAttr]
    lat = node[conf.latAttr]
    if (isNumber(lon) and isNumber(lat))
      mapProj([lon, lat])
    else
      undefined




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
    (if donor.length > 20
       "<span class=sm>from <b>#{donor}</b></span>"
     else
       "from <b>#{donor}</b>") +
    "  in #{state.selMagnAttr()} <br>"
    #"<div id=tseries></div>"





  ###
  createYearTicks = ->

    dates = state.magnAttrs().map (attr) -> dateFromMagnAttr(attr)

    x = d3.time.scale().domain([d3.min(dates), d3.max(dates)]).range([0, yearTicksWidth])          

    ticksSvg = d3.select("#yearTicks")
      .append("svg")
        .attr("width", yearTicksWidth + yearTicksLeft + yearTicksRight)
        .attr("height", 50)
      .append("g")
        .attr("transform", "translate(#{yearTicksLeft})")


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
  ###
    

  svg = null 
  nodes = null
  rscale = fwscale = null

  flowLineValue = (d) -> +d.data[state.selMagnAttr()]

  init = (selection) ->

    data = selection.datum()

    svg = selection 
      .append("svg")
        .attr("width", bubblesChartWidth)
        .attr("height", bubblesChartHeight)
        .attr("class", "bubble")



    idToNode = {}


    # After loadData



    provideNodesWithTotals(data.flows, data.nodes, conf)


    state = initFlowData(conf)
    state.selAttrIndex = 0 # state.magnAttrs().length - 7  # state.magnAttrs().length - 1
    state.totalsMax = calcMaxTotalMagnitudes(data, conf)


    maxTotalMagnitudes = state.totalsMax
    maxTotalMagnitude = Math.max(
          d3.max(maxTotalMagnitudes.inbound), 
          d3.max(maxTotalMagnitudes.outbound))

    rscale = d3.scale.sqrt()
      .range([0, Math.min(bubblesChartWidth/20, bubblesChartHeight /10)])
      .domain([0, maxTotalMagnitude])
    maxr = rscale.range()[1]

    fwscale = d3.scale.sqrt() #.linear()
      .range([0,  maxr *2])
      .domain([0, maxTotalMagnitude])

    #timescale = d3.time.scale().domain([d3.min(dates), d3.max(dates)]).range([0, w])          
  


    #createYearTicks()

    svg.append("rect")
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", bubblesChartWidth)
      .attr("height", bubblesChartHeight)
      .attr("fill", "white")
      .on 'click', (d) -> clearNodeSelection()


    fitProjection(mapProj, data.map, 
      [[-bubblesChartWidth*0.15,bubblesChartHeight*0.15],[bubblesChartWidth, bubblesChartHeight * 0.8]], true)







    hasFlows = (node, flowDirection) -> 
      totals = node.totals?[flowDirection]
      (if totals? then d3.max(totals) > flowMagnitudeThreshold else false)

    nodesWithFlows = data.nodes.filter(
      (node) -> hasFlows(node, "inbound") or hasFlows(node, "outbound")
    )

    #nodesWithLocation = nodesWithFlows.filter (node) -> projectNode(node)?

    #nodesWithoutLocationX = 0

    nodes = nodesWithFlows.map (d) ->
      xy = projectNode(d)

      maxin = d3.max(d.totals.inbound ? [0])
      maxout = d3.max(d.totals.outbound ? [0])

      idToNode[d[conf.nodeIdAttr]] =
        data : d
        max : Math.max(maxin, maxout)
        name: d[conf.nodeLabelAttr] 
        code: d[conf.nodeIdAttr]
        x: xy?[0]
        y: xy?[1]
        gravity: {x: xy?[0], y: xy?[1]}



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

    for f in data.flows
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
              #l = Math.sqrt(dx * dx + dy * dy)
              l2 = (dx * dx + dy * dy)
              d = a.r + b.r
              d2 = d * d 
              #if (l < d)
              if (l2 < d2)
                l = Math.sqrt(l2)
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
            .data(d.outlinks) #.filter (d) -> flowLineValue(d) > 0)
          .enter().append("svg:line")
            .attr("class", "out")
            #.attr("stroke", outboundColor)
            .attr("opacity", 0)
            .transition()
              .duration(300)
                .attr("opacity", 1)


      if (d.inlinks?)
        flows.selectAll("line.in")
            .data(d.inlinks) #.filter (d) -> flowLineValue(d) > 0)
          .enter().append("svg:line")
            .attr("class", "in")
            #.attr("stroke", inboundColor)
            #.attr("opacity",0.5)
            .attr("opacity", 0)
            .transition()
              .duration(300)
                .attr("opacity", 1)

      createFlowTimeSeries = (flow, d, i) ->
        
        dir = (if d3.select(flow).classed("in") then "in" else "out")

        flowData = (for attr in state.magnAttrs() when d.data[attr]?
          date: dateFromMagnAttr(attr)
          value: +d.data[attr]
        )

        data = if dir is "in"
          inbound : flowData
          outbound : []
        else
          inbound : []
          outbound : flowData

  
        if not tseriesPanel.contains("flow" + i)
          tseries = tseriesPanel.addNew("flow" + i, "tseries")
          recipient = d.target.data[conf.nodeLabelAttr]
          donor = d.source.data[conf.nodeLabelAttr]

          flowLabel = shortenLabel(donor, 20) + " -> " + shortenLabel(recipient, 20)

          createTimeSeries(tseries, data, flowLabel, dir)



      flows.selectAll("line")
        .attr("x1", (d) -> d.source.x)
        .attr("y1", (d) -> d.source.y)
        .attr("x2", (d) -> d.target.x)
        .attr("y2", (d) -> d.target.y)
        .attr("stroke-width", (d) -> fwscale(flowLineValue(d)))
        .attr("visibility", (d) -> if flowLineValue(d) > 0 then "visible" else "hidden")
        .on "mouseover", (d, i) ->
          if this.parentNode?
            this.parentNode.appendChild(this)

          $(this).tipsy("show")
          # $("#tseriesPanel").add('<div id="tseries"></div>')

          createFlowTimeSeries(this, d, i)

          $(tipsy.$tip)
              .css('top', d3.event.pageY-($(tipsy.$tip).outerHeight()/2))
              .css('left', d3.event.pageX + 10)


        .on "mouseout", (d, i) ->
          $(this).tipsy("hide")
          tseriesPanel.remove("flow" + i)


      $('line').tipsy
        gravity: 'w'
        opacity: 0.9
        html: true
        trigger: "manual"
        title: ->
          flowTooltip(d3.select(this).data()[0])



    createNodeTimeSeries = (node, d, i) ->
      data = 
        inbound : state.magnAttrs().map (attr, i) -> 
          date: dateFromMagnAttr(attr)
          value: d.data.totals?.inbound?[i] ? 0

        outbound : state.magnAttrs().map (attr, i) -> 
          date: dateFromMagnAttr(attr)
          value: d.data.totals?.outbound?[i] ? 0

      if not tseriesPanel.contains("node" + i)
        tseries = tseriesPanel.addNew("node" + i, "tseries")
        nodeLabel = d3.select(node).data()[0][conf.nodeLabelAttr]
        #parent = d3.select(tseries)
        #parent.setSelDateTo = setSelDateTo
        createTimeSeries(tseries, data, shortenLabel(nodeLabel, 40))        


    bubble = svg.selectAll("g.bubble")
        .data(nodes)
      .enter()
        .append("g")
          .attr("class", "bubble")
          .attr("transform", (d) -> "translate(#{d.x},#{d.y})")
          .on 'click', (d, i) ->

            if selectedNode == this
              tseriesPanel.remove("node" + i)
              selectedNode = null
              d3.select(this).selectAll("circle").classed("selected", false)
            else 
              if selectedNode != null
                tseriesPanel.removeOthers("node" + i)
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
              tseriesPanel.remove("node" + i)
  
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



    ###
    svg.append("text")
      .attr("id", "yearText")
      .attr("font-size", bubblesChartWidth/15)
      .attr("x", 20) #bubblesChartWidth - 20)
      .attr("y", 100)
      .attr("text-anchor", "start")
        .text(state.selMagnAttr())
    ###


    update()

    ###
    $("#yearSlider")
      .slider
        min: 0
        max: state.magnAttrs().length - 1
        value: state.selAttrIndex
        slide: (e, ui) -> stopAnimation(); setSelAttrIndexTo(ui.value, false)
        change: (e, ui) -> setSelAttrIndexTo(ui.value, false)

    $("#yearSlider").focus()

    #$("#playButton").button()
    ###

    $('g.bubble').tipsy
      gravity: 'w'
      html: true
      opacity: 0.9
      trigger: "manual"
      title: ->
        bubbleTooltip(d3.select(this).data()[0])


    ###

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
        $(".tseries").trigger("updateYear")
        update()

        timer = setInterval(->
          if (state.selAttrIndex >= state.magnAttrs().length - 1) 
            stopAnimation()
          else
            state.selAttrIndex++
            $("#yearSlider").slider('value', state.selAttrIndex)
            $(".tseries").trigger("updateYear")
            update()

        , 900)

    ###

  listeners = { changeSelDate : [] }

  chart.on = (event, handler) ->
    listeners.changeSelDate.push handler
    chart


  chart.setSelDateTo = (date, noAnim) ->
    idx = state.magnAttrs().indexOf(utils.date.dateToYear(date))
    chart.setSelAttrIndexTo(idx, noAnim) unless idx < 0
    chart
   
  chart.setSelAttrIndexTo = (newSelAttr, noAnim) ->
    unless state.selAttrIndex == newSelAttr
      #console.log "bubbles ",state.selAttrIndex, "<>",newSelAttr
      old = state.selAttrIndex
      state.selAttrIndex = newSelAttr
      update(noAnim)
      $(".tseries line.rule").trigger("updateYear")
      for handler in listeners.changeSelDate
        handler(
          utils.date.yearToDate(state.magnAttrs(newSelAttr)),
          utils.date.yearToDate(state.magnAttrs(old)))
      #$("#yearSlider").slider('value', state.selAttrIndex)
    chart

  updateNodeSizes = ->
    for n in nodes
      d = n.data
      n.inbound = d.totals.inbound?[state.selAttrIndex] ? 0
      n.outbound = d.totals.outbound?[state.selAttrIndex] ? 0
      n.rin = rscale(n.inbound)
      n.rout = rscale(n.outbound)
      n.r = Math.max(n.rin, n.rout)
      n.maxr = rscale(n.max)

  update = (noAnim) ->
    updateNodeSizes()
    duration = if noAnim or noAnimation then 0 else 200

    ###
    svg.selectAll("#yearText")
      .text(state.selMagnAttr())
    ###

    bubble = svg.selectAll("g.bubble")

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

    flows = svg.selectAll("g.flows line")
    flows
      .transition()
      .duration(duration)
      .attr("stroke-width", (d) -> fwscale(flowLineValue(d)))
      .attr("visibility", (d) -> if flowLineValue(d) > 0 then "visible" else "hidden")

    force.start() unless dontUseForceLayout
     

  chart
