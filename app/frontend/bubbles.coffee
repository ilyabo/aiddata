years = [1947..2011]
startYear = 2007

filters = {}

# Bubbles
bubbles = bubblesChart()
  .conf(
    flowOriginAttr: 'donor'
    flowDestAttr: 'recipient'
    nodeIdAttr: 'code'
    nodeLabelAttr: 'name'
    latAttr: 'Lat'
    lonAttr: 'Lon'
    flowMagnAttrs: years
    )
  .on("selectDate", (current, old) -> 
    timeSlider.setTime(current)
  )
  .on("selectNode", (sel) ->
    unless sel?
      delete filters.node
    else
      filters.node = [ sel.code ]
    reloadFlows()
    reloadPurposes()
  )


barHierarchy = barHierarchyChart()
  .width(450)
  .barHeight(12)
  .labelsWidth(200)
  .childrenAttr("values")
  .nameAttr("name")
  .leafsSelectable(true)
  .valueFormat(formatMagnitude)
  .values((d) -> d["sum_#{startYear}"] ? 0)
  # .values((d) -> d.totals[startYear].sum ? 0)
  #.values((d) -> d.totals["sum_#{startYear}"] ? 0)
  .labelsFormat((d) -> shorten(d.name ? d.key, 30))
  .labelsTooltipFormat((d) -> name = d.name ? d.key)
  .breadcrumbText(
    do ->
      percentageFormat = d3.format(",.2%")
      (currentNode) ->
        v = barHierarchy.values()
        data = currentNode; (data = data.parent while data.parent?)
        formatMagnitude(v(currentNode)) + " in total"
        #" (" + percentageFormat(v(currentNode) / v(data)) + " of total)"
  )
  .on("select", (sel) ->
    if sel.key is null or sel.key is ""
      delete filters.purpose
    else
      filters.purpose = [ sel.key ]
    reloadFlows()
  )


groupFlowsByOD = (flowList) -> 
  nested = d3.nest()
    .key((d) -> d.donor)
    .key((d) -> d.recipient)
    .key((d) -> d.date)
    .entries(flowList)

  flows = []
  for o in nested
    for d in o.values
      entry =
        donor : o.key
        recipient : d.key

      for val in d.values
        entry[val.key] = val.values[0].sum_amount_usd_constant

      flows.push entry
  flows


timeSlider = timeSliderControl()
  .min(utils.date.yearToDate(years[0]))
  .max(utils.date.yearToDate(years[years.length - 1]))
  .step(d3.time.year)
  .format(d3.time.format("%Y"))
  .width(250 - 30 - 8) # timeSeries margins
  .height(10)
  .on "change", (current, old) ->
    bubbles.setSelDateTo(current, true)
    barHierarchy.values((d) -> d["sum_" + utils.date.dateToYear(current)] ? 0)

# loadData()
#   .csv('nodes', "#{dynamicDataPath}aiddata-nodes.csv")
#   #.csv('flows', "#{dynamicDataPath}aiddata-totals-d-r-y.csv")
#   .csv('flows', "dv/flows/by/od.csv")
#   #.csv('flows', "dv/flows/breaknsplit.csv?breakby=date,donor,recipient")
#   .json('map', "data/world-countries.json")
#   .csv('countries', "data/aiddata-countries.csv")
#   .csv('flowsByPurpose', "dv/flows/by/purpose.csv")
#   .json('purposeTree', "purposes-with-totals.json")
#   .onload (data) ->



loadingStarted = ->
  $("body").css("cursor", "progress")
  $("#loading").show()
  $("#blockUI")
    .css("cursor", "progress")
    .show()
  # $("#loading img").stop().fadeIn(100)
  # $(".btn").attr("disabled", true)
  # $("#indicatorTypeahead").attr("disabled", true)

loadingFinished = ->
  $("body").css("cursor", "auto")
  $("#loading").hide()
  $("#blockUI").hide()
  # $("#loading img").stop().fadeOut(500)
  # $(".btn").button("complete")
  # $("#indicatorTypeahead").attr("disabled", false)
  # updateCtrls()


cache = cachingLoad(100)

reloadFlows = (callback) ->
  loadingStarted()
  filterq = if filters? then ("&filter=" + encodeURIComponent JSON.stringify filters) else ""
  queue()
    .defer(cache(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,donor,recipient#{filterq}"))
    .await (err, loaded) ->
      if err?
        callback err if callback?
      else
        # list of flows with every year separated
        #   -> list grouped by o/d, all years' values in one object
        flows = groupFlowsByOD loaded[0] 

        chart = d3.select("#bubblesChart")
        data = chart.datum()
        data.flows = flows
        chart
          .datum(data)
          .call(bubbles)

        callback(null, data) if callback?

      loadingFinished()


reloadPurposes = do ->
  valueAttrs = do ->
    arr = []
    for y in years
      for attr in ["sum", "count"]
        arr.push "#{attr}_#{y}"
    arr

  ->
    if (filters.node? and filters.node.length > 0)
      filterq = "?node=" + filters.node[0] # todo: support for multiple node selection
    else
      filterq = ""
    d3.json "purposes-with-totals.json#{filterq}", (purposeTree) ->
      purposeTree.name = "Purposes"
      utils.aiddata.purposes.provideWithTotals(purposeTree, valueAttrs, "values", "totals")
      d3.select("#purposeBars")
        .datum(purposeTree) #utils.aiddata.purposes.fromCsv(purposes['2007']))
        .call(barHierarchy)


reloadPurposes()

queue()
  .defer(loadCsv, "#{dynamicDataPath}aiddata-nodes.csv")
  .defer(cache(loadCsv, "dv/flows/breaknsplit.csv?breakby=date,donor,recipient&filter=%7B%7D"))
  .defer(loadJson, "data/world-countries.json")
  .defer(loadCsv, "data/aiddata-countries.csv")
  #.defer(loadCsv, "dv/flows/by/purpose.csv")
  .await (err, loaded) ->

    if err?  or  not(loaded?)
      $("#loading").hide()
      $("#blockUI").hide()
      $("#error")
        .addClass("alert-error alert")
        .html("Could not load data")
      return


    [ nodes, flows, map, countries,  ] = loaded



    provideCountryNodesWithCoords(
      nodes, { code: 'code', lat: 'Lat', lon: 'Lon'},
      countries, { code: "Code", lat: "Lat", lon: "Lon" }
    )


    # list of flows with every year separated
    #   -> list grouped by o/d, all years' values in one object
    flows = groupFlowsByOD flows 

    data = 
      map : map
      flows : flows
      nodes : nodes

    d3.select("#bubblesChart")
      .datum(data)
      .call(bubbles)


    d3.select("#timeSlider")
      .call(timeSlider)

 

    bubbles.setSelDateTo(utils.date.yearToDate(startYear), false)

    $("#loading").hide()
    $("#blockUI").hide()

    $("#purposeBars").show()




