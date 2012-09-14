
queryHistory = do ->

  current = null
  history = []
  forwardHistory = []

  load = (q, callback, updateHistory, clearForwardHistory) ->

    q.load (err, data) ->

        if clearForwardHistory
          forwardHistory = []

        if updateHistory
          if current?
            history.push(current)

        current = q.copy()

        #console.log( history.map((d)->d.filters()), current?.filters(), forwardHistory.map((d)->d.filters()))


        if callback? then callback(null, data)


  top = -> 
      if history.length > 0
        history[history.length - 1]
      else
        null

  {
    top : top

    current : -> current?.copy()

    back : (callback) ->
      if history.length > 0
        top = history.pop()
        forwardHistory.push(current)
        load(top.copy(), callback, false, false)

    forward : (callback) ->
      if forwardHistory.length > 0
        top = forwardHistory.pop()
        load(top.copy(), callback, true, false)

    isBackEmpty : -> history.length is 0

    isForwardEmpty : -> forwardHistory.length is 0

    load : (q, callback) -> load(q, callback, true, true)
  }



dateFormat = d3.time.format("%Y")
minDate = dateFormat.parse("1942")
maxDate = Date.now()


query = do -> 
  baseUrl = "dv/flows/breaknsplit.csv"

  (dataset, props, valueProp) ->
    filters = {}
    numFilters = 0
    breakDownBy = null


    q = () ->

    q.copy = ->
      cpy = query(dataset, props, valueProp)
      for p,v of filters
        cpy.addFilter(p, v)
      cpy.breakDownBy(breakDownBy) if breakDownBy?
      cpy

    check = (prop) ->
      unless prop in props
        throw new Error("Illegal property '#{prop}'")

    q.addFilter = (prop, values) ->
      check prop
      if values.length > 0
        unless prop of filters
          numFilters++
        filters[prop] = values.slice(); q

    q.removeFilter = (prop) ->
      check prop
      if prop of filters
        numFilters--
      delete filters[prop]; q

    q.filter = (prop) -> check prop; filters[prop]?.slice()

    q.filters = -> 
      all = {}
      for p,v of filters
        all[p] = v.slice()
      all

    q.breakDownBy = (prop) ->
      if (!arguments.length) then breakDownBy else check prop; breakDownBy = prop; q

    q.resetBreakDownBy = ->
      breakDownBy = null; q

    q.describe = () ->
      "Showing totals for " +
      dataset + "'s " + valueProp + " over time" +
      (if breakDownBy? then " broken down by #{breakDownBy}s" else "") + "." + 
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
        unless csv? #and csv.length > 0
          callback(new Error("Couldn't load csv"), null)
        else
          datum =
            if breakDownBy?
              groupValuesByDate(csv)
            else
              prepareValues(csv)


          datum = datum.filter (d) -> d.date? and (minDate <= d.date <= maxDate)

          callback(null, datum)

          #console.log merged



    return q


tschart = timeSeriesChart()
  .width(500)
  .height(200)
  .xticks(7)
  .yticks(7)
  .dotRadius(1)
  .marginLeft(100)
  #.title("AidData: Total commitment amount by year")
  .ytickFormat(formatMagnitudeLong)
  .showLegend(true)
  .legendWidth(250)
  .legendHeight(250)


createSmallTimeSeriesChart = (title) ->
  timeSeriesChart()
    .width(200)
    .height(150)
    .dotRadius(1)
    .marginLeft(70)
    .title(title)
    .ytickFormat(shortMagnitudeFormat)


propertyData = null  # is initialized below

syncFiltersWithQuery = ->
  q = queryHistory.current()

  $("select.filter").each ->

    $(this).find("option").remove()

    prop = $(this).data("prop")

    filter = q?.filter(prop)
    values = filter ? (propertyData[prop].map (d) -> d[prop])

    $(this).append("<option>#{d}</option>") for d in values

  
updateCallback = (err, data) ->
  if err?
    $("#errorText").html("<h4>Oh snap!</h4>I could not load the data from the server")
    $("#error").fadeIn().delay(5000).fadeOut()
    if callback? then callback("Could not load data from the server")

  else if data?.length is 0
    $("#warningText").html("The result of your filter query is empty")
    $("#warn").fadeIn().delay(5000).fadeOut()
    if callback? then callback("Empty query")

  else
    $("#warn").hide()
    $("#error").hide()
    # update the view
    d3.select("#tseries").datum(data).call(tschart)

    q = queryHistory.current()
    $("#status").html(q.describe())

    $("#backButton").attr("disabled", queryHistory.isBackEmpty())
    $("#forwardButton").attr("disabled", queryHistory.isForwardEmpty())
    syncFiltersWithQuery()
    
    # if q.breakDownBy()? then splitBy(q.breakDownBy())

  $("#loading").fadeOut()



# splitBy = (prop) ->
#   panel = d3.select("#splitPanel")
#   panel.selectAll("svg").remove()

#   values = filter ? (propertyData[prop].map (d) -> d[prop])
#   for v in values
#     chart = createSmallTimeSeriesChart(v)
#     data = 
#     d3.select("#splitPanel").datum(data).call(chart)


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

    propertyData =
      donor : donors
      recipient : recipients
      purpose : purposes


    queryHistory.load(
      query("AidData", ["donor", "recipient", "purpose"], "sum_amount_usd_constant"),
      updateCallback
    )







    
    # $("#donorList").append("<option>#{d.donor}</option>") for d in donors
    # $("#recipientList").append("<option>#{d.recipient}</option>") for d in recipients
    # $("#purposeList").append("<option>#{d.purpose}</option>") for d in purposes



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


    selectedFilterOptions = (prop) ->
      selectedOptions = $("select.filter[data-prop='#{prop}']").find(":selected")
      selection = $.makeArray(selectedOptions).map (d) -> d.value

    load = (q) ->
      $("#loading").fadeIn()
      queryHistory.load(q, updateCallback)

    filter = (prop, selection) ->
      unless selection.length is 0
        q = queryHistory.current().copy()
        q.addFilter(prop, selection)
        load q

    resetFilter = (prop) ->
      q = queryHistory.current().copy()
      if q.filter(prop)?
        q.removeFilter(prop)
        load q

    resetBreakDown = (prop) ->
      q = queryHistory.current().copy()
      if (q.breakDownBy() is prop)
        q.resetBreakDownBy()
      load q

    breakDownBy = (prop) ->
      q = queryHistory.current().copy()
      unless q.breakDownBy is prop
        q.breakDownBy(prop)
        load q


    $("button.breakdown").click -> breakDownBy($(this).data("prop"))


    $("button.filter").click ->
      prop = $(this).data("prop")
      selection = selectedFilterOptions(prop)
      filter(prop, selection)


    $("button.resetFilter").click -> resetFilter($(this).data("prop"))
    $("button.resetBreakDown").click -> resetBreakDown($(this).data("prop"))


    $("#backButton").click ->
      $("#loading").fadeIn()
      queryHistory.back(updateCallback)


    $("#forwardButton").click ->
      $("#loading").fadeIn()
      queryHistory.forward(updateCallback)






    $("#content").fadeIn()
    $("#status").fadeIn()

