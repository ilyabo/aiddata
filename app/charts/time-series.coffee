@include = ->

  @coffee '/coffee/charts/time-series.js' : ->

    this.timeSeriesChart = ->

      title = ""
      width = 300
      height = 200
      dateProp = "date"
      valueProp = "value"
      interpolate = null # default is "monotone"
      showDots = true
      dotRadius = 2
      xticks = yticks = null
      marginLeft = 40
      marginTop = 28
      marginRight = 8
      ytickFormat = d3.format(",.0f")
      showLegend = false
      indexedMode = false
      legendWidth = 150
      legendHeight = null  # will be set to height by default
      legendItemHeight = 15
      legendItemWidth = 80
      legendMarginLeft = 12
      legendMarginTop = 0
      #properties = null
      showRule = false
      showYAxis = true
      ruleDate = null
      valueDomain = dateDomain = null
      hideRuleOnMouseout = true

      eventListeners = {}

      propColors = d3.scale.category10().range()

      # borrowed from chroma.js: chroma.brewer.Set1
      # ["#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00", "#ffff33", "#a65628", "#f781bf", "#999999"]
      # Set3 (more pastel colors):
      #  ["#8dd3c7", "#ffffb3", "#bebada", "#fb8072", "#80b1d3", "#fdb462", "#b3de69", "#fccde5", "#d9d9d9", "#bc80bd", "#ccebc5", "#ffed6f"]


      # data is expected to be in the following form:
      # [{date:Date, inbound:123, outbound:321}, ...]
      #
      # either:  [ { date:Date, value:123 },  { date:Date, value:123 }, ... ] for one property
      # or { 
      #    prop1: [ { date:Date, value:123 },  { date:Date, value:123 }, ... ]
      #    prop2: [ { date:Date, value:123 },  { date:Date, value:123 }, ... ]
      # }

      chart = (selection) -> init(selection)

      chart.title = (_) -> if (!arguments.length) then title else title = _; chart

      chart.dateProp = (_) -> if (!arguments.length) then dateProp else dateProp = _; chart

      chart.valueProp = (_) -> if (!arguments.length) then valueProp else valueProp = _; chart

      chart.dateDomain = (_) -> if (!arguments.length) then dateDomain else dateDomain = _; chart

      chart.valueDomain = (_) -> if (!arguments.length) then valueDomain else valueDomain = _; chart

      chart.actualDateDomain = (_) -> xscale?.domain().slice()

      chart.actualValueDomain = (_) -> yscale?.domain().slice()

      # which properties to visualize
      #chart.properties = (_) -> if (!arguments.length) then properties else properties = _; chart

      chart.width = (_) -> if (!arguments.length) then width else width = _; chart

      chart.showDots = (_) -> if (!arguments.length) then showDots else showDots = _; chart

      chart.dotRadius = (_) -> if (!arguments.length) then dotRadius else dotRadius = _; chart

      chart.xticks = (_) -> if (!arguments.length) then xticks else xticks = _; chart

      chart.yticks = (_) -> if (!arguments.length) then yticks else yticks = _; chart

      chart.height = (_) -> if (!arguments.length) then height else height = _; chart

      chart.marginLeft = (_) -> if (!arguments.length) then marginLeft else marginLeft = _; chart

      chart.marginTop = (_) -> if (!arguments.length) then marginTop else marginTop = _; chart

      chart.marginRight = (_) -> if (!arguments.length) then marginRight else marginRight = _; chart

      chart.interpolate = (_) -> if (!arguments.length) then interpolate else interpolate = _; chart

      chart.ytickFormat = (_) -> if (!arguments.length) then ytickFormat else ytickFormat = _; chart

      chart.showLegend = (_) -> if (!arguments.length) then showLegend else showLegend = (if _ then true else false); chart

      chart.indexedMode = (_) -> if (!arguments.length) then indexedMode else indexedMode = (if _ then true else false); chart

      chart.showRule = (_) -> if (!arguments.length) then showRule else showRule = (if _ then true else false); chart

      chart.hideRuleOnMouseout = (_) -> if (!arguments.length) then hideRuleOnMouseout else hideRuleOnMouseout = (if _ then true else false); chart

      chart.showYAxis = (_) -> if (!arguments.length) then showYAxis else showYAxis = (if _ then true else false); chart

      chart.legendWidth = (_) -> if (!arguments.length) then legendWidth else legendWidth = _; chart

      chart.legendHeight = (_) -> if (!arguments.length) then legendHeight else legendHeight = _; chart


      chart.propColors = (_) -> if (!arguments.length) then propColors else propColors = _; chart

      # Supported events: "rulemove", "mouseover", "mouseout", "click"
      chart.on = (eventName, listener) -> 
        (eventListeners[eventName] ?= []).push(listener); chart

      fire = (eventName, args...) -> 
        listeners = eventListeners[eventName]
        if listeners?
          l.apply(chart, args) for l in listeners


      chart.moveRule = (date) ->
        if date isnt ruleDate
          rule = vis.selectAll("line.rule")
          if date?
            rule.attr("visibility", "visible")
              .attr("x1", xscale(date))
              .attr("x2", xscale(date))
          else if hideRuleOnMouseout
            rule.attr("visibility", "hidden")

          ruleDate = date

          fire("rulemove", date)


      propData = (data) -> (if (data instanceof Array) then { value: data } else data)


      chart.update = (selection) ->
        data = propData(selection.datum())
        vis.datum(data)

        updateScalesAndAxes(data)

        # vis.selectAll("path.line").remove()
        # vis.selectAll("circle.dot").remove()

        vis.selectAll("g.prop").remove()
        vis.selectAll("g.legend").remove()



        #enter(data)
        update(data)


      # enter = (data) ->
      #   # dates = data.map (d) -> d[dateProp]

      #   for prop, pi in propsOf(data)
      #     line = lineDrawer(prop)

      #     g = vis.append("g")
      #       .attr("class", "prop #{prop}")

      #     g.append("path")
      #       .attr("class", "line")
      #       .attr("d", line)
      #       .attr("stroke", propColors[pi % propColors.length])

      #     # if showDots
      #     #   dots = g.selectAll("circle.dot")
      #     #     .data(dates.filter (d) -> (not isNaN(y(nested[d]?[prop]))))

      #     #   dots.enter().append("circle")
      #     #     .attr("class", "dot")
      #     #     .attr("r", dotRadius)


      yscaleForProp = (prop) -> if indexedMode then yscales[prop] else yscale

      picolor = (pi) -> propColors[pi % propColors.length]



      update = (data, duration = updateDuration) ->
        
        data = propData(data)

        pi = -1
        for prop, entries of data
          pi++

          # necessary for findValuesWithTheClosestDate
          entries.sort((a,b) -> d3.ascending(a[dateProp]?.getTime(), b[dateProp]?.getTime()))

          y = yscaleForProp(prop)

          color = picolor(pi)

          g = vis.append("g").datum(entries)
            .attr("class", "prop")

          line = d3.svg.line()
            .x((d) -> xscale(d[dateProp]))
            .y((d) -> y(d[valueProp]))
            .defined((d) -> d[valueProp]? and !isNaN(d[valueProp]))
            .interpolate(interpolate)


          g.append("path")
            .attr("stroke", color)
            .attr("class", "line")
            .attr("d", line)


          # g = vis.select("g.#{prop}")
          
          # g.select("path")
          #     #.transition()
          #      # .duration(duration)
          #     .attr("d", line)


          if showDots
            dots = g.selectAll("circle.dot").data(entries)

            dots.enter().append("circle")
              .attr("class", "dot")
              .attr("r", dotRadius)
              .attr("stroke", color)

            dots
              .attr("cx", (d) -> xscale(d[dateProp]))
              .attr("cy", (d) -> y(d[valueProp]))

            dots.exit().remove()


        if showLegend

          props = d3.keys(data)

          legend = vis.append("g")
            .attr("class", "legend")
            .attr("transform", "translate(#{width - marginLeft + legendMarginLeft},#{legendMarginTop})")


          colSize = Math.floor(legendHeight/legendItemHeight)

          item = legend.selectAll("g.legendItem")
            .data(props)
          .enter().append("g")
            .attr("class", "legendItem")
            .attr("transform", (d, i) -> 
              col = Math.floor(i/colSize) 
              row = i % colSize
              "translate(#{col * legendItemWidth},#{row * legendItemHeight})")

          item.append("rect")
            .attr("x", 0)
            .attr("y", 0)
            #.attr("rx", 2)
            #.attr("ry", 2)
            .attr("width", 10)
            .attr("height", 2)
            .attr("fill", (d, pi) -> picolor(pi))

          item.append("text")
            .attr("dominant-baseline", "central")
            .attr("x", 13)
            .attr("y", 1)
            .text((d) -> d)
            




      updateDuration = 1300

      w = h = null   # width and height
      xscale = yscale = null  # scales
      xAxis = yAxis = null
      yscales = {}  # y scales by property for indexedMode
      yaxes = {} # for indexedMode
      svg = vis = null


      # returns an object with values for each property
      # on the closest date to the given date
      findValuesWithTheClosestDate = do ->
        time = (v) -> v?[dateProp].getTime()
        bisector = d3.bisector(time).right
        
        find = (values, t) ->
          i = bisector(values, t)
          
          left = values[i - 1]
          right = values[i]

          if left?  and (not(right?) or (t - time(left) < time(right) - t))
            left
          else
            right

        (data, date) ->
          t = date.getTime()

          # closest for each prop
          closest = ([prop, find(values, t)] for prop,values of data).filter((d) -> d[1]?)

          # group by date and sort by closeness
          byDate = d3.nest()
            .key((d) -> d[1][dateProp].getTime())
            .sortKeys((a, b) -> d3.ascending(Math.abs(t - a), Math.abs(t - b)))
            .entries(closest)

          if byDate[0]?
            byProp = d3.nest()
              .key((d) -> d[0])
              .rollup((arr) -> arr[0][1])
              .map(byDate[0].values)
          else
            null


      isNumber = (obj) -> (obj is +obj) or toString.call(obj) is '[object Number]'



      createAxis = (orient, scale, numTicks, tickSize = -w) ->
       d3.svg.axis()
        .ticks(numTicks)
        .scale(scale)
        .orient(orient)
        .tickFormat(ytickFormat)
        .tickSize(tickSize, 0, 0)


      updateIndex = ->
        index = svg.select("g.index")
        
        index.select("text.title").text("max")

        index.selectAll("g.item text")
          .text((prop, i) -> ytickFormat(yscales[prop].domain()[1]))


      updateScalesAndAxes = (data) ->

        vis.selectAll("g.y.axis").remove()
        svg.selectAll("g.index").remove()

        if indexedMode
          # create a separate scale for each prop
          yscales = {}
          yaxes = {}
          for prop, values of data
            y = d3.scale.linear().range([h, 0])
            extent = d3.extent(values, (d) -> d[valueProp])
            y.domain([ Math.min(0, extent[0]),  extent[1] ])
            yscales[prop] = y
            yaxes[prop] = createAxis("left", y, 2, 0)
      
          index = svg.append("g")
            .attr("class", "index")

          index.append("text")
            .attr("class", "title")
            .attr("dominant-baseline", "central")
            .attr("x", 7)
            .attr("y", 7)

          g = index.selectAll("g.item")
            .data(d3.keys(data))
          .enter().append("g")
            .attr("class", "item")
            .attr("transform", (prop, i) -> "translate(3, #{15+i*15})")
          
          g.append("text")
            .attr("dominant-baseline", "central")
            .attr("x", 12)
            .attr("y", 6)

          g.append("rect")
            .attr("fill", (prop, i) -> picolor(i))
            .attr("y", 5)
            .attr("width", 10)
            .attr("height", 2)

          updateIndex()



          if showYAxis
            pi = 0
            for prop, values of data
              dx = -25 * pi  #(if (pi % 2 is 0) then (-25*pi/2) else (w + 25*pi/2))
              vis.append("g")
                .attr("class", "y axis")
                .attr("transform", "translate(#{dx},0)")
                .call(yaxes[prop])
              pi++


        else
          yscale = d3.scale.linear().range([h, 0])

          if valueDomain?
            yscale.domain(valueDomain)
          else
            valueExtents = (d3.extent(values, (d) -> d[valueProp]) for prop, values of data)
            valueExtent = [ d3.min(valueExtents, (d) -> d[0]), d3.max(valueExtents, (d) -> d[1]) ] 
            yscale.domain([ Math.min(0, valueExtent[0]),  valueExtent[1] ])

          if showYAxis
            yAxis = createAxis("left", yscale, yticks ? 5)

            vis.append("g")
              .attr("class", "y axis")
              .call(yAxis)


        if dateDomain?
          xscale.domain(dateDomain)
        else
          dateExtents = (d3.extent(values, (d) -> d[dateProp]) for prop, values of data)
          dateExtent = [ d3.min(dateExtents, (d) -> d[0]), d3.max(dateExtents, (d) -> d[1]) ] 
          xscale.domain([ dateExtent[0],  dateExtent[1] ])


        vis.selectAll(".x.axis").call(xAxis)






      init = (selection) -> 

        element = selection
        data = propData(selection.datum())

        if svg?
          chart.update(selection)
          return


        margin = {top: marginTop, right: marginRight, bottom: 14, left: marginLeft}

        legendHeight ?= height - margin.top - margin.bottom

        w = width - margin.left - margin.right
        h = height - margin.top - margin.bottom



        svg = element.append("svg")
            .attr("width", w + margin.left + margin.right + 
                          (if showLegend then legendWidth else 0))
            .attr("height", 
              Math.max(h + margin.top + margin.bottom, legendHeight + margin.top + margin.bottom))

        svg.append("text")  
          .attr("class", "title")
          .attr("x",  margin.left + w/2)
          .attr("y", 20)
          .attr("text-anchor", "middle")
          .text(title)

        vis = svg.append("g")
            .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

        vis.append("rect")
          .attr("class", "background")
          .attr("x", 0)
          .attr("y", 0)
          .attr("width", w)
          .attr("height", h)

        xscale = d3.time.scale().range([0, w])          

        xAxis = d3.svg.axis()
          .scale(xscale)
          .ticks(xticks ? Math.max(1, Math.round(w/30)))
          .orient("bottom")
          .tickSize(3, 0, 0)

        updateScalesAndAxes(data)



        vis.append("g")
          .attr("class", "x axis")
          .attr("transform", "translate(0," + h + ")")
          .call(xAxis)

        ruleLine = vis.append("line")
          .attr("visibility", if hideRuleOnMouseout then "hidden" else "visible")
          .attr("class", "rule")
          .attr("y1", -3)
          .attr("y2", h + 6)

        ###
        updateYear = ->
          vis.selectAll("line.rule")
            .attr("x1", x(data[state.selAttrIndex][dateProp]))
            .attr("x2", x(data[state.selAttrIndex][dateProp]))

        updateYear()
        $(ruleLine[0]).bind("updateYear", updateYear)
        ###

        #enter(data)
        update(data, 0)

        foreground = vis.append("rect")
          .attr("class", "foreground")
          .attr("x", 0)
          .attr("y", 0)
          .attr("width", w)
          .attr("height", h + margin.bottom)
          .on("mouseover", -> fire "mouseover", svg)
          .on("click", -> fire "click", svg)
          .on("mouseout", -> 
            fire("mouseout", svg)
          )




        if showRule

          foreground
            .on("mousemove", ->
              date = xscale.invert(d3.mouse(foreground[0][0])[0])
              closest = findValuesWithTheClosestDate(propData(vis.datum()), date)
              if closest?
                d = closest[d3.keys(closest)[0]]
                chart.moveRule(d[dateProp])

                if indexedMode
                  index = svg.select("g.index")
                  
                  index.select("text.title")
                    .text(xscale.tickFormat()(d[dateProp]))

                  index.selectAll("g.item text")
                    .text (prop, i) -> 
                      v = closest[prop]?[valueProp]
                      if v? then ytickFormat(v) else ""


            ).on("mouseout", ->

              chart.moveRule(null)
              if indexedMode
                updateIndex()

            )
          

      
      chart


