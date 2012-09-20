plusYears = (date, numYears) ->
  d = new Date(date.getTime()); d.setFullYear(d.getFullYear() + numYears); d

# used to sanity-filter the input data
minDate = plusYears(new Date(), -100)
maxDate = plusYears(new Date(), +10)

dateFormat = d3.time.format("%Y")

propertyData = null
indicators = null
smallCharts = {}

history = queryHistory()


query = do -> 

  (dataset, props, valueProp) ->
    filters = {}
    numFilters = 0
    breakDownBy = null
    split = false
    indicator = null

    q = () ->

    q.copy = ->
      cpy = query(dataset, props, valueProp)
      for p,v of filters
        cpy.addFilter(p, v)
      cpy.breakDownBy(breakDownBy) if breakDownBy?
      cpy.split(split)
      cpy.indicator(indicator.id, indicator.prop) if indicator?
      cpy

    check = (prop) ->
      unless prop in props
        throw new Error("Illegal property '#{prop}'")

    q.addFilter = (prop, values) ->
      check prop
      values = [ values ] unless values instanceof Array
      if values.length > 0
        unless prop of filters
          numFilters++
        filters[prop] = values.slice()
      q

    q.removeFilter = (prop) ->
      check prop
      if prop of filters
        numFilters--
      delete filters[prop]; q

    q.filter = (prop) -> check prop; filters[prop]?.slice()

    indicatorObj = (id, prop) ->
      id : id
      prop : prop

    q.indicator = (id, prop) ->
      if (!arguments.length)
        if indicator?
          return indicatorObj(indicator.id, indicator.prop)
        else
          return null 
      check prop
      indicator = indicatorObj(id, prop)
      q

    q.split = (_) ->
      if (!arguments.length)
        split
      else
        if breakDownBy? then split = (if _ then true else false)       
        q

    q.filters = -> 
      all = {}
      for p,v of filters
        all[p] = v.slice()
      all

    q.breakDownBy = (prop) ->
      if (!arguments.length) then breakDownBy else check prop; breakDownBy = prop; q

    q.resetBreakDownBy = ->
      breakDownBy = null; split = false; q

    q.describe = () ->
      "Showing totals for " +
      dataset + "'s <em>" + valueProp + "</em> over time." +
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
      "." +
      (if breakDownBy?
        " Broken down by <b>#{breakDownBy}s</b>.</div>" 
      else 
        "") +
      "</div>"


    makeUrl = () ->
      url = "dv/flows/breaknsplit.csv?breakby=date"
      url += ",#{breakDownBy}" if breakDownBy?
      enc = (obj) -> encodeURIComponent(obj)
      #url += ("&#{prop}=#{enc(values)}" for prop,values of filters)
      url += "&filter=" + enc(JSON.stringify filters) if numFilters > 0
      return url

    makeIndicatorUrlFor = (filterValue) ->
      "wb/brief/#{indicator.id}/#{filterValue}.csv"


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

    # do not report errors (data in WB API is often missing)
    loadCsvQuietly = (path, callback) -> d3.csv path, (csv) -> callback(null, csv)

    q.load = (callback) ->

      que = queue()

      que.defer(loadCsv, makeUrl())
      
      if indicator?
        filterValues = filters[indicator.prop]
        if filterValues?
          for val in filterValues
            que.defer(loadCsvQuietly, makeIndicatorUrlFor(val))
        else
          que.defer(loadCsv, makeIndicatorUrlFor("ALL"))

      que.await (error, results) ->
        if error?
          callback(new Error("Couldn't load data from server"), null)
          return

        mainCsv = results.shift()
        mainData =
          if breakDownBy?
            groupValuesByDate(mainCsv)
          else
            prepareValues(mainCsv)

        mainData = mainData.filter (d) -> d.date? and (minDate <= d.date <= maxDate)



        console.log results

        callback(null, mainData)



    return q


tschart = timeSeriesChart()
  .width(600)
  .height(200)
  .xticks(7)
  .yticks(7)
  .dotRadius(1)
  .marginLeft(100)
  #.title("AidData: Total commitment amount by year")
  .ytickFormat(formatMagnitudeLong)
  .showLegend(true)
  .legendWidth(250)
  #.legendHeight(250)
  .propColors(chroma.brewer.Set1)
  #.propColors([chroma.brewer.Set1[1]])
  .showRule(true)
  .on "rulemove", (date) -> moveChartRulesTo date



