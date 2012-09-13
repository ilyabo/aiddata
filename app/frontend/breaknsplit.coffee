
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




query = do -> 
  baseUrl = "dv/flows/breaknsplit.csv"

  (dataset, props, valueProp) ->
    filters = {}
    numFilters = 0
    breakDownBy = null
    dateFormat = d3.time.format("%Y")


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
      check prop
      if (!arguments.length) then breakDownBy else breakDownBy = prop; q

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

          minDate = dateFormat.parse("1942")
          maxDate = Date.now()

          datum = datum.filter (d) -> (minDate <= d.date <= maxDate)

          callback(null, datum)

          #console.log merged



    return q


tschart = timeSeriesChart()
  .width(550)
  .height(200)
  .yticks(7)
  .marginLeft(100)
  #.title("AidData: Total commitment amount by year")
  .ytickFormat(formatMagnitudeLong)



propertyData = null  # is initialized below

syncFiltersWithQuery = ->
  q = queryHistory.current()

  $("select.filter").each ->

    $(this).find("option").remove()

    prop = $(this).data("prop")

    filter = q?.filter(prop)
    list = filter ? (propertyData[prop].map (d) -> d[prop])

    $(this).append("<option>#{d}</option>") for d in list

  
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

    $("#status").html(queryHistory.current().describe())

    $("#backButton").attr("disabled", queryHistory.isBackEmpty())
    $("#forwardButton").attr("disabled", queryHistory.isForwardEmpty())
    syncFiltersWithQuery()

  $("#loading").fadeOut()







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

    filter = (prop, selection) ->
      unless selection.length is 0
        q = queryHistory.current().copy()
        q.addFilter(prop, selection)
        $("#loading").fadeIn()
        queryHistory.load(q, updateCallback)

    removeFilter = (prop) ->
      q = queryHistory.current().copy()
      if q.filter(prop)?
        q.removeFilter(prop)
        $("#loading").fadeIn()
        queryHistory.load(q, updateCallback)


    $("button.breakdown").click ->


    $("button.filter").click ->
      prop = $(this).data("prop")
      selection = selectedFilterOptions(prop)
      filter(prop, selection)


    $("button.reset").click ->
      removeFilter($(this).data("prop"))



    $("#backButton").click ->
      $("#loading").fadeIn()
      queryHistory.back(updateCallback)


    $("#forwardButton").click ->
      $("#loading").fadeIn()
      queryHistory.forward(updateCallback)






    $("#content").fadeIn()
    $("#status").fadeIn()

