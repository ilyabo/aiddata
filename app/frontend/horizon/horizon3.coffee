dateFormat = d3.time.format("%Y")
timeInterval = d3.time.year

 
horizonChart = ->

  mode = "mirror"
  showLegend = true
  bandHeight = 20
  bandWidth = 350
  valueFormat = formatMagnitudeLong
  interval = d3.time.year
  labelAttr = "key"

  title = ""
  eventListeners = {}
  useLog10Bands = true
  numBands = 4
  valueExtent = null

  chart = (selection) -> init(selection)
  chart.title = (_) -> if (!arguments.length) then title else title = _; chart
  chart.mode = (_) -> if (!arguments.length) then mode else mode = _; chart
  chart.interval = (_) -> if (!arguments.length) then interval else interval = _; chart
  chart.useLog10BandSplitting = (_) -> if (!arguments.length) then useLog10Bands else useLog10Bands = _; chart
  chart.showLegend = (_) -> if (!arguments.length) then showLegend else showLegend = _; chart
  chart.valueFormat = (_) -> if (!arguments.length) then valueFormat else valueFormat = _; chart
  chart.labelAttr = (_) -> if (!arguments.length) then labelAttr else labelAttr = _; chart
  chart.valueExtent = (_) -> if (!arguments.length) then valueExtent else valueExtent = _; chart

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


  # colors = ["#08519c","#3182bd","#6baed6","#bdd7e7",
  #           "#bae4b3","#74c476","#31a354","#006d2c"]
  # colors = 
  #   colorsBetween("#e0f3f8","#313695", 6).reverse()  # negative
  #   .concat(colorsBetween("#e5f5e0","#00441b", 6))   # positive

  colors = 
    colorsBetween("#313695", "#e0f3f8", numBands)  # negative
    .concat colorsBetween(d3.hcl("#e5f5e0").darker(0.5),d3.hcl("#00441b").darker(), numBands)  # positive


  parent = null
  width = bandWidth
  height = bandHeight
  tscale = d3.time.scale().range([0, width])
  yscale = d3.scale.linear()#.nice() #.interpolate(d3.interpolateRound)
  m = colors.length >> 1   # number of bands

  showNegativeLegend = false
  nextCheckboxId = 1

  numSteps = stepWidth = null

  init = (selection) ->

    data = selection.datum()
    parent = selection


    update = not selection.select("svg").empty()

    unless update
      parent
        .attr("class", "horizonChart")
        #.attr("style", "width:#{bandWidth}px")


      parent.append("div").attr("class", "viewTitle").text(title)
      parent.append("div").attr("class", "legend")  if showLegend
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


      filterBtns = parent.append("div")
        .attr("class", "controls btn-group")

      filterBtns.append("button")
        .attr("class", "btn btn-mini filter")
        .text("Apply filter")
        .on "click", -> 
          selected = []
          parent.selectAll("input")
            .each (d) -> 
              that = d3.select(this)
              if that.property("checked")
                selected.push d.key
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

    max = Math.max(-extent[0], extent[1])
    yscale.domain [0, max]


    unless update
      timeExtents = (d.values.timeExtent for d in data)
      timeExtent = [ d3.min(timeExtents, (d) -> d[0]), d3.max(timeExtents, (d) -> d[1]) ]
      tscale.domain(timeExtent)

      numSteps = Math.max(1, interval.range.apply(this, timeExtent).length)
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
        .data(data, (d) -> d.key)

    horizonsEnter = horizons.enter()
      .append("div")
        .attr("class", "horizon")
        .on("click", (d) -> 
          unless d3.event.target?.type is "checkbox"
            d3.select(this).select("input")[0][0].click()
            parent.select("button.filter")[0][0].click()
        )



    horizonsEnter.append("canvas")
      .attr("width", width)
      .attr("height", height)
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
          fire "focusOnItem", this, d, dobj, t
        else
          fire "focusOnItem", this, null
      )
      .on("mouseout", ->
        chart.showRuleAt null
        fire "ruleMoved", this, null
        fire "focusOnItem", this, null
      )

    item = horizonsEnter.append("span")
      .attr("class", "item")

    item.append("input")
      .attr("value", (d) -> d.key)
      .attr("type", "checkbox")

    item.append("label")
      .attr("class", "title")
      .html((d) -> shorten(d[labelAttr], 25, true))
      # .on "click", ->  d3.select(this.parentElement).select("input")[0][0].click()



    parent.select("div.bands").selectAll("div.horizon")
      .sort((a, b) -> d3.descending(a.values.extent[1], b.values.extent[1]))


    horizons.exit().remove()


    if useLog10Bands

      # TODO: find min nonzero abs value in the data and uniformly 
      # split the interval between the min and max orders of magnitude 
      # (not always by 10, but possibly by 100 or 1000)

      # TODO: deal with situations when there is no large difference
      # between orders of magnitudes 
      # (maybe automatically switch to the linear scale?)
      maxOrdMagn = Math.ceil(log10(max))
      #minOrdMagn = Math.ceil(log10(min))
      pow10 = (n) -> v = 1; v *= 10 for i in [1..n]; return v
      bands = (for i in [1..m]
        magn = maxOrdMagn + (i - m)
        start = (if i is 1 then 0 else pow10(magn - 1))
        end = pow10(magn)
        [ i - 1, [ start, end ] ]
      )

      if showLegend then do ->
        n = if showNegativeLegend then 2*m else m

        if update
          parent.select("div.legend").select("svg").remove()          

        parent.select("div.legend")
          .append("svg")
            .attr("width", 100)
            .attr("height", n * 15 + 15)
          .append("g")
            .attr("class", "content")
            .attr("transform", "translate(0, 10)")

        legend = parent.select("div.legend").select("g.content")

        #items = bands.map (band) -> [ i, [start, end] ] = band; [ colors[m + i - 1], end ]

        gitem = legend.selectAll("g.item")
          .data(
            #([[-1, [0, 0]]]).concat(bands)
            #items
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

        gitem.append("rect")
          .attr("x", 5)
          .attr("y", 0)
          .attr("width", 15)
          .attr("height", 15)
          .attr("fill", (d, i) -> d)

        gitem.append("text")
          .attr("dominant-baseline", "central")
          .attr("x", 25)
          .attr("y", 0)
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

applyFilter = do ->
  filters = {}
  (attrName, values) ->
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

tooltip = (chart, verb, prekey = "") ->
  (d, dobj, t) ->
    if d?
      tip.find("div").html "#{donorsChart.valueFormat()(dobj.value)} were"+
                           "<br> #{verb} #{d.key} in #{dateFormat(t)}"
      e = d3.event
      tip.css
        top: e.pageY - 20
        left: e.pageX + 20
      tip.show()
    else
      tip.hide()


donorsChart = horizonChart()
  .title("Donors")
  .interval(timeInterval)
  .showLegend(true)
  .on("applyFilter", (selected) -> applyFilter "donor", selected)
  .on("ruleMoved", (t) ->
    recipientsChart.showRuleAt t
    purposesChart.showRuleAt t
  )
  .on("focusOnItem", tooltip(donorsChart, "donated by"))

recipientsChart = horizonChart()
  .title("Recipients")
  .interval(timeInterval)
  .showLegend(false)
  .on("applyFilter", (selected) -> applyFilter "recipient", selected)
  .on("ruleMoved", (t) ->
    donorsChart.showRuleAt t
    purposesChart.showRuleAt t
  )
  .on("focusOnItem", tooltip(recipientsChart, "received by"))

purposesChart = horizonChart()
  .title("Purposes")
  .interval(timeInterval)
  .labelAttr("purpose")
  .showLegend(false)
  .on("applyFilter", (selected) -> applyFilter "purpose", selected)
  .on("ruleMoved", (t) ->
    recipientsChart.showRuleAt t
    donorsChart.showRuleAt t
  )
  .on("focusOnItem", tooltip(purposesChart, "donated with purpose"))



# queue()
#   .defer(loadJson, "purposes.json")
#   .await (error, loaded) ->
#      console.log loaded[0]

loadData = do ->

  loadingStarted = ->
    $("body").css("cursor", "progress")
    $("#loading .blockUI")
      .css("cursor", "progress")
      .show()
    $("#loading img").stop().fadeIn(100)
    $(".btn").attr("disabled", true)

  loadingFinished = ->
    $("body").css("cursor", "auto")
    $("#loading .blockUI").hide()
    $("#loading img").stop().fadeOut(500)
    $(".btn").button("complete")

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


  getValuesExtent = (data) ->
    extents = (d.values.extent for d in data)
    [ d3.min(extents, (d) -> d[0]), d3.max(extents, (d) -> d[1]) ]

  getMaxValuesExtent = (datas) ->
    extents = (getValuesExtent(data)  for data in datas)
    [ d3.min(extents, (d) -> d[0]), d3.max(extents, (d) -> d[1]) ]



  (filters) ->
    loadingStarted()

    filterq = if filters? then ("&filter=" + JSON.stringify filters) else ""

    queue()
    .defer(cache(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,donor#{filterq}", prepareData("donor", "sum_amount_usd_constant")))
    .defer(cache(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,recipient#{filterq}", prepareData("recipient", "sum_amount_usd_constant")))
    .defer(cache(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,purpose#{filterq}", prepareData("purpose", "sum_amount_usd_constant")))
    .defer(cache(loadJson, "purposes.json"))
    .await (error, loaded) ->


      [ donors, recipients, purposes, purposeTree ] = loaded

      purposesByCode = flatten purposeTree
      purposes = expandPurposes(purposes)


      maxExtent = getMaxValuesExtent [ donors, recipients, purposes ]

      donorsChart.valueExtent maxExtent
      recipientsChart.valueExtent maxExtent
      purposesChart.valueExtent maxExtent


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




