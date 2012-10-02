dateFormat = d3.time.format("%Y")
valueFormat = formatMagnitudeLong
bandHeight = 20
bandWidth = 390
bandPadding = 1

timeInterval = d3.time.year





colorsBetween = (start, end, numColors) ->
  scale = d3.scale.linear()
    .range([start, end])
    .domain([1, numColors])
    .interpolate(d3.interpolateHcl)

  (scale(i) for i in [1..numColors])

 



renderHorizons = do ->

  mode = "mirror"
  # colors = ["#08519c","#3182bd","#6baed6","#bdd7e7",
  #           "#bae4b3","#74c476","#31a354","#006d2c"]
  # colors = 
  #   colorsBetween("#e0f3f8","#313695", 6).reverse()  # negative
  #   .concat(colorsBetween("#e5f5e0","#00441b", 6))   # positive


  colors = 
    colorsBetween("#313695", "#e0f3f8", 6)  # negative
    .concat colorsBetween("#e5f5e0",d3.hcl("#00441b").darker(), 6)  # positive


  width = bandWidth
  height = bandHeight
  tscale = d3.time.scale().range([0, width])
  yscale = d3.scale.linear()#.nice() #.interpolate(d3.interpolateRound)
  m = colors.length >> 1   # number of bands

  useLog10Bands = true
  showNegativeLegend = false



  (parent, data, showLegend) ->
    parent
      .attr("class", "horizonChart")
      .attr("style", "width:#{bandWidth}px")




    extents = (d.values.extent for d in data)
    extent = [ d3.min(extents, (d) -> d[0]), d3.max(extents, (d) -> d[1]) ]
    max = Math.max(-extent[0], extent[1])
    
    yscale.domain [0, max]

    timeExtents = (d.values.timeExtent for d in data)
    timeExtent = [ d3.min(timeExtents, (d) -> d[0]), d3.max(timeExtents, (d) -> d[1]) ]
    tscale.domain(timeExtent)

    numSteps = Math.max(1, timeInterval.range.apply(this, timeExtent).length)
    stepWidth = Math.ceil(width / numSteps)


    xAxis = d3.svg.axis()
      .scale(tscale)
      .ticks(12)
      .orient("top")
      .tickSize(3, 0, 0)

    parent.append("div")
      .attr("class", "top axis")
      .append("svg")
        .attr("height", 20)
        .attr("width", bandWidth + 20)
        .append("g")
          .attr("class", "x axis")
          .attr("transform", "translate(0," + 20 + ")")
          .call(xAxis)

    parent.selectAll(".x.axis").call(xAxis)


    parent.append("div")
      .attr("class", "bands")

    parent.select("div.bands").selectAll("div.band")
        .data(data)
      .enter()
        .append("div")
          .attr("class", "band")
        .append("div")
          .attr("class", "horizon")



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

        legend = parent.select("div.legend")
          .append("svg")
            .attr("width", 100)
            .attr("height", n * 15 + 15)
          .append("g")
            .attr("transform", "translate(0, 10)")

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

      parent = d3.select(this)

      parent.append("canvas")
        .attr("width", width)
        .attr("height", height)

      parent.append("span")
        .attr("class", "title")
        .text((d) -> d.key)


      canvas = d3.select(this).select("canvas").node().getContext("2d")
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

            yscale.range [0, height]
            yscale.domain limits 

            canvas.fillStyle = colors[m - 1 - band]
            y1 = yscale(-v)

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
    
            yscale.range [0, height]
            yscale.domain limits 

            canvas.fillStyle = colors[m + band]
            y1 = yscale(v)
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

          yscale.range [m * height + y0, y0]
          y0 = yscale(0)
          i = i0
          n = width
          y1 = undefined

          # while i < n3
          #   y1 = data[i].value
          #   if y1 <= 0
          #     negative = true
          #     continue
          #   canvas.fillRect i, y1 = yscale(y1), 1, y0 - y1
          #   ++i

          for d in data
            t = d.date
            y1 = d.value
            if y1 <= 0
              negative = true       # has at least one negative value
              continue
            canvas.fillRect tscale(t), y1 = yscale(y1), stepWidth, y0 - y1


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
            yscale.range [m * height + y0, y0]
            y0 = yscale(0)
            i = i0
            n = width
            y1 = undefined

            # while i < n
            #   y1 = data[i].value
            #   continue  if y1 >= 0
            #   canvas.fillRect i, yscale(-y1), 1, y0 - yscale(-y1)
            #   ++i

            for d in data
              t = d.date
              y1 = d.value
              continue  if y1 >= 0
              canvas.fillRect tscale(t), yscale(-y1), stepWidth, y0 - yscale(-y1)

            ++j

      canvas.restore() 


      return canvas




queue()
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,donor")
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,recipient")
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,purpose")
  .await (error, loaded) ->

    prepareData = (data, keyProp, valueProp) ->
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
      nested.sort((a, b) -> d3.descending(a.values.extent[1], b.values.extent[1]))

    [ donors, recipients, purposes ] = loaded

    #timeScale = d3.time.scale().range([0, w])          


    renderHorizons(
      d3.select("#donorsChart"), 
      prepareData(donors, "donor", "sum_amount_usd_constant"),
      true
    )

    renderHorizons(
      d3.select("#recipientsChart"), 
      prepareData(recipients, "recipient", "sum_amount_usd_constant")
    )

    renderHorizons(
      d3.select("#purposesChart"), 
      prepareData(purposes, "purpose", "sum_amount_usd_constant")
    )


    




