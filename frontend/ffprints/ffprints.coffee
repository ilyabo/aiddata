this.ffprintsChart = () ->

  conf = {}
  state = {}
  data = null
  magnitudeColor = colorScaleLimits = null
  flowsTree = null   # fast access to flow values by origin/dest/attrGroup

  #useLogColorScale = true

  ffprintsChartWidth = 800
  ffprintsChartHeight = 600

  
  #scale = 300 # width/5
  showNodeNames = false
  ffprintsScale = 1.0  # is updated when map size is set
  ffprintsHeight = 12
  ffprintHoverScale = 3.0

  fmt = d3.format(",.0f")


  originsMap = destsMap = null

  forceK = 0.1
  mapProj = winkelTripel()
  mapProjPath = d3.geo.path().projection(mapProj)
  mapTitles = ["Origins", "Destinations"]

  tooltipText = (value, nodeData, magnAttr, flowDirection, magnAttrGroup) ->
    nodeData[conf.nodeLabelAttr] + ' in ' + magnAttr + ': <br>' + fmt(value)
 


  # Show/hide tooltip preventing several tooltips visible 
  # at once
  tipsy = ( ->
    prev = {}
    tipsy =

      show : (name, elem) ->
        if elem?
          if prev[name]? then $(prev[name]).tipsy("hide")
          $(elem).tipsy("show")
          prev[name] = elem
        else
          prev[name]

      shown : (name) -> tipsy.show(name)?

      hide : (name) ->
        if prev[name]?
          $(prev[name]).tipsy("hide")
          delete prev[name]
    tipsy
  )()



  oppositeFlowDirection = (flowDirection) ->
    switch flowDirection
      when "outbound" then "inbound"
      when "inbound" then "outbound"

  mapOf = (flowDirection) ->
    switch flowDirection
      when "inbound" then destsMap
      when "outbound" then originsMap

  oppositeMap = (flowDirection) -> mapOf(oppositeFlowDirection(flowDirection))








  ############################             ############################ 
  ############################ ffprintsMap ############################ 
  ############################             ############################ 

  ffprintsMap = ->

    width = 300
    height = 200
    flowDirection = "outbound"
    title = "---"
    force = nodeData = nodeDataWithLocation = null
    mapSvgSelection = null

    box = fingerprints = null


    ## Helper functions

    ndata = (fp) -> d3.select(fp.parentNode.parentNode).data()[0].data

    totalsValues = (ndata) -> ndata.totals[state.selMagnAttrGrp][flowDirection]

    totalsValueByAttr = (ndata, magnAttr) -> totalsValues(ndata)[state.magnAttrs().indexOf(magnAttr)]


    projectNode = (node) ->  
      lon = node[conf.lonAttr]
      lat = node[conf.latAttr]
      if (isNumber(lon) and isNumber(lat))
        mapProj([lon, lat])
      else
        undefined

    ## Start
    mapChart = (selection) ->


      mapSvgSelection = selection

      data = selection.datum()

      fitProjection(mapProj, data.map, [[-width/7,0],[width, height]], true)

      createBox = ->
        clipId = "outerBoxClip#{flowDirection}"
        selection.append("clipPath")
          .attr("id", clipId)
        .append("rect")
          .attr("x", 0)
          .attr("y", 0)
          .attr("width", width - 1)
          .attr("height", height - 1)

        outer = selection.append('g')
            .attr('class', 'outer')
            .attr("clip-path", "url(#"+clipId+")")

        map = outer.append('g').attr('class', 'map')
        legend = outer.append("g").attr("class", "legend")
        nodes = outer.append('g').attr('class', 'nodes')

        outer.append("rect")
          .attr("fill", "none")
          .attr("stroke", "gray")
          .attr("stroke-width", 1)
          .attr("x", 0)
          .attr("y", 0)
          .attr("width", width - 1)
          .attr("height", height - 1)
        {
          outer : outer
          map : map 
          nodes : nodes
          legend : legend
        }


      box = createBox()




      box.outer.append("text")
        .attr("text-anchor", "middle")
        .attr("x", width/2)
        .attr("y", 30)
        .attr("font-size", "20pt")
        .attr("font-weight", "bold")
        .text(title)

      ####################### Force layout #########################

      force = d3.layout.force()
          .charge(0)
          .gravity(0)
          .size([width, height])


      


      ####################### Country shapes #########################
      box.map
        .selectAll('path')
          .data(data.map.features)
        .enter().append('path')
          .attr('d', mapProjPath)
          .on 'mouseover', ->
             #this.parentNode.appendChild(this)
             d3.select(this)
              .transition()
                .duration(300)
                .attr("fill", d3.interpolate("#eee", "#0166ce")(.1))
          .on 'mouseout', ->
              d3.select(this)
                .transition()
                  .delay(50)
                  .duration(200)
                  .attr("fill", "#eee" )


      # calc magnitude totals for the nodes



      ###
      domainForColors = (colors, min, max) ->
        domain = [ min ]
        d = (max - min) / (colors.length - 1)
        for i in [1..(colors.length - 1)]
          domain.push(min + d*i)
        domain

      
      magnitudeColor = d3.scale.log()
        .domain(domainForColors(ColorBrewer.sequential.OrRd, 1, 84302806823.77 ))# state.maxTotalMagnitude()))
        .range(ColorBrewer.sequential.OrRd)
      
      
      magnitudeColor = d3.scale.linear()
          .domain([1, 84302806823.77])   #state.maxTotalMagnitude()])
          .range([
              ColorBrewer.sequential.OrRd[0],
              ColorBrewer.sequential.OrRd[ColorBrewer.sequential.OrRd.length - 1]
            ])
      ###





      ## ## Color scale
      ###
      minPow = 7

      log10 = (x) -> Math.log(x) / Math.log(10)
      maxTotal = state.maxTotalMagnitude()
      #maxPower = Math.ceil(Math.log(maxTotal) / Math.log(10))

      magnitudeColor = ( -> 
        scale = new chroma.ColorScale({
            #colors: ['#F7E1C5', '#6A000B'], mode: 'hcl',
            colors: chroma.brewer.OrRd
            limits: 
              if useLogColorScale
                [minPow, log10(maxTotal)]
              else
                [0, maxTotal]
          
        })

        (value) ->
          if useLogColorScale
            logv = log10(value)
            scale.getColor(Math.max(minPow+1, logv))
          else
            scale.getColor(Math.max(0, value))
      )()




      ## ## Legend
      
      legendValues = (->
        if useLogColorScale
          vals = [minPow .. Math.ceil(log10(maxTotal))].reverse().map((i) -> Math.pow(10, i))
          nextToLast = vals[1]
          vals.splice(1, 0, nextToLast * 2.5)
          vals.splice(1, 0, nextToLast * 5)
          console.log vals 
          vals
        else
          [0..5].map((i) ->  i * maxTotal / 5).reverse()
      )()

      legend = mapSvgSelection.append("g")
        .attr("transform", "scale(0.75)")
        .attr("class", "legend")

      item = legend.selectAll("g.item")
          .data(legendValues)
      .enter().append("g")
        .attr("class", "item")
        .attr("transform", (d,i) ->  "translate(20," + (20 + i*30) + ")")
          
      item.append("rect")
        .attr("visibility", (d,i) -> if i < legendValues.length - 1 then "visible" else "hidden")
        .attr("x", 0)
        .attr("y", 0)
        .attr("width", 20)
        .attr("height", 30)
        .attr("fill", (d,i) -> magnitudeColor(d))
          
      item.append("text")
        .attr("x", 28)
        .attr("y", 5)
        .attr("fill", "black")
        .text((d,i) -> 
          v = Math.round(Math.min(d, maxTotal) / Math.pow(10, 6))
          if v == 0
            "$0"
          else
            "$#{fmt(v)} million"
          )
          ###


      makeNodeTotalsValuesList = (nodes, attrGroup) ->
        list = [0]
        add = (vals) ->
          if vals? then for v in vals
            if v != 0 then list.push v
          return

        for node in nodes
          add(node.totals[attrGroup].inbound)
          add(node.totals[attrGroup].outbound)

        return list

      



      legend = box.legend.attr("transform", "scale(0.75)")
        

      item = legend.selectAll("g.item")
          .data(colorScaleLimits.slice().reverse())
      .enter().append("g")
        .attr("class", "item")
        .attr("transform", (d,i) ->  "translate(20," + (i*20) + ")")
          
      item.append("rect")
        .attr("visibility", (d,i) -> if i > 0 then "visible" else "hidden")
        .attr("x", 0)
        .attr("y", 0)
        .attr("width", 20)
        .attr("height", 20)
        .attr("fill", (d,i) -> magnitudeColor(d))
          
      item.append("text")
        .attr("x", 28)
        .attr("y", 25)
        .attr("fill", "black")
        .text((d,i) -> 
          if (d >= 1e6)
            "$#{fmt(d / 1e6)} million"
          else
            "$#{fmt(d)}" 
          )



      

      #
      # Returns a function which returns coords for next node
      # each time when called.
      #
      placeNodesWithoutLocation = ((numNodesWithoutCoords)->
        count = 0

        hgap = 6
        vgap = 13
        w = (ffprintsScale *state.numMagnAttrs() + hgap)
        h = (ffprintsScale *ffprintsHeight + vgap)
        numInRow = Math.floor(width / w)
        numRows = Math.ceil(numNodesWithoutCoords / numInRow)

        # default node positions for nodes without coords
        ->
          col = (count % numInRow)
          row = Math.floor(count / numInRow)
          count++
          [
           w * col + w/2 + (width - w * numInRow)/2, 
           h * row + (height - (numRows-1) * h - vgap)
          ]
      )



      nodesWithFlows = data.nodes.filter(
        (node) -> 
          totals = node.totals?[state.selMagnAttrGrp]?[flowDirection]
          (if totals? then d3.max(totals) > 0 else 0)
      )

      nodesWithLocation = nodesWithFlows.filter (node) -> projectNode(node)?

      placeNext = placeNodesWithoutLocation(nodesWithFlows.length - nodesWithLocation.length)

      nodeData = nodesWithFlows.map ((node) -> 
        p = projectNode(node)
        hasLocation = p?
        if !hasLocation then p = placeNext()
        {
          x0: p[0]
          y0: p[1]
          x: p[0]
          y: p[1]
          gravity: {x: p[0], y: p[1]}
          #r: 20
          width: state.numMagnAttrs()
          height: ffprintsHeight
          data: node
          hasLocation: hasLocation
          # value: node
        }
      )

      # for force
      nodeDataWithLocation = nodeData.filter((n) -> n.hasLocation)

      # for node name labels
      nodeDataWithoutLocation = nodeData.filter((n) -> !n.hasLocation)




      nodesWithoutLocationLabels = box.nodes
        .selectAll("g.nodeLabel")
          .data(nodeDataWithoutLocation)
        .enter()
          .append("g")
            .attr("class", "nodeLabel")
            .attr('transform', (d) -> "translate(#{d.x},#{d.y})")


      nodesWithoutLocationLabels.append('text')
        .attr('x', 0)
        .attr('y', -ffprintsHeight/2)
        .attr('text-anchor', 'middle')
        .text((d) -> 
            label = d.data[conf.nodeIdAttr]
            if (label[0] == "("  and label[label.length-1] == ")")
              label = label.substr(1, label.length-2)
            if (label.length < 7) then label else label.substr(0, 5)+"..."
          )



      ## Nodes/ffprints
      nodes = box.nodes
        .selectAll('g.node')
          .data(nodeData)
        .enter()
          .append('g')
            .attr('class', 'node')
            .attr('transform', (d) -> "translate(#{d.x},#{d.y})")
          .sort((a,b) -> 
            # TODO: calc max vals in calcMaxTotalMagnitudes
            # and store in the nodesto improve performance
            d3.max(a.data.totals[state.selMagnAttrGrp][flowDirection]) >
            d3.max(b.data.totals[state.selMagnAttrGrp][flowDirection])
          )
          .append('g')
            .attr('class', 'node4scale')
            .attr('transform', 'scale('+ffprintsScale+')')

      ###
      if showNodeNames
        nodes.append('rect')
          .attr('class', 'plate')
          .attr('x', (d) -> -d.data[conf.nodeLabelAttr].length * 5/2)
          .attr('y', -8)
          .attr('width', (d) -> d.data[conf.nodeLabelAttr].length * 5)
          .attr('height', ffprintsHeight)
          .attr('fill', '#fff')
          .attr('opacity', 0.7)

        nodes.append('text')
          .attr('x', 0)
          .attr('y', 0)
          .attr('text-anchor', 'middle')
          .text((d) -> d.data[conf.nodeIdAttr])
      ###


      fingerprints = nodes
        .append('g')
          .attr('class', 'fingerprint')


      #setNodeHighlighted = () ->



      fingerprints.selectAll('rect.fp')
          .data(state.magnAttrs()).enter()
        .append('svg:rect')
          .attr('class', 'fp')
          .attr('x', (d, i) -> i*1 - state.numMagnAttrs()/2 )
          .attr('y', -ffprintsHeight/2)
          .attr('width', (d, i) -> if (i < state.numMagnAttrs() - 1) then 2 else 1)
          .attr('height', ffprintsHeight)
          .attr('fill', (d, i) -> 
            magnitudeColor(totalsValues(ndata(this))[i])
          )






      fingerprints.append('rect')
        .attr('class', 'fpframe')
        .attr('x', -state.numMagnAttrs()/2)
        .attr('y', -ffprintsHeight/2)
        .attr('width', state.numMagnAttrs())
        .attr('height', ffprintsHeight)
        .attr('fill', "#fff")
        .attr('fill-opacity', 0)   # for capturing events
        .attr('stroke-width', '1px')
        .attr('stroke', '#999')
        .on 'mousemove', (d) ->
          if tipsy.shown("fp")
            fpi = Math.floor((d3.event.clientX - $(this).offset().left)/ffprintHoverScale)
            fp = $("rect.fp", $(this).closest("g.fingerprint")).get(fpi)
            tipsy.show("fp", fp)

        .on 'mouseover', (d) ->

          p = $(this).closest("g.fingerprint").get(0)
          d3.select(p)
           .select('rect.fpframe')
            .transition()
              .duration(50)
              .attr("stroke", "#0166ce")



        .on 'click', (d) ->
          p = $(this).closest("g.fingerprint").get(0)
          pnode4scale = $(this).closest("g.node4scale").get(0)
          pnode = $(this).closest("g.node").get(0)
          pnodes = $(this).closest("g.nodes").get(0)


          ## states:  '' -> armed -> expanded

          $(p).data("state", "armed")

          nd = ndata(this)

          # save child index to insert in the previous position on mouseout
          pnode.indexInParent = Array.prototype.indexOf.call(pnodes.childNodes, pnode)
          pnodes.appendChild(pnode)

          d3.select(pnode)
            .transition()
            .each "end", ->
              if ($(p).data("state") == "armed")

                d3.select(pnode4scale)
                  .transition()
                    .duration(150)
                    .attr("transform", "translate(#{dx},#{dy}),scale(#{ffprintHoverScale})")
                    .each "end", ->
                      if ($(p).data("state") in ["armed", "expanded"])
                        tipsy.show("fp", fp)

                # Update opposite map ffprints
                sel = switch flowDirection
                    when "inbound" then { inbound: nd.code }
                    when "outbound" then { outbound: nd.code }
                originsMap.updateFfprints(sel)
                destsMap.updateFfprints(sel)

                $(p).data("state", "expanded")




          # If too close to the borders, translate so that it fits into the map
          { x: x, y: y, width: w, height: h } = d3.select(pnode4scale).data()[0]
          halfw = (w * ffprintHoverScale/2 + 2)
          halfh = (h * ffprintHoverScale/2 + 2)
          dx = Math.max(Math.min(0, width - (x + halfw)), halfw - x)
          dy = Math.max(Math.min(0, height - (y + halfh)), halfh - y)

          fpi = Math.floor((d3.event.clientX - $(this).offset().left)/ffprintsScale)
          fp = $("rect.fp", pnode4scale).get(fpi)



        .on 'mouseout', (d) ->
          p = $(this).closest("g.fingerprint").get(0)
          pnode4scale = $(this).closest("g.node4scale").get(0)
          pnode = $(this).closest("g.node").get(0)
          pnodes = $(this).closest("g.nodes").get(0)

          $(p).data("state", "")

          # restore previous child ordering
          if pnode.indexInParent?
            nextSibling = pnodes.childNodes[pnode.indexInParent]
            if nextSibling?
              pnodes.insertBefore(pnode, nextSibling)

          tipsy.hide("fp")

          # update opposite map ffprints
          originsMap.updateFfprints()
          destsMap.updateFfprints()


          d3.select(p)
            .select('rect.fpframe')
              .transition()
                .delay(100)
                .duration(20)
                .attr("stroke", "#999")
          d3.select(pnode4scale)
            .transition()
              .delay(100)
              .duration(100)
              .attr("transform", "scale(#{ffprintsScale})")
              .each "end", ->
                $(p).data("state", "")




      $('svg rect.fp').tipsy({ 
        gravity: 'n'
        html: true
        trigger: 'manual'
        #delayIn: 200
        #fade: true
        title: ->
          nd = ndata(this)
          magnAttr = d3.select(this).data()[0]
          value = totalsValueByAttr(nd, magnAttr)
          tooltipText(value, nd, magnAttr, flowDirection, state.selMagnAttrGrp)
      })


    mapChart.updateFfprints = (selection) ->
      isempty = !(selection?)  or  !(selection.inbound or selection.outbound)
      oppdir = oppositeFlowDirection(flowDirection)
      sel = selection?[flowDirection]
      oppsel = selection?[oppdir]

      if isempty
        # show everything
        fingerprints.selectAll('rect.fp')
          #.transition().duration(200)
          .attr('fill', (d, i) -> magnitudeColor(totalsValues(ndata(this))[i]))

        box.nodes.selectAll('g.node').attr("opacity", "1.0")

      else

        if oppsel?

          getMagnitudes = (nd) -> switch oppdir
            when "outbound" then flowsTree[oppsel]?[nd[conf.nodeIdAttr]]
            when "inbound"  then flowsTree[nd[conf.nodeIdAttr]]?[oppsel]

          # hide those for which there are no flows
          box.nodes.selectAll('g.node')
            .attr("opacity", (d, i) ->
              hasMagnitudes = getMagnitudes(d.data)?
              if (hasMagnitudes) then "1.0" else "0.0"
            )

          # update fingerprints to show flows to/from selected node
          fingerprints.selectAll('rect.fp')
            #.transition().duration(200)
            .attr('fill', (d, i) ->
              magnitudes = getMagnitudes(ndata(this))
              magnitudeColor(
                if magnitudes? then magnitudes[state.selMagnAttrGrp][i] else 0
              )
            )

        else
          # hide all but the selected one
          box.nodes.selectAll('g.node')
            .attr("opacity", (d, i) -> 
              if (d.data[conf.nodeIdAttr] == sel) then "1.0" else "0.1"
            )


    mapChart.useGeoNodePositions = ->
      force.stop()
      nodeDataWithLocation.forEach (a, i) -> 
        #p = projectNode(a.data)
        a.x = a.x0; a.y = a.y0; a.gravity = {x: a.x0, y: a.y0};


      mapSvgSelection.selectAll('g.node')
        .transition()
          .duration(500)
          .attr('transform', (d) -> "translate(#{d.x},#{d.y})")

      mapChart


    mapChart.useForce = ->
      if (force.nodes.length == 0)
        force
          .nodes(nodeDataWithLocation)
          .links([])
          .start()
      else
        force.resume()

      force
        .on "tick", (e) ->
          k = forceK #e.alpha
          kg = k * .01  # gravity (towards the node's original coords)
          spaceAround = 0.1  # proportion of size

          nodeDataWithLocation.forEach (a, i) ->

            #if (a.data.Name == "Various")
             # console.log a
            
            # Apply gravity forces.
            a.x += (a.gravity.x - a.x) * kg
            a.y += (a.gravity.y - a.y) * kg
            

            # Check borders
            ###
            if (a.x < a.r)
              dx = a.r - a.x 
              l = Math.sqrt(dx * dx)
              a.x += (l + dx*dx) / l * k

                     
            if (a.y < a.r)
              dy = a.r - a.y 
              l = Math.sqrt(dy * dy)
              a.y += (l + dy*dy) / l * k
            ###

            nodeDataWithLocation.slice(i + 1).forEach (b) ->
              # Check for collisions
              ###
              dx = (a.x - b.x)
              dy = (a.y - b.y)
              l = Math.sqrt(dx * dx + dy * dy)
              d = ffprintsScale * (a.width + b.width)/2

              if (l < d)
                l = (l - d) / l * k
                dx *= l
                dy *= l
                a.x -= dx
                a.y -= dy
                b.x += dx
                b.y += dy
              ###
              dx = (a.x - b.x)
              dy = (a.y - b.y)

              adx = Math.abs(dx)
              ady = Math.abs(dy)

              mdx = (1 + spaceAround) * ffprintsScale * (a.width + b.width)/2
              mdy = (1 + spaceAround) * ffprintsScale * (a.height + b.height)/2

              if (adx < mdx  &&  ady < mdy)       
                l = Math.sqrt(dx * dx)

                lx = (adx - mdx) / adx * k  # or l -> adx
                ly = (ady - mdy) / ady * k  # or l -> ady

                # choose the direction with less overlap
                if (lx > ly  &&  ly > 0)
                  lx = 0
                else if (ly > lx  &&  lx > 0)
                  ly = 0

                dx *= lx
                dy *= ly
                a.x -= dx
                a.y -= dy
                b.x += dx
                b.y += dy




          mapSvgSelection.selectAll("g.node")
            .attr('transform', (d) -> "translate(#{d.x},#{d.y})")


    mapChart.title = (_) -> if (!arguments.length) then title else title = _; mapChart

    mapChart.width = (_) -> if (!arguments.length) then width else width = _; mapChart

    mapChart.height = (_) -> if (!arguments.length) then height else height = _; mapChart

    mapChart.flowDirection = (_) -> if (!arguments.length) then flowDirection else flowDirection = _; mapChart

    mapChart


  ############################             ############################ 
  ############################ ffprintsMap ############################ 
  ############################             ############################ 













  fromInputDataTotalsToNodeTotals = ->
    # supply the nodes with the totals data so that it 
    # corresponds to the case when flows are supplied as input

    originTotals = d3.nest()
      .key((d) -> d[conf.flowOriginAttr])
      .rollup((d) -> d[0])
      .map(data.originTotals)

    destTotals = d3.nest()
      .key((d) -> d[conf.flowDestAttr])
      .rollup((d) -> d[0])
      .map(data.destTotals)

    for node in data.nodes
      nodeId = node[conf.nodeIdAttr]
      totals = {}
      for attrGroup, props of conf.flowMagnAttrs
        totals[attrGroup] =
          outbound: []
          inbound: []
        for attr, i in props.attrs
          # TODO: different totals for different attrGroup should be used
          totals[attrGroup].outbound[i] = +originTotals[nodeId]?[attr] ? 0
          totals[attrGroup].inbound[i] = +destTotals[nodeId]?[attr] ? 0

      node.totals = totals



  
  #####################################################################
  ##                   Chart construction entry
  #####################################################################

  chart = (selection) ->

    ####################### Data preparation #########################
    data = selection.datum()
    
    state = 
      selMagnAttrGrp : d3.keys(conf.flowMagnAttrs)[0]
      magnAttrs : (i) ->
        magnAttrs = conf.flowMagnAttrs[state.selMagnAttrGrp]
        if (i?) then magnAttrs.attrs[i] else magnAttrs.attrs
      numMagnAttrs : -> state.magnAttrs().length
      maxTotalMagnitude : -> state.totalsMax[state.selMagnAttrGrp].max


    if data.originTotals  and  data.destTotals 
      fromInputDataTotalsToNodeTotals()
    else if data.flows
      provideNodesWithTotals(data, conf)

      flowsTree = d3.nest()
        .key((d) -> d[conf.flowOriginAttr])
        .key((d) -> d[conf.flowDestAttr])
        .rollup((d) -> 
          groups = {}
          for attrGrp, attrs of conf.flowMagnAttrs
            groups[attrGrp] = attrs.attrs.map((attr) -> +d[0][attr])
          groups
        )
        .map(data.flows)

    else
      throw new Error("Either data.flows or data.originTotals must be specified")


    state.totalsMax = calcMaxTotalMagnitudes(data, conf)


    #totalsValues = makeNodeTotalsValuesList(data.nodes, state.selMagnAttrGrp)
    # TODO: configurable color scale

    maxTotal = state.maxTotalMagnitude()
    #colorScaleLimits = chroma.limits(totalsValues, "k-means", 10)
    #colorScaleLimits = [0,  1e06, 1e7, 1e8, 5e8, 1e9, 1e10, maxTotal
    colorScaleLimits = 
      [0, 10e6, 50e6, 100e6, 500e6, 1000e6, 5000e6, 10000e6, 25000e6, 50000e6, maxTotal]

    magnitudeColor = ( -> 
      scale = new chroma.ColorScale
          #colors: ['#F7E1C5', '#6A000B'], mode: 'hcl',
          colors: chroma.brewer.OrRd
          limits: colorScaleLimits
      (value) -> scale.getColor(value)
    )()


    ## Create Origins and Dests maps
    ffprintsMapWidth = ffprintsChartWidth * 0.49
    ffprintsScale = ffprintsMapWidth / (state.numMagnAttrs()*20)
    ffprintsMapHorizGap = ffprintsChartWidth * 0.01 * 2
    ffprintsMapHeight = ffprintsChartHeight

    originsMap = ffprintsMap()
      .title(mapTitles[0])
      .width(ffprintsMapWidth)
      .height(ffprintsMapHeight)
      .flowDirection("outbound")

    destsMap = ffprintsMap()
      .title(mapTitles[1])
      .width(ffprintsMapWidth)
      .height(ffprintsMapHeight)
      .flowDirection("inbound")


    ## Create SVG
    svg = selection.append("svg")
          .attr("width", ffprintsChartWidth)
          .attr("height", ffprintsChartHeight)
          .attr("class", "ffprints")

    svg.append("g")
        .attr("class", "ffprintsMap")
        .attr("transform", "translate(0,0)")
      .datum(data)
        .call(originsMap)
    
    
    svg.append("g")
        .attr("class", "ffprintsMap")
        .attr("transform", "translate(#{ffprintsMapWidth+ffprintsMapHorizGap},0)")
      .datum(data)
        .call(destsMap)


    ###
    createFfprintsMap(
      ,
      state, data, width/2, height,
      "outbound")

    
    createFfprintsMap(
      svg.append("g")
        .attr("class", "ffprintsMap")
        .attr("transform", "translate(#{width/2},0)"),
      state, data, width/2, height,
      "inbound")
    ###




  chart.useGeoNodePositions = ->
    [originsMap, destsMap].forEach (map) -> map.useGeoNodePositions()

  chart.useForce = ->
    [originsMap, destsMap].forEach (map) -> map.useForce()


  chart.forceK = (_) -> if (!arguments.length) then forceK else forceK = _; this.useForce(); chart

  chart.width = (_) -> if (!arguments.length) then ffprintsChartWidth else ffprintsChartWidth = _; chart

  chart.height = (_) -> if (!arguments.length) then ffprintsChartHeight else ffprintsChartHeight = _; chart

  chart.mapTitles = (_) -> if (!arguments.length) then mapTitles else mapTitles = _; chart

  chart.flowOriginAttr = (_) ->
    if (!arguments.length) then conf.flowOriginAttr else conf.flowOriginAttr = _; chart

  chart.flowDestAttr = (_) ->
    if (!arguments.length) then conf.flowDestAttr else conf.flowDestAttr = _; chart

  chart.nodeIdAttr = (_) ->
    if (!arguments.length) then conf.nodeIdAttr else conf.nodeIdAttr = _; chart

  chart.nodeLabelAttr = (_) ->
    if (!arguments.length) then conf.nodeLabelAttr else conf.nodeLabelAttr = _; chart

  chart.flowMagnitudeAttrs = (_) ->
    if (!arguments.length) then conf.flowMagnAttrs else conf.flowMagnAttrs = _; chart

  chart.latAttr = (_) -> if (!arguments.length) then conf.latAttr else conf.latAttr = _; chart

  chart.lonAttr = (_) -> if (!arguments.length) then conf.lonAttr else conf.lonAttr = _; chart

  chart.tooltipText = (_) -> if (!arguments.length) then tooltipText else tooltipText = _; chart

  chart

