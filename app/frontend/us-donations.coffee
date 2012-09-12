 $ ->
    tschart1 = timeSeriesChart()
      .width(800)
      .height(300)
      .marginLeft(200)
      #.title("Total US donations (blue, nominal US$) as percentage of US GDP (red, current US$)")
      .title("Total US foreign aid donations as percentage of US GDP")
      .ytickFormat(d3.format(",.2%"))


    tschart2 = timeSeriesChart()
      .width(800)
      .height(300)
      .marginLeft(200)
      .title("US GDP (red, current US$), total US donations (blue, nominal US$)")
      .ytickFormat(formatMagnitude)


    tschart3 = timeSeriesChart()
      .width(800)
      .height(300)
      .marginLeft(200)
      .title("Total US donations (blue, nominal US$)")
      .ytickFormat(formatMagnitude)



    loadData()
      .json('gdp', "wb.json/NY.GDP.MKTP.CD/USA")
      #.json('donated', "aiddata-donor-totals.json/USA")
      .json('donated', "aiddata-donor-totals-nominal.json/USA")
      .onload (data) ->
        
        
        datum1 = []
        datum2 = []
        datum3 = []

        donated = {}
        donated[d.date] = d.sum_amount_usd_nominal  for d in data.donated

        for y, o of data.gdp
          year = utils.date.yearToDate(y)

          if (donated[y]?)
            datum1.push
              date : year
              outbound : +(donated[y]) / o.value 

          datum2.push
            date : year
            inbound : +o.value 
            outbound : +donated[y]

          datum3.push
            date : year
            outbound : +donated[y]


        d3.select("#tseries1")
          .datum(datum1).call(tschart1)
          .append("div")
            .attr("class", "credits")
            .attr("style", "font-size:10px; color:#ccc; text-align:center;")
            .text("Based on data from AidData.org and World Bank")

        d3.select("#tseries2").datum(datum2).call(tschart2)
        d3.select("#tseries3").datum(datum3).call(tschart3)





