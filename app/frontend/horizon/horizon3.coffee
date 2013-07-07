@include = ->

  @coffee '/coffee/horizon3.js' : -> 

    dateFormat = d3.time.format("%Y")
    timeInterval = d3.time.year

     
    horizonChart = ->

      mode = "mirror"
      showLegend = true
      bandHeight = 20
      bandWidth = 350
      valueFormat = d3.format(",.0f")
      interval = d3.time.year
      keyGet = (d) -> d.key
      labelGet = (d) -> d.name
      filterButtons = true
      indicatorButtons = false

      title = ""
      eventListeners = {}
      useLog10BandSplitting = true
      numBands = 4
      valueExtent = null
      timeExtent = null

      # colors = ["#08519c","#3182bd","#6baed6","#bdd7e7",
      #           "#bae4b3","#74c476","#31a354","#006d2c"]

      negativeColorRange = [d3.hcl(-139.23, 6.94, 94.62), d3.hcl(-60.84, 60.56, 10)]
      positiveColorRange = [d3.hcl(137.27, 12.24, 85.88), d3.hcl(147.32, 35.76, 10)]

      chart = (selection) -> init(selection)
      chart.title = (_) -> if (!arguments.length) then title else title = _; chart
      chart.mode = (_) -> if (!arguments.length) then mode else mode = _; chart
      chart.interval = (_) -> if (!arguments.length) then interval else interval = _; chart
      chart.useLog10BandSplitting = (_) -> if (!arguments.length) then useLog10BandSplitting else useLog10BandSplitting = _; chart
      chart.showLegend = (_) -> if (!arguments.length) then showLegend else showLegend = _; chart
      chart.valueFormat = (_) -> if (!arguments.length) then valueFormat else valueFormat = _; chart
      chart.key = (_) -> if (!arguments.length) then keyGet else keyGet = (if _ instanceof Function then _ else (d) -> d[_]) ; chart
      chart.label = (_) -> if (!arguments.length) then labelGet else labelGet = (if _ instanceof Function then _ else (d) -> d[_]) ; chart
      chart.valueExtent = (_) -> if (!arguments.length) then valueExtent else valueExtent = _; chart
      chart.timeExtent = (_) -> if (!arguments.length) then timeExtent else timeExtent = _; chart
      chart.filterButtons = (_) -> if (!arguments.length) then filterButtons else filterButtons = _; chart
      chart.indicatorButtons = (_) -> if (!arguments.length) then indicatorButtons else indicatorButtons = _; chart
      chart.negativeColorRange = (_) -> if (!arguments.length) then negativeColorRange else negativeColorRange = _; chart
      chart.positiveColorRange = (_) -> if (!arguments.length) then positiveColorRange else positiveColorRange = _; chart

      # Supported events: "applyFilter", "ruleMoved"
      chart.on = (eventName, listener) -> 
        (eventListeners[eventName] ?= []).push(listener); chart


      fire = (eventName, thisObj, args...) -> 
        listeners = eventListeners[eventName]
        if listeners?
          l.apply(thisObj, args) for l in listeners

      chart.showRuleAt = (t) ->
        unless t?
          parent.select(".rule").style("display", "none")
        else
          bands = parent.select("div.bands")
          r = bands[0][0].getBoundingClientRect()
          cr = bands.select("canvas")[0][0].getBoundingClientRect()
          pos = tscale(t) + cr.left + Math.floor(stepWidth/2)
          clip = "rect("+(r.top - 5)+"px,"+r.right+"px,"+Math.round(r.bottom)+"px,0px)"
          parent.select(".rule")
            .style("display", "block")
            .style("clip", clip)
            .style("left", pos + "px")

      colorsBetween = (start, end, numColors) ->
        scale = d3.scale.linear()
          .range([start, end])
          .domain([1, numColors])
          .interpolate(d3.interpolateHcl)

        (scale(i) for i in [1..numColors])

      pow10 = (n) ->
        v = 1
        if n > 0
          v *= 10 for i in [1..n]; return v
        else
          v /= 10 for i in [1..-n]; return v



      colors = []

      parent = null
      width = bandWidth
      height = bandHeight
      tscale = d3.time.scale().range([0, width])
      yscale = d3.scale.linear()#.nice() #.interpolate(d3.interpolateRound)
      #m = colors.length >> 1   # number of bands

      
      nextCheckboxId = 1

      numSteps = stepWidth = null
      xAxis = null

      init = (selection) ->

        colors = 
          colorsBetween(negativeColorRange[1], negativeColorRange[0], numBands)
          .concat(
            colorsBetween(positiveColorRange[0], positiveColorRange[1], numBands)
          )

        data = selection.datum()
        parent = selection


        update = not selection.select("svg").empty()

        unless update
          parent
            .attr("class", "horizonChart")
            #.attr("style", "width:#{bandWidth}px")


          if title?.length > 0
            parent.append("div").attr("class", "viewTitle").text(title)

          parent.append("div").attr("class", "legend")  if showLegend


          if indicatorButtons or filterButtons
            controls = parent.append("div")
              .attr("class", "btn-toolbar controls")

          parent.append("div").attr("class", "top axis")
          
          bandsDiv = parent.append("div")
            .attr("class", "bands")

          parent.append("div")
              .attr("class", "line rule")
              .style("position", "fixed")
              .style("top", 0)
              .style("right", 0)
              .style("bottom", 0)
              .style("width", "1px")
              .style("pointer-events", "none")


          if indicatorButtons
            compareBtns = controls.append("div")
              .attr("class", "btn-group")

            compareBtns.append("button")
              .attr("class", "btn btn-mini indicator")
              .text("Indicators")
              .on "click", -> fire "loadIndicator", chart

            compareBtns.append("button")
              .attr("class", "btn btn-mini")
              .attr("title", "Clear indicator")
              .html("&times;")
              .on "click", -> fire "clearIndicator", chart


          if filterButtons
            filterBtns = controls.append("div")
              .attr("class", "btn-group filter")

            filterBtns.append("button")
              .attr("class", "btn btn-mini filter")
              .text("Apply filter")
              .on "click", -> 
                selected = []
                parent.selectAll("input")
                  .each (d) -> 
                    that = d3.select(this)
                    if that.property("checked")
                      selected.push keyGet(d)
                      # that.property("checked", false)

                if selected.length > 0
                  fire "applyFilter", chart, selected

            filterBtns.append("button")
              .attr("class", "btn btn-mini")
              .attr("title", "Clear filter")
              .html("&times;")
              .on "click", -> 
                fire "applyFilter", chart, null
                parent.selectAll("input").property("checked", false)




        if valueExtent?
          extent = valueExtent
        else
          extents = (d.values.extent for d in data)
          extent = [ d3.min(extents, (d) -> d[0]), d3.max(extents, (d) -> d[1]) ]

        showNegativeLegend = extent[0] < 0
        max = Math.max(-extent[0], extent[1])
        yscale.domain [0, max]

        
        if timeExtent?
          textent = timeExtent
        else
          textents = (d.values.timeExtent for d in data)
          textent = [ d3.min(textents, (d) -> d[0]), d3.max(textents, (d) -> d[1]) ]

        tscale.domain(textent)
        numSteps = Math.max(1, interval.range.apply(this, textent).length)
        stepWidth = Math.ceil(width / numSteps)


        unless update
          xAxis = d3.svg.axis()
            .ticks(12)
            .orient("top")
            .tickSize(3, 0, 0)
            .scale(tscale)

          parent.select("div.top.axis")
            .append("svg")
              .attr("height", 20)
              .attr("width", bandWidth + 40)
              .append("g")
                .attr("class", "x axis")
                .attr("transform", "translate(20,20)")
                .call(xAxis)


        parent.selectAll(".x.axis").call(xAxis)



        horizons = parent.select("div.bands").selectAll("div.horizon")
            .data(data, (d) -> keyGet(d))

        horizonsEnter = horizons.enter()
          .append("div")
            .attr("class", "horizon")

        if filterButtons
          horizonsEnter.on("click", (d) -> 
              #if d3.event.target?.type is "canvas"
              tag = d3.event.target?.tagName
              if tag is "CANVAS"
                d3.select(this).select("input")[0][0].checked = true
                parent.select("button.filter")[0][0].click()
              else
                unless tag is "INPUT"
                  d3.select(this).select("input")[0][0].click()
            )


        item = horizonsEnter.append("span")
          .attr("class", "item")

        if filterButtons
          item.append("input")
            .attr("value", (d) -> keyGet(d))
            .attr("type", "checkbox")

        item.append("label")
          .attr("class", "title")
          .html((d) -> shorten(labelGet(d), 25, true))
          # .on "click", ->  d3.select(this.parentElement).select("input")[0][0].click()

        horizonsEnter.append("canvas")
          .attr("width", width)
          .attr("height", height)
          .attr("data-key", (d) -> keyGet(d))
          .on("mousemove", (d) ->
            # otherwise, d for the first horizon is not properly set for some reason
            d = this.parentElement.__data__
            left = this.getBoundingClientRect().left
            t = interval(tscale.invert(d3.event.clientX - left))

            chart.showRuleAt t
            fire "ruleMoved", this, t

            dobj = do -> 
              tt = t.getTime()
              if d.values?
                for obj in d.values
                  if interval(obj.date).getTime() is tt
                    return obj
              return null

            if dobj
              fire "focusOnItem", chart, d, dobj, t
            else
              fire "focusOnItem", chart, null
          )
          .on("mouseout", ->
            chart.showRuleAt null
            fire "ruleMoved", this, null
            fire "focusOnItem", chart, null
          )




        parent.select("div.bands").selectAll("div.horizon")
          .sort((a, b) -> d3.descending(a.values.extent[1], b.values.extent[1]))


        horizons.exit().remove()


        if update
          parent.select("div.legend").select("svg").remove()          


        maxOrdMagn = Math.ceil(log10(max))
        m = numBands


        # automatically switch to the linear scale when there is no large difference
        # between orders of magnitudes
        useLog10Bands = (useLog10BandSplitting  and  maxOrdMagn >= m)


        if showLegend then do ->
          n = if showNegativeLegend then 2*m else m


          parent.select("div.legend")
            .append("svg")
              .attr("width", maxOrdMagn*8 + (if useLog10Bands then 20 else 40))
              .attr("height", n * 15 + 15)
            .append("g")
              .attr("class", "content")
              .attr("transform", "translate(0, 10)")

          legend = parent.select("div.legend").select("g.content")

          #items = bands.map (band) -> [ i, [start, end] ] = band; [ colors[m + i - 1], end ]

          legendItem = legend.selectAll("g.item")
            .data(
              if showNegativeLegend
                ["white"].concat colors
              else
                ["white"].concat colors.slice(m, 2*m)
            )
            .enter()
              .append("g")
                .attr("class", "item")
                .attr("transform", (d, i) -> 
                  "translate(0, #{(n - i) * 15})")

          legendItem.append("rect")
            .attr("x", 5)
            .attr("y", 0)
            .attr("width", 15)
            .attr("height", 15)
            .attr("fill", (d, i) -> d)

          legendItem.append("text")
            .attr("dominant-baseline", "central")
            .attr("x", 25)
            .attr("y", 0)

        
        

        if useLog10Bands  


          # TODO: find min nonzero abs value in the data and uniformly 
          # split the interval between the min and max orders of magnitude 
          # (not always by 10, but possibly by 100 or 1000)


          bands = (for i in [1..m]
            magn = maxOrdMagn + (i - m)
            start = (if i is 1 then 0 else pow10(magn - 1))
            end = pow10(magn)
            [ i - 1, [ start, end ] ]
          )

          # colorScale = d3.scale.threshold()
          # colorScale.range(colors)
          # colorScale.domain(
          #   for i in [-m..-1].concat([1..m])
          #     magn = maxOrdMagn + (Math.abs(i) - m)
          #     if i == 0
          #       0
          #     else if i < 0
          #       -pow10(magn)
          #     else
          #       pow10(magn)                
          # )



          parent.select("div.legend").selectAll("g.item").select("text")
            .text((d, i) ->
              if showNegativeLegend
                if i < m
                  valueFormat -bands[m - 1 - i][1][1]
                else if i == m
                  valueFormat 0
                else
                  valueFormat bands[i - m - 1][1][1]
              else
                if i > 0
                  valueFormat bands[i - 1][1][1]
                else
                  valueFormat 0
            )


          # returns array [ band, [startLimit, endLimit] ] 
          #                 band is between 0 and m-1
          valueToBand = 
            (value) ->
              v = Math.abs(value)
              for i in [m .. 2]
                limits = bands[i - 1][1] 
                if v >= limits[0]
                  return bands[i - 1]

              return bands[0]


        else


          parent.select("div.legend").selectAll("g.item").select("text")
            .text((d, i) ->
              domain = yscale.domain()

              v = if showNegativeLegend
                if i < m
                  - (max / m) * (m - i)
                else if i == m
                  0
                else
                  (max / m) * (i - m)
              else
                if i > 0
                  (max / m) * (i)
                else
                  0

              valueFormat v
            )





        parent.selectAll("div.horizon").each (data) ->
          data = data.values

          horizon = d3.select(this)

          ys = yscale.copy()
          
     

          canvas = horizon.select("canvas").node().getContext("2d")
          canvas.save()

          i0 = 0

          # clear for the new data
          canvas.clearRect i0, 0, width - i0, height

          if useLog10Bands


            for d in data
              t = Math.round(tscale(d.date))
              v = d.value
              
              [band, limits] = valueToBand(v)

              if v < 0     # negative

                # draw previous band
                if band > 0
                  canvas.fillStyle = colors[m - 1 - (band - 1)]
                  canvas.fillRect t, 0, stepWidth, height

                ys.range [0, height]
                ys.domain limits 

                canvas.fillStyle = colors[m - 1 - band]
                y1 = ys(-v)

                if mode is "offset"
                  canvas.fillRect t, 0, stepWidth, y1
                else
                  canvas.fillRect t, height - y1, stepWidth, y1
                

              else

                # draw previous band
                if band > 0
                  canvas.fillStyle = colors[m + band - 1]
                  canvas.fillRect t, 0, stepWidth, height

                # draw this band
        
                ys.range [0, height]
                ys.domain limits 

                canvas.fillStyle = colors[m + band]
                y1 = ys(v)
                canvas.fillRect t, height - y1, stepWidth, y1




          else

            # record whether there are negative values to display
            negative = undefined

            # positive bands
            j = 0

            while j < m
              canvas.fillStyle = colors[m + j]
              
              # Adjust the range based on the current band index.
              y0 = (j - m + 1) * height

              # draw the same thing in each band
              # but shifting each subsequent band down and using a darker color
              # so that bars representing larger values and coming from below 
              # overplot the smaller ones in previous bands

              ys.range [m * height + y0, y0]
              y0 = ys(0)
              i = i0
              n = width
              y1 = undefined

              # while i < n3
              #   y1 = data[i].value
              #   if y1 <= 0
              #     negative = true
              #     continue
              #   canvas.fillRect i, y1 = ys(y1), 1, y0 - y1
              #   ++i

              for d in data
                t = d.date
                y1 = d.value
                if y1 <= 0
                  negative = true       # has at least one negative value
                  continue
                canvas.fillRect tscale(t), y1 = ys(y1), stepWidth, y0 - y1


              ++j


            if negative
              
              # enable offset mode
              if mode is "offset"
                canvas.translate 0, height
                canvas.scale 1, -1
              
              # negative bands
              j = 0

              while j < m
                canvas.fillStyle = colors[m - 1 - j]
                
                # Adjust the range based on the current band index.
                y0 = (j - m + 1) * height
                ys.range [m * height + y0, y0]
                y0 = ys(0)
                i = i0
                n = width
                y1 = undefined

                # while i < n
                #   y1 = data[i].value
                #   continue  if y1 >= 0
                #   canvas.fillRect i, ys(-y1), 1, y0 - ys(-y1)
                #   ++i

                for d in data
                  t = d.date
                  y1 = d.value
                  continue  if y1 >= 0
                  canvas.fillRect tscale(t), ys(-y1), stepWidth, y0 - ys(-y1)

                ++j

          canvas.restore() 


          return canvas


      chart






    # TODO: ensure that a uniform scale is used for the three datasets

    filter = do ->
      filters = {}
      (attrName, values) ->
        if arguments.length is 1
          return filters[attrName]
        if values?
          filters[attrName] = values
          loadData filters
        else      
          if filters[attrName]?
            delete filters[attrName]
            loadData filters



    tip = $('<div id="tooltip"></div>')
      .html('<div></div>')
      .hide()
      .appendTo($('body'))

    tooltip = (verb, prekey = "") ->
      (d, dobj, t) ->
        chart = this
        if d?
          tip.find("div").html "#{chart.valueFormat()(dobj.value)} "+
                               "#{verb} #{d.key} in #{dateFormat(t)}"
          e = d3.event
          tip.css
            top: e.pageY - 20
            left: e.pageX + 20
          tip.show()
        else
          tip.hide()



    nodeCodesToNames = null
    iso2toIso3 = null

    donorsChart = horizonChart()
      .title("Donors")
      .interval(timeInterval)
      .valueFormat(formatMagnitudeLong)
      .indicatorButtons(true)
      .showLegend(true)
      .label((d) -> nodeCodesToNames[d.key])
      .on("applyFilter", (selected) -> filter "donor", selected)
      .on("ruleMoved", (t) ->
        recipientsChart.showRuleAt t
        purposesChart.showRuleAt t
      )
      .on("focusOnItem", tooltip("were donated <br> by"))
      .on("loadIndicator", -> $("#indicatorModal").data("target", "donors").modal())
      .on("clearIndicator", -> )


    recipientsChart = horizonChart()
      .title("Recipients")
      .valueFormat(formatMagnitudeLong)
      .label((d) -> nodeCodesToNames[d.key])
      .interval(timeInterval)
      .indicatorButtons(true)
      .showLegend(false)
      .on("applyFilter", (selected) -> filter "recipient", selected)
      .on("ruleMoved", (t) ->
        donorsChart.showRuleAt t
        purposesChart.showRuleAt t
      )
      .on("loadIndicator", -> $("#indicatorModal").data("target", "recipients").modal())
      .on("focusOnItem", tooltip("were received <br>  by"))

    purposesChart = horizonChart()
      .title("Purposes")
      .interval(timeInterval)
      .valueFormat(formatMagnitudeLong)
      .label("purpose")
      .showLegend(false)
      .on("applyFilter", (selected) -> filter "purpose", selected)
      .on("ruleMoved", (t) ->
        recipientsChart.showRuleAt t
        donorsChart.showRuleAt t
      )
      .on("focusOnItem", tooltip("were donated <br> with purpose"))


    indicatorChart = horizonChart()
      .key((dd) -> if (d = dd.values[0])? then (if d.code?.length > 0 then d.code else d.name) else "")
      .label((dd) -> if (d = dd.values[0])? then d.name else "")
      .interval(timeInterval)
      .showLegend(true)
      .filterButtons(false)
      .on("focusOnItem", tooltip("<br>"))
      .negativeColorRange([d3.hcl(42,-10, 70), d3.hcl(42,-46, 10)])
      .positiveColorRange([d3.hcl(52, 43, 70), d3.hcl(14, 45, 10)])


    # queue()
    #   .defer(loadJson, "purposes.json")
    #   .await (error, loaded) ->
    #      console.log loaded[0]

    prepareData = (keyProp, valueProp) ->
      (data) ->
        nested = d3.nest()
          .key((d) -> d[keyProp])
          .rollup((arr) -> 

            #mean = arr.reduce(((p, v) -> +v[valueProp] + p), 0) / arr.length

            for obj in arr
              obj.date = timeInterval(dateFormat.parse(obj.date)) #.getTime()
              obj.value = +obj[valueProp] #- mean/2

            arr.extent = d3.extent(arr, (d) -> +d.value)
            arr.timeExtent = d3.extent(arr, (d) -> d.date)
            arr
          )
          .entries(data)
        #nested.sort((a, b) -> d3.descending(a.values.extent[1], b.values.extent[1]))

    loadingStarted = ->
      $("body").css("cursor", "progress")
      $("#loading .blockUI")
        .css("cursor", "progress")
        .show()
      $("#loading img").stop().fadeIn(100)
      $(".btn").attr("disabled", true)
      $("#indicatorTypeahead").attr("disabled", true)

    loadingFinished = ->
      $("body").css("cursor", "auto")
      $("#loading .blockUI").hide()
      $("#loading img").stop().fadeOut(500)
      $(".btn").button("complete")
      $("#indicatorTypeahead").attr("disabled", false)
      updateCtrls()

    updateCtrls = ->
      d3.select("#donorsChart").select(".btn-group.filter")
        .classed("applied", filter("donor")?)

      d3.select("#recipientsChart").select(".btn-group.filter")
        .classed("applied", filter("recipient")?)

      d3.select("#purposesChart").select(".btn-group.filter")
        .classed("applied", filter("purpose")?)


    # prop is either "extent" (for values) or "timeExtent" (for time)
    getMaxExtent = (datas, prop = "extent") ->
      extent = (data) ->
        extents = (d.values[prop] for d in data)
        [ d3.min(extents, (d) -> d[0]), d3.max(extents, (d) -> d[1]) ]

      extents = (extent(data)  for data in datas)
      [ d3.min(extents, (d) -> d[0]), d3.max(extents, (d) -> d[1]) ]



    loadData = do ->

      cache = cachingLoad(100)
      purposesByCode = null

      expandPurposes = (data) ->
        for obj in data
          obj.purpose = purposesByCode[obj.key]
        data

      flatten = (purposeTree) ->
        codeToName = {}
        recurse = (node) ->
          codeToName[node.code] = node.name
          if node.values?
            recurse(n) for n in node.values
        recurse purposeTree
        codeToName

      groupNodesByCode = (nodes) ->
        d3.nest()
          .key((d) -> d.code)
          .rollup((list) -> list[0].name)
          .map(nodes)

      groupCountryCodesByIso2 = (nodes) ->
        d3.nest()
          .key((d) -> d.iso2)
          .rollup((list) -> list[0].iso3)
          .map(nodes)

      firstLoad = true

      (filters) ->
        loadingStarted()

        filterq = if filters? then ("&filter=" + encodeURIComponent JSON.stringify filters) else ""

        queue()
        .defer(cache(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,donor#{filterq}", prepareData("donor", "sum_amount_usd_constant")))
        .defer(cache(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,recipient#{filterq}", prepareData("recipient", "sum_amount_usd_constant")))
        .defer(cache(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,purpose#{filterq}", prepareData("purpose", "sum_amount_usd_constant")))
        .defer(cache(loadJson, "purposes.json"))
        # .defer(cache(loadCsv, "aiddata-countries.csv"), groupCountriesByIso3)
        .defer(cache(loadCsv, "data/aiddata-nodes.csv", groupNodesByCode))
        .defer(cache(loadCsv, "data/countries-iso2-iso3.csv", groupCountryCodesByIso2))
        .await (error, loaded) ->


          [ donors, recipients, purposes, purposeTree, nodeCodesToNames, iso2toIso3 ] = loaded

          purposesByCode = flatten purposeTree
          purposes = expandPurposes(purposes)

          valueExtent = getMaxExtent([ donors, recipients, purposes ], "extent")
          donorsChart.valueExtent valueExtent
          recipientsChart.valueExtent valueExtent
          purposesChart.valueExtent valueExtent
      

          if firstLoad
            timeExtent = getMaxExtent([ donors, recipients, purposes ], "timeExtent")
            donorsChart.timeExtent timeExtent
            recipientsChart.timeExtent timeExtent
            purposesChart.timeExtent timeExtent
            indicatorChart.timeExtent timeExtent

            firstLoad = false




          d3.select("#donorsChart")
            .datum(donors)
            .call(donorsChart)

          d3.select("#recipientsChart")
            .datum(recipients)
            .call(recipientsChart)

          d3.select("#purposesChart")
            .datum(purposes)
            .call(purposesChart)


          loadingFinished()

    loadData({})




    # disable text selection with mouse
    (($) ->
      $.fn.disableSelection = ->
        @attr("unselectable", "on").css("user-select", "none").on "selectstart", false
    ) jQuery

    $(".horizonChart").disableSelection()


    fitToWindow = ->
      $(".horizonChart").not("#indicatorChart").each ->
        $(this).css("height", (window.innerHeight - $(this).position().top - 110) + "px")

      $("#indicatorChart").css("height", (window.innerHeight - 280) + "px")
      $("#indicatorModal .modal-body")
        .css("height", (window.innerHeight - 200) + "px")

      # $("#indicatorModal").css("height", (window.innerHeight - 100) + "px")

    $(window).resize(fitToWindow)


    $ -> 
      fitToWindow()
      $("#indicatorModalClose").click -> $("#indicatorModal").modal("hide")
      $("#indicatorModalLoad").click -> addIndicatorBandsTo($("#indicatorModal").data("target"))


    addIndicatorBandsTo = (target) ->
      chart = $("#" + target + "Chart")
      
      horizonByCode = {}
      $("canvas", chart).each -> horizonByCode[$(this).data("key")] = this

      $("#indicatorChart canvas").each ->
        $(horizonByCode[iso2toIso3[$(this).data("key")]]).after(this)

      $("#indicatorModal").modal("hide")


    indicators = null
    findIndicatorByName = (name) -> (if i.name is name then return i) for i in indicators; null

    updateIndicator = ->
      indicator = findIndicatorByName $("#indicatorTypeahead").val()
      if indicator?
        loadingStarted()

        queue()
        .defer(loadCsv, "wb/all/#{indicator.id}.csv")
        .defer(loadJson, "wb/describe/#{indicator.id}.json")
        .await (err, data) ->
          loadingFinished()

          [ entries, desc ] = data
          unless err?
            try
              prepared = prepareData("name", "value")(entries)

              valueExtent = getMaxExtent([ prepared ], "extent")

              max = Math.max(-valueExtent[0], valueExtent[1])
              if max > 100
                indicatorChart.valueFormat(d3.format(",.0f"))
              else if max > 10
                indicatorChart.valueFormat(d3.format(",.1f"))
              else if max > 1
                indicatorChart.valueFormat(d3.format(",.2f"))
              else
                indicatorChart.valueFormat(d3.format(",.3f"))

              d3.select("#indicatorChart")
                .datum(prepared)
                .call(indicatorChart)

              d3.select("#indicatorDesc .name").text(desc.name)
              d3.select("#indicatorDesc .source").text("Source: " + desc.source?.value)
              d3.select("#indicatorDesc .sourceNote").text(desc.sourceNote)
              d3.select("#indicatorDesc .topics").text(desc.topics?.map((d) -> d.value).join(", "))



            catch e
              err = e

          if err?
            alert("Could not load indicator: " + err)


      


    d3.csv "wb/brief/indicators.csv", (data) ->
      indicators = data

      splitWords = (str) -> str.split(/\W+/).filter((s)->s.length > 0)
      findWordWithPrefix = (words, prefix) -> 
        for w in words
          return w if w.indexOf(prefix) is 0
        return null

      $("#indicatorTypeahead")
        .data("source", indicators.map((ind) -> ind.name))
        .data("items", indicators.length)
        .data("minLength", 2)
        .data("matcher", (item) ->
          q = this.query
          qwords = splitWords q.toLowerCase()
          iwords = splitWords item.toLowerCase()
          for qw in qwords
            return false unless findWordWithPrefix iwords, qw
          return true
        )
        .on("blur", -> $(this).val("") unless findIndicatorByName($(this).val())?  )
        .on("change", updateIndicator)

      $("#indicatorClear").click -> $("#indicatorTypeahead").val("")