moveChartRulesTo = (date) ->
  tschart.moveRule date
  for val, chart of smallCharts
    chart.moveRule date

createSmallTimeSeriesCharts = (prop, values) ->
  
  data = d3.select("#tseries").datum()
  panel = d3.select("#splitPanel")

  charts = []
  for val in values
    chart = timeSeriesChart()
      .width(270)
      .height(90)
      .xticks(3)
      .yticks(2)
      .dotRadius(1)
      .properties([val])
      .marginLeft(40)
      .marginRight(15)
      .title("#{prop}: #{val}")
      .propColors(["steelblue"])
      .ytickFormat(shortMagnitudeFormat)
      .showRule(true)
      .on("rulemove", (date) -> moveChartRulesTo date)
      .on("click", do -> v = val; ->
        current = history.current().filter(prop)
        if current? and current.length is 1 and current[0] is v
          # nothing has to be changed
          return
        else
          filter(prop, [ v ])
      )
      #.on("mouseover", (svg) -> svg.classed("tshighlight", true))
      #.on("mouseout", (svg) -> svg.classed("tshighlight", false))

    div = panel.append("div")
        .datum(data)
      .attr("class", "tseries")

    div.call(chart)

    charts[val] = chart

  smallCharts = charts
  



syncFiltersWithQuery = ->
  q = history.current()

  $("select.filter").each ->

    $(this).find("option").remove()

    prop = $(this).data("prop")

    filter = q?.filter(prop)
    values = filter ? (propertyData[prop].map (d) -> d[prop])

    $(this).append("<option>#{d}</option>") for d in values


findIndicator = (id) -> (if i.id is id then return i) for i in indicators; null
findIndicatorByName = (name) -> (if i.name is name then return i) for i in indicators; null


updateCtrls = ->

  q = history.current()

  $(".btn-group.filter").each ->
    prop = $(this).data("prop")
    if q.filter(prop)?
      $(this).addClass("applied")
    else
      $(this).removeClass("applied")


  $(".btn-group.breakDown").each ->
    prop = $(this).data("prop")
    if q.breakDownBy() is prop
      $(this).addClass("applied")
    else
      $(this).removeClass("applied")

  if q.indicator()?
    indicator = q.indicator()
    $("#indicatorTypeahead").val(findIndicator(indicator.id)?.name)
    $("#indicatorFor").val(indicator.prop)
  else
    $("#indicatorTypeahead").val("")


  $(".btn, .ctl").attr("disabled", false)

  # $(".btn-group.filter .btn").attr("disabled", false)
  # $(".btn-group.breakDown .btn").attr("disabled", false)

  $("#split")
    .attr("disabled", not (q.breakDownBy()?))


  if q.split()
    $("#split").addClass("active")
  else
    $("#split").removeClass("active")

  if q.split()
    $("#split").addClass("applied")
    $("#indicatorOuter").show()
  else
    $("#split").removeClass("applied")
    $("#indicatorOuter").hide()



updateCallback = (err, data) ->
  if err?
    $("#errorText").html("<h4>Oh snap!</h4>I could not load the data from the server")
    $("#error").fadeIn().delay(5000).fadeOut()
    if callback? then callback("Could not load data from the server")

  else 
    if data?.length is 0
      $("#warningText").html("The result of your filter query is empty")
      $("#warn").fadeIn().delay(5000).fadeOut()
      #if callback? then callback("Empty query")
    else
      $("#warn").hide()

    $("#error").hide()
    # update the view
    d3.select("#tseries").datum(data).call(tschart)

    q = history.current()
    $("#status").html(q.describe())

    $("#backButton").attr("disabled", history.isBackEmpty())
    $("#forwardButton").attr("disabled", history.isForwardEmpty())
    syncFiltersWithQuery()
    updateCtrls()

    updateSplitPanel()
    
    # if q.breakDownBy()? then splitBy(q.breakDownBy())

  loadingStopped()


