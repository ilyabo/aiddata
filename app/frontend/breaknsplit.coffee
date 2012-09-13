
query = do -> 
  baseUrl = "dv/flows/breaknsplit.csv"

  (dataset, props, valueProp) ->
    filters = {}
    numFilters = 0
    breakDownBy = null
    dateFormat = d3.time.format("%Y")


    q = () ->

    check = (prop) ->
      unless prop in props
        throw new Error("Illegal property '#{prop}'")

    q.addFilter = (prop, values) ->
      check prop
      unless prop of filters
        numFilters++
      filters[prop] = values.slice(); q

    q.filter = (prop) -> check prop; filters[prop].slice()

    q.breakDownBy = (prop) ->
      check prop
      if (!arguments.length) then breakDownBy else breakDownBy = prop; q

    q.describe = () ->
      "Showing totals for " +
      dataset + " " + valueProp + "." + 
      "<div class=\"filter\">Selected " +
      (for prop in props
        if prop of filters
          len = filters[prop].length
          len + " " + prop + 
            (if len > 1 then "s" else "") +
            (if len < 5 then " ("+filters[prop].join(", ")+")" else "")
        else
          "all #{prop}s"
      ).join(", ") + 
      (if breakDownBy? then ", broken down by #{breakDownBy}s" else "") + 
      ".</div>"

    makeUrl = () ->
      url = baseUrl + "?breakby=date"
      url += ",#{breakDownBy}" if breakDownBy?
      enc = (obj) -> encodeURIComponent(obj)
      #url += ("&#{prop}=#{enc(values)}" for prop,values of filters)
      url += "&filter=" + enc(JSON.stringify filters) if numFilters > 0
      return url

    # grouping values corresponding to different values of breakDownBy
    # to one object identified by date. This is the form of data which the 
    # time-series chart accepts.
    groupValuesByDate = (data) ->
      nested = d3.nest()
        .key((d) -> d.date)
        .rollup((array) ->
          obj = {}
          for a,i in array
            obj[a[breakDownBy]] = +a[valueProp]
          obj
        )
        .map(data)

      merged = for date,val of nested
        val.date = dateFormat.parse(date)
        val

      merged

    prepareValues = (data) -> 
      values = []
      for d in data
        date = dateFormat.parse(d.date)
        v = {}
        v.date = date
        v[valueProp] = +d[valueProp]
        values.push v
      values

    q.load = (callback) ->
      #console.log q.describe()
      #console.log makeUrl()
      d3.csv makeUrl(), (csv) ->
        unless csv? and csv.length > 0
          callback(new Error("Couldn't load csv"), null)
        else
          datum =
            if breakDownBy?
              groupValuesByDate(csv)
            else
              prepareValues(csv)

          minDate = dateFormat.parse("1942")
          maxDate = Date.now()

          datum = datum.filter (d) -> (minDate <= d.date <= maxDate)

          callback(null, datum)

          #console.log merged



    return q


tschart = timeSeriesChart()
  .width(550)
  .height(300)
  .yticks(7)
  .marginLeft(100)
  .title("AidData: Total commitment amount by year")
  .ytickFormat(formatMagnitudeLong)



loadQuery = (q) -> 
  $("#loading").fadeIn()

  q.load (err, data) ->
    #console.log data
    if err?
      $("#error").addClass("alert-error alert").html("Could not load flow data")
    else
      #d3.select("#tseries").datum(data)
      #tschart.update(d3.select("#tseries"))
      
      #console.log data
      d3.select("#tseries").datum(data).call(tschart)
      $("#status").html(q.describe())

      #d3.select("#tseries").datum(prepareLoadedDataForUse(flows)).call(tschart)

    $("#loading").fadeOut()



loadQuery query("AidData", ["donor", "recipient", "purpose"], "sum_amount_usd_constant")





queue()
  #.defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=date")
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=donor")
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=recipient")
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=purpose")
  .defer(loadJson, "purposes.json")
  .await (err, data) ->

    if err?  or  not(data?)
      $("#loading").hide()
      $("#error")
        .addClass("alert-error alert")
        .html("Could not load flow data")
      return

    #console.log data


      
    [ donors, recipients, purposes, purposeTree ] = data

    $("#donorsList").append("<option>#{d.donor}</option>") for d in donors
    $("#recipientList").append("<option>#{d.recipient}</option>") for d in recipients
    $("#purposeList").append("<option>#{d.purpose}</option>") for d in purposes



    # prepareLoadedDataForUse = (flows) ->

    #   datum = []

    #   minDate = d3.time.format("%Y").parse("1942")
    #   maxDate = Date.now()

    #   for d in flows
    #     date = utils.date.yearToDate(d.date)
    #     if date?  and  (minDate <= date <= maxDate)
    #       datum.push
    #         date : date
    #         outbound : +d.sum_amount_usd_constant

    #   datum











    $("#donorsFilter").click -> loadQuery(query("AidData", ["donor", "recipient", "purpose"], "sum_amount_usd_constant")
      .addFilter("recipient", ["IND", "RUS"])
      .breakDownBy("recipient"))


    $("#recipientsFilter").click -> loadQuery(query("AidData", ["donor", "recipient", "purpose"], "sum_amount_usd_constant")
      .addFilter("donor", ["DEU", "USA", "NOR"])
      .breakDownBy("donor"))







    $("#content").show()

