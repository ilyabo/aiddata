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



  tseriesw = 261 #bubblesChartWidth*0.25
  tseriesh = 100 #bubblesChartHeight*0.18
  tseriesMarginLeft = 40

  nodesWithoutCoordsMarginBottom = 50


  ###
  yearTicksWidth = bubblesChartWidth * 0.6
  yearTicksLeft = yearTicksRight = 10
  playButtonWidth = 40
  ###

  dontUseForceLayout = false
  noAnimation = false
  flowMagnitudeThreshold = 0



  state = null
  stopAnimation = null
  selectedNode = null


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
  createTimeSeriesChart = (tseriesDiv, data, title, dir) ->
    
    dateDomain = [ dateFromMagnAttrInd(0), dateFromMagnAttrInd(state.magnAttrs().length - 1) ]

    tschart = timeSeriesChart()
      .dateDomain(dateDomain)
      .propColors(["lightcoral", "steelblue"])
      .width(tseriesw)
      .height(tseriesh)
      .dotRadius(1)
      .marginLeft(tseriesMarginLeft)
      .marginRight(12)
      .title(title)
      .yticks(3)
      .ytickFormat(shortMagnitudeFormat)
      #.indexedMode(true)
      .showRule(true)
      .hideRuleOnMouseout(false)
      .on "rulemove", (date) -> if date? then chart.setSelDateTo(date, true)


      #.propColors(["lightcoral","steelblue"])

    # tschart.propColors switch dir
    #   when "in" then ["lightcoral"]
    #   when "out" then ["steelblue"]
    #   else ["lightcoral","steelblue"]

    d3.select(tseriesDiv).datum(data).call(tschart)

    updateYear = -> tschart.moveRule(dateFromMagnAttrInd(state.selAttrIndex))
    updateYear()
    $(tseriesDiv).bind("updateYear", updateYear)

    tseriesDiv.__chart__ = tschart
    tschart




  class DivPanel

    constructor: (@panelDivId) -> 
      @div = $("#" + @panelDivId)
      unless @div.length > 0 
        throw new Error("Element with id '#{@panelDivId}' not found")

    find : (id) -> $(@div).children("[data-id='#{id}']")

    findNot : (id) -> $(@div).children(":not([data-id='#{id}'])")

    addNew : (id, cssClass) -> 
      $(@div).append('<div data-id="'+id+'" class="'+cssClass+'"></div>')
      @find(id).get(0)

    remove : (id) -> @find(id).remove()

    removeAll : -> $(@div).children().remove()

    removeOthers : (id) -> @findNot(id).remove()

    contains : (id) -> @find(id).length > 0


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



  legendMargin = {top: 85, right: 15, bottom: 10, left: 15}

  updateLegend = (selection, maxTotalMagnitude) ->

    maxR = rscale.range()[1]  # rscale(pow10(maxOrd))
    legend = selection.select("svg.legend")
    
    maxOrd = Math.floor(log10(maxTotalMagnitude))
    values = []

    unless isNaN(maxTotalMagnitude)
      addValue = (v) ->
        values.push(v) if values.length is 0 or (rscale(values[values.length - 1]) - rscale(v)) > 6
      addValue maxTotalMagnitude
      addValue pow10(maxOrd) * 5
      addValue pow10(maxOrd)
      addValue pow10(maxOrd) / 2
      values.push(pow10(maxOrd - 1))
  

    legend
      .attr("width", maxR*2 + legendMargin.left + legendMargin.right)
      .attr("height",maxR*2 + legendMargin.top + legendMargin.bottom)


    legend.select("g.outer")
      .attr("transform", "translate(#{legendMargin.left + maxR},#{legendMargin.top + maxR})")

    arc = d3.svg.arc()
      .startAngle(-Math.PI)
      .endAngle(Math.PI)
      .innerRadius(0)
      .outerRadius(rscale)
    
    legend = selection.select("svg.legend g.outer")


    item = legend.selectAll("g.item")
      .data(values, (d) -> d)


    # enter
    itemEnter = item.enter().append("g")
      .attr("class", "item")

    itemEnter.append("path")
    itemEnter.append("text")
      .attr("text-anchor", "middle")
      #.attr("alignment-baseline", "central")
      .attr("x", 0)

    itemEnter.transition().duration(200).attr("opacity", 1)


    # update
    item.attr("transform", (d) -> "translate(0,#{maxR-rscale(d)})")

    item.selectAll("path")
      .transition().duration(200)
      .attr("d", arc)

    item.selectAll("text")
      .text(magnitudeFormat)
      .transition().duration(200)
      .attr("y", (d, i) -> -rscale(d)-1)

    legend.selectAll("g.item").sort((a, b) -> d3.descending(a, b))

    # exit
    item.exit()
      .transition().duration(200).attr("opacity", 0)
      .remove()


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

    selection.attr("class", "bubbleChart")

    data = selection.datum()

    isUpdate = not selection.select("svg").empty()

    unless isUpdate
      svg = selection 
        .append("svg")
          .attr("width", bubblesChartWidth)
          .attr("height", bubblesChartHeight)
          .attr("class", "bubble")







    provideNodesWithTotals(data.flows, data.nodes, conf)


    unless isUpdate
      state = initFlowData(conf)
      state.selAttrIndex = 0 # state.magnAttrs().length - 7  # state.magnAttrs().length - 1

    state.totalsMax = calcMaxTotalMagnitudes(data, conf)


    maxTotalMagnitudes = state.totalsMax
    maxTotalMagnitude = Math.max(
          d3.max(maxTotalMagnitudes.inbound), 
          d3.max(maxTotalMagnitudes.outbound))

    rscale = d3.scale.sqrt()
      .range([0, Math.min(bubblesChartWidth/25, bubblesChartHeight /12)])
      .domain([0, maxTotalMagnitude])
    maxr = rscale.range()[1]

    fwscale = d3.scale.sqrt() #.linear()
      .range([0,  maxr *2])
      .domain([0, maxTotalMagnitude])

    #timescale = d3.time.scale().domain([d3.min(dates), d3.max(dates)]).range([0, w])          
  

    do ->
      if selectedNode?
        tseriesPanel.remove("_overallTotals_")
      else
        overallTotals = do ->
          totals = {}
          for dir,i in ["outbound"]  # "inbound" is the same for totals 
            totals[dir] = []
            for n in data.nodes when n.totals?[dir]?
                for v,j in n.totals[dir] when v? and not isNaN(v)
                  totals[dir][j] ?= 0
                  totals[dir][j] += v
          nodeTimeSeriesData(totals)

        div = tseriesPanel.find("_overallTotals_")?.get(0)
        if div?
          d3.select(div).datum(overallTotals).call(div.__chart__)
        else
          div = tseriesPanel.addNew("_overallTotals_", "tseries")
          createTimeSeriesChart(div, overallTotals, "Total")        


    unless isUpdate
      do ->
        legend = selection.append("svg")
          .attr("class", "legend")
        
        colors = legend.append("g")
          .attr("class", "colors")

        legend.append("text")
          .attr("class", "caption")
          .attr("x", legendMargin.left + maxr)
          .attr("y", "15")
          .attr("text-anchor", "middle")
          .text("Aid commitment amount")

        legend.append("text")
          .attr("class", "caption")
          .attr("x", legendMargin.left + maxr)
          .attr("y", "28")
          .attr("text-anchor", "middle")
          .text("US$ constant (2009)")

        legend.append("g").attr("class", "outer")

        itemEnter = colors.selectAll("g.item")
          .data([{name:"Donated", color:"steelblue"}, {name:"Received", color:"#d56869"}])
          .enter()
        .append("g")
          .attr("class", "item")
          .attr("transform", (d,i) -> "translate(#{legendMargin.left + maxr - 28}, #{40 + i*15})")

        itemEnter.append("rect")
          .attr("x", "0")
          .attr("y", "0")
          .attr("width", "15")
          .attr("height", "11")
          .attr("fill", (d) -> d.color)

        itemEnter.append("text")
          .attr("x", "19")
          .attr("y", "5")
          .attr("alignment-baseline", "central")
          .text((d) -> d.name)




    updateLegend(selection, maxTotalMagnitude)


    


    #createYearTicks()

    unless isUpdate
      svg.append("rect")
        .attr("x", 0)
        .attr("y", 0)
        .attr("width", bubblesChartWidth)
        .attr("height", bubblesChartHeight)
        .attr("fill", "white")
        .on 'click', (d) -> chart.clearNodeSelection()


      fitProjection(mapProj, data.map, 
        [[-bubblesChartWidth*0.15,bubblesChartHeight*0.15],[bubblesChartWidth, bubblesChartHeight * 0.8]], true)







    hasFlows = (node, flowDirection) -> 
      totals = node.totals?[flowDirection]
      (if totals? then d3.max(totals) > flowMagnitudeThreshold else false)

    nodesWithFlows = data.nodes.filter(
      (node) -> hasFlows(node, "inbound") or hasFlows(node, "outbound")
    )
    .filter (node) -> projectNode(node)?

    #nodesWithLocation = nodesWithFlows.filter (node) -> projectNode(node)?

    #nodesWithoutLocationX = 0

    nodes = do ->
      idToNode = {}
      nodesArr = nodesWithFlows.map (d) ->
        xy = projectNode(d)

        maxin = d3.max(d.totals.inbound ? [0])
        maxout = d3.max(d.totals.outbound ? [0])

        n =
          data : d
          max : Math.max(maxin, maxout)
          name: d[conf.nodeLabelAttr] 
          code: d[conf.nodeIdAttr]
          x: xy?[0]
          y: xy?[1]
          gravity: {x: xy?[0], y: xy?[1]}

        idToNode[d[conf.nodeIdAttr]] = n
        return n

      nodesArr.nodeById = (id) -> idToNode[id]
      nodesArr



    updateNodeSizes()
    placeNodesWithoutCoords(nodes)


    

    for f in data.flows
      src = nodes.nodeById(f[conf.flowOriginAttr])
      target = nodes.nodeById(f[conf.flowDestAttr])
      if src? and target?
        link = 
          source: src
          target: target
          data: f 
        
        (src.outlinks ?= []).push link
        (target.inlinks ?= []).push link


    unless isUpdate
      svg.append("g")
        .attr("class", "map")
        .selectAll('path')
          .data(data.map.features)
        .enter().append('path')
          .attr('d', mapProjPath)
          .attr("fill", "#f0f0f0")
          .on 'click', (d) -> chart.clearNodeSelection()

      svg.append("g")
        .attr("class", "flows")


    flows = svg.selectAll("g.flows")




    bubble = svg.selectAll("g.bubble")
      .data(nodes, (d) -> d[conf.nodeIdAttr])


    # update subnodes data
    bubble.selectAll("circle").datum((d) -> this.parentNode.__data__)
    bubble.selectAll("text").datum((d) -> this.parentNode.__data__)

    bubble.exit().remove()

    bubbleEnter = bubble.enter()
      .append("g").attr("class", "bubble")

    bubbleEnter.append("circle").attr("class", "rin")
    bubbleEnter.append("circle").attr("class", "rout")

    parensre = /^\((.*)\)$/

    bubbleEnter.append("text")
      .attr("class", "nodeLabel")
      .attr("y", 1)
      .attr("font-size", 9)
      .attr("text-anchor", "middle")
      .text((d)-> 
        c = d[conf.nodeIdAttr]

        m = parensre.exec c
        c = (if m? then m[1] else c)

        (if c.length < 5 then c else c.substring(0,3)+"..")
      )

    bubbleEnter.on 'click', (d, i) ->
      #flows.selectAll("line").remove()
      old = selectedNode
      if selectedNode == this
        tseriesPanel.remove(d[conf.nodeIdAttr])
        selectedNode = null
        d3.select(this).selectAll("circle").classed("selected", false)
        dispatch.selectNode(null, old?.__data__)
      else 
        if selectedNode != null
          tseriesPanel.removeOthers(d[conf.nodeIdAttr])
          d3.select(selectedNode).selectAll("circle").classed("selected", false)
          flows.selectAll("line").remove()
        else
          createNodeTimeSeries(this, d, i)  
        selectedNode = this
        d3.select(this).selectAll("circle").classed("selected", true)
        dispatch.selectNode(this.__data__, old?.__data__)
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
        tseriesPanel.remove(d[conf.nodeIdAttr])

      $(this).tipsy("hide")


    force.nodes(nodes)

    update()
    updateNodeTimeSeries(nodes)



    if selectedNode?
      if nodes.nodeById(d3.select(selectedNode).datum()[conf.nodeIdAttr])?
        showFlowsOf(selectedNode)
        
      else        
        # selected node does not have any flows
        flows.selectAll("line").remove()


    chart.clearNodeSelection = ->
      if selectedNode?
        d3.select(selectedNode).selectAll("circle").classed("selected", false)
        flows.selectAll("line").remove()
        tseriesPanel.removeAll()
        old = selectedNode
        selectedNode = null
        dispatch.selectNode(null, old?.__data__)


    #unless isUpdate
    #  $(document).keyup (e) -> if e.keyCode == 27 then clearNodeSelection()

    # $('g.bubble').tipsy
    #   gravity: 'w'
    #   html: true
    #   opacity: 0.9
    #   trigger: "manual"
    #   title: -> bubbleTooltip(d3.select(this).data()[0])


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

  dispatch = d3.dispatch("selectDate", "selectNode")

  d3.rebind(chart, dispatch, "on");


  chart.setSelDateTo = (date, noAnim) ->
    idx = state.magnAttrs().indexOf(utils.date.dateToYear(date))
    chart.setSelAttrIndexTo(idx, noAnim) unless idx < 0
    chart
   
  chart.setSelAttrIndexTo = (newSelAttr, noAnim) ->
    unless state.selAttrIndex == newSelAttr
      #console.log "bubbles ",state.selAttrIndex, "<>",newSelAttr
      old = state.selAttrIndex
      state.selAttrIndex = newSelAttr
      updateNodeSizes()
      update(noAnim)
      $(".tseries line.rule").trigger("updateYear")
      dispatch.selectDate(
        utils.date.yearToDate(state.magnAttrs(newSelAttr)),
        utils.date.yearToDate(state.magnAttrs(old))
      )
      #$("#yearSlider").slider('value', state.selAttrIndex)
    chart





  showFlowsOf = (bbl) ->

    flows = svg.selectAll("g.flows")
    d = d3.select(bbl).datum()

    ###
    ffwscale = d3.scale.linear()
      .range([0, rscale.range()[1]/2])
      .domain([0, Math.max(d3.max(max.inbound), d3.max(max.outbound))])
    ###

    if (d.outlinks?)
      outflow = flows.selectAll("line.out")
          .data(d.outlinks, (d) -> d.target[conf.nodeIdAttr]) #.filter (d) -> flowLineValue(d) > 0)
        
      outflow.exit().remove()

      outflow.enter().append("svg:line")
        .attr("class", "out")
        .attr("stroke-width", 0)

    if (d.inlinks?)
      inflow = flows.selectAll("line.in")
          .data(d.inlinks, (d) -> d.source[conf.nodeIdAttr]) #.filter (d) -> flowLineValue(d) > 0)

      inflow.exit().remove()

      inflow.enter().append("svg:line")
        .attr("class", "in")
        .attr("stroke-width", 0)


    lines = flows.selectAll("line")

    lines
      .attr("x1", (d) -> d.source.x)
      .attr("y1", (d) -> d.source.y)
      .attr("x2", (d) -> d.target.x)
      .attr("y2", (d) -> d.target.y)
      .attr("visibility", (d) -> if flowLineValue(d) > 0 then "visible" else "hidden")
      .on "mouseover", (d, i) ->
        if this.parentNode?
          this.parentNode.appendChild(this)

        $(this).tipsy("show")

        createFlowTimeSeries(this, d, i)

        $(tipsy.$tip)
            .css('top', d3.event.pageY-($(tipsy.$tip).outerHeight()/2))
            .css('left', d3.event.pageX + 10)
      .on "mouseout", (d, i) ->
        $(this).tipsy("hide")
        tseriesPanel.remove("flow" + i)

      lines
        .transition()
            .duration(200)
              .attr("stroke-width", (d) -> fwscale(flowLineValue(d)))
              #.attr("opacity", 1)


    $('g.flows line').tipsy
      gravity: 'w'
      opacity: 0.9
      html: true
      trigger: "manual"
      title: -> flowTooltip(d3.select(this).datum())



  # converts totals data into a sturcture which tseriesChart understands
  nodeTimeSeriesData = (totals) ->
    #totals = d.data.totals
    inbound :
      if totals?.inbound?
        (for val,i in totals.inbound when val?
          date: dateFromMagnAttr(state.magnAttrs()[i])
          value: val
        )
      else []

    outbound :
      if totals?.outbound?
        (for val,i in totals.outbound when val?
          date: dateFromMagnAttr(state.magnAttrs()[i])
          value: val
        )
      else []


  createNodeTimeSeries = (node, d, i) ->    
    if not tseriesPanel.contains(d[conf.nodeIdAttr])
      tseriesDiv = tseriesPanel.addNew(d[conf.nodeIdAttr], "tseries")
      d3.select(tseriesDiv).attr("data-type", "node")
      nodeLabel = d3.select(node).data()[0][conf.nodeLabelAttr]
      tschart = createTimeSeriesChart(tseriesDiv, nodeTimeSeriesData(d.data.totals), shortenLabel(nodeLabel, 40))
      #tseriesDiv.__chart__ = tschart


  updateNodeTimeSeries = (nodesData) ->
    byId = d3.nest()
      .key((d) -> d[conf.nodeIdAttr])
      .rollup((list) -> if list.length is 1 then list[0] else list)
      .map(nodesData)

    d3.select("#tseriesPanel")
      .selectAll("div.tseries")
      .each ->
        _div = d3.select(this)
        _chart = this.__chart__
        _type = _div.attr("data-type")
        _data = byId[_div.attr("data-id")]
        switch _type
          when "node" then _div.datum(nodeTimeSeriesData(_data.data.totals)).call(_chart)



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

      createTimeSeriesChart(tseries, data, flowLabel, dir)


  updateNodeSizes = ->
    for n in nodes
      d = n.data
      n.inbound = d.totals.inbound?[state.selAttrIndex] ? 0
      n.outbound = d.totals.outbound?[state.selAttrIndex] ? 0
      n.rin = rscale(n.inbound)
      n.rout = rscale(n.outbound)
      n.r = Math.max(n.rin, n.rout)
      n.maxr = rscale(n.max)

  placeNodesWithoutCoords = do -> 
    squeezeFactor = 0.75
    (nodes) ->
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


  update = (noAnim) ->
    #updateNodeSizes()
    

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
      .transition()
      .duration(duration).attr("opacity", (d) -> if d.r > 10 then 1.0 else 0)
      #.delay(duration).attr("visibility", (d) -> if d.r > 10 then "visible" else "hidden")

    flows = svg.selectAll("g.flows line")
    flows
      .transition()
      .duration(duration)
      .attr("stroke-width", (d) -> fwscale(flowLineValue(d)))
      .attr("visibility", (d) -> if flowLineValue(d) > 0 then "visible" else "hidden")

    if dontUseForceLayout
      bubble.attr("transform", (d) -> "translate(#{d.x},#{d.y})")
    else     
      force.start() 


  force.on "tick", (e) -> 
    
    k = e.alpha
    kg = k * .02

    force.nodes().forEach((a, i) ->
      # Apply gravity forces
      a.x += (a.gravity.x - a.x) * kg
      a.y += (a.gravity.y - a.y) * kg
      force.nodes().slice(i + 1).forEach((b) -> 
        # Check for collisions.
        dx = a.x - b.x
        dy = a.y - b.y
        #l = Math.sqrt(dx * dx + dy * dy)
        l2 = (dx * dx + dy * dy)
        d = a.r + b.r + 2     # +2 to leave space for the border
        d2 = d * d 
        #if (l < d)
        if (l2 < d2)
          l = Math.sqrt(l2)
          l = (l - d) / l * k
          dx *= l
          dy *= l
          
          # the larger body should move less
          ka = 1 - (a.r / d)
          kb = 1 - (b.r / d)

          a.x -= dx * ka
          a.y -= dy * ka
          b.x += dx * kb
          b.y += dy * kb
      )
    )

    svg.selectAll("g.bubble")
      .attr("transform", (d) -> "translate(#{d.x},#{d.y})")

    svg.select("g.flows").selectAll("line")
      .attr("x1", (d) -> d.source.x )
      .attr("y1", (d) -> d.source.y )
      .attr("x2", (d) -> d.target.x )
      .attr("y2", (d) -> d.target.y )



  chart