updateSplitPanel = ->
  
  d3.select("#splitPanel").selectAll("div.tseries").remove()

  q = history.current()
  prop = q.breakDownBy()
  
  if q.split() and prop?
    values = q.filter(prop) ? (propertyData[prop].map (d) -> d[prop])
    createSmallTimeSeriesCharts(prop, values)






load = (q) ->
  loadingStarted()
  history.load(q, updateCallback)

filter = (prop, selection) ->
  unless selection.length is 0
    current = history.current()
    q = current.copy()
    q.addFilter(prop, selection)
    load q

resetFilter = (prop) ->
  q = history.current().copy()
  if q.filter(prop)?
    q.removeFilter(prop)
    q.split(false)
    load q

resetBreakDown = (prop) ->
  q = history.current().copy()
  if (q.breakDownBy() is prop)
    q.resetBreakDownBy()
    q.split(false)
  load q

breakDownBy = (prop, selection) ->
  q = history.current().copy()

  changed = false

  if selection.length > 0
    q.addFilter(prop, selection)
    changed = true
  
  if q.breakDownBy isnt prop
    q.breakDownBy(prop)
    changed = true


  load q if changed
    
split = ->
  q = history.current().copy()
  q.split(not $(this).hasClass("active"))
  #updateSplitPanel()

  load q

showIndicator = (id, prop) ->
  q = history.current().copy()
  unless (q.indicator()?.id is id) and (q.indicator()?.prop is prop) 
    q.indicator(id, prop)
    load q





loadingStarted = ->
  $("body").css("cursor", "progress")
  $("#loading .blockUI")
    .css("cursor", "progress")
    .show()
    #.fadeIn(100)
  $("#loading img").stop().fadeIn(100)
  $(".btn").attr("disabled", true)
  #$(".ctls .btn").button("loading")

loadingStopped = ->
  $.Callbacks().empty()
  $("body").css("cursor", "auto")
  $("#loading .blockUI").hide() #fadeOut(100)
  $("#loading img").stop().fadeOut(500)
  #$(".ctls .btn").button("complete")
  updateCtrls()







queue()
  #.defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=date")
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=donor")
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=recipient")
  .defer(loadCsv, "dv/flows/breaknsplit.csv?breakby=purpose")
  .defer(loadJson, "purposes.json")
  .defer(loadCsv, "wb/brief/indicators.csv")
  .await (err, data) ->

    if err?  or  not(data?)
      loadingStopped()
      $("#error")
        .addClass("alert-error alert")
        .html("Could not load flow data")
      return

    #console.log data



    [ donors, recipients, purposes, purposeTree, indicators ] = data

    propertyData =
      donor : donors
      recipient : recipients
      purpose : purposes


    history.load(
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

    $ ->

      $("button.breakDown").click ->
        prop = $(this).data("prop")
        breakDownBy($(this).data("prop"), selectedFilterOptions(prop))


      $("button.filter").click ->
        prop = $(this).data("prop")
        filter(prop, selectedFilterOptions(prop))


      $("button.resetFilter").click ->
        prop = $(this).data("prop")
        $("select.filter[data-prop='#{prop}']").val([]) # clear selection
        resetFilter(prop)

      $("button.resetBreakDown").click ->
        prop = $(this).data("prop")
        $("select.filter[data-prop='#{prop}']").val([]) # clear selection
        resetBreakDown(prop)


      $("#backButton").click ->
        loadingStarted()
        history.back(updateCallback)


      $("#forwardButton").click ->
        loadingStarted()
        history.forward(updateCallback)


      $("#split").click split


      #$(".ctls .btn").each -> $(this).data("loading-text", $(this).text())


      $("#content").fadeIn()
      $("#status").fadeIn()



      updateIndicator = ->
        indicator = findIndicatorByName $("#indicatorTypeahead").val()
        if indicator? then showIndicator indicator.id, $("#indicatorFor").val()

      $("#indicatorTypeahead")
        .data("source", indicators.map((ind) -> ind.name))  #(ind.source ? "") + ": " + ind.name
        .data("items", 10)
        .on("blur", -> $(this).val("") unless findIndicatorByName($(this).val())?  )
        .on("change", updateIndicator)

      $("#indicatorFor").on("change", updateIndicator)


