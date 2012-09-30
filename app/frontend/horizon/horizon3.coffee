dateFormat = d3.time.format("%Y")
bandHeight = 20
bandWidth = 390
bandPadding = 1

timeInterval = d3.time.year





colorsBetween = (min, max, numColors) ->
  scale = new chroma.ColorScale
    colors: [min, max]
    limits: [1..numColors]
  [1..numColors].map (n) -> scale.getColor(n).hex()
  



renderHorizons = do ->

  mode = "offset"
  # colors = ["#08519c","#3182bd","#6baed6","#bdd7e7",
  #           "#bae4b3","#74c476","#31a354","#006d2c"]
  colors = 
    colorsBetween("#e0f3f8","#313695", 10).reverse()  # negative
    .concat(colorsBetween("#e5f5e0","#00441b", 10))   # positive

  width = bandWidth
  height = bandHeight
  tscale = d3.time.scale().range([0, width])
  yscale = d3.scale.sqrt().nice() #.interpolate(d3.interpolateRound)
  m = colors.length >> 1


  (parent, data) ->
    parent
      .attr("class", "horizonChart")
      .attr("style", "width:#{bandWidth}px")

    parent.selectAll("div.band")
        .data(data)
      .enter()
        .append("div")
          .attr("class", "band")
        .append("div")
          .attr("class", "horizon")

    

    extents = (d.values.extent for d in data)
    extent = [ d3.min(extents, (d) -> d[0]), d3.max(extents, (d) -> d[1]) ]
    max = Math.max(-extent[0], extent[1])
    yscale.domain [0, max]

    timeExtents = (d.values.timeExtent for d in data)
    timeExtent = [ d3.min(timeExtents, (d) -> d[0]), d3.max(timeExtents, (d) -> d[1]) ]
    tscale.domain(timeExtent)

    numSteps = Math.max(1, timeInterval.range.apply(this, timeExtent).length)
    stepWidth = width / numSteps


    


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

      # record whether there are negative values to display
      negative = undefined

      # positive bands
      j = 0

      while j < m
        canvas.fillStyle = colors[m + j]
        
        # Adjust the range based on the current band index.
        y0 = (j - m + 1) * height
        yscale.range [m * height + y0, y0]
        y0 = yscale(0)
        i = i0
        n = width
        y1 = undefined

        # while i < n
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
            negative = true
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
  # .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,recipient")
  # .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,purpose")
  .await (error, loaded) ->

    prepareData = (data, keyProp, valueProp) ->
      nested = d3.nest()
        .key((d) -> d[keyProp])
        .rollup((arr) -> 

          mean = arr.reduce(((p, v) -> +v[valueProp] + p), 0) / arr.length

          for obj in arr
            obj.date = timeInterval(dateFormat.parse(obj.date)) #.getTime()
            obj.value = +obj[valueProp] - mean/2

          arr.extent = d3.extent(arr, (d) -> +d.value)
          arr.timeExtent = d3.extent(arr, (d) -> d.date)
          arr
        )
        .entries(data)
      nested.sort((a, b) -> d3.descending(a.values.extent[1], b.values.extent[1]))

    [ donors ] = loaded

    #timeScale = d3.time.scale().range([0, w])          


    renderHorizons(
      d3.select("#donorsChart"), 
      prepareData(donors, "donor", "sum_amount_usd_constant")
    )



    




