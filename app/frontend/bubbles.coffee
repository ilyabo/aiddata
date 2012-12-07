years = [1947..2011]

selectedYear = 2007

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
  .width(460)
  .barHeight(12)
  .labelsWidth(200)
  .childrenAttr("values")
  .nameAttr("name")
  .leafsSelectable(true)
  .valueFormat(formatMagnitude)
  .values((d) -> d["sum_#{selectedYear}"] ? 0)
  # .values((d) -> d.totals[selectedYear].sum ? 0)
  #.values((d) -> d.totals["sum_#{selectedYear}"] ? 0)
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
    updatePurposeTooltips()
  )

updatePurposeTooltips = ->
  $('.tipsy').remove()  # remove all existing tooltips (otherwise they might remain forever)
  $('#purposeBars g.barg rect').tipsy
    gravity: 's'
    opacity: 0.9
    html: true
    #trigger: "manual"
    title: -> '<span class="sm">'+formatMagnitude(d3.select(this).data()[0]["sum_#{selectedYear}"])+'</span>'


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
    selectedYear = utils.date.dateToYear(current)
    bubbles.setSelDateTo(current, true)
    barHierarchy.values((d) -> d["sum_" + selectedYear] ? 0)

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
  
      updatePurposeTooltips()

      $("#purposeBars").show()



(($) ->
  $.fn.disableSelection = ->
    @attr("unselectable", "on").css("user-select", "none").on "selectstart", false
) jQuery


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

    nodesByCode = d3.nest()
      .key((d) -> d.code)
      .rollup((arr) -> if arr.length is 1 then arr[0] else console.warn("Code collision: ", arr); arr)
      .map(nodes)

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

    $("#timeSlider").disableSelection()
    $("#timeSlider div").disableSelection()
 

    bubbles.setSelDateTo(utils.date.yearToDate(selectedYear), false)
    $(document).keyup (e) -> 
      if e.keyCode is 27  and  $("#commitmentListModal").css("display") is "none"
        bubbles.clearNodeSelection()


    $("#loading").hide()
    $("#blockUI").hide()



    do ->

      accordionItem = (attr, value, parentid) ->
        
        if not(value) or (/^\s*(<br>)?\s*$/.test value) or (attr in ['donor', 'recipient', 'amount_constant', 'purpose_code','purpose_name'])
          return null 

        title = attr[0].toUpperCase()+attr.replace(/_/g,' ').substr(1)

        if attr.indexOf("amount")>-1 or attr.indexOf("cost")>-1
          unless isNaN(value)
            fmt = (if attr.indexOf("usd")>-1 then formatMagnitudeLong else formatMagnitudeLongNoCurrency)
            value = fmt(value)

        if value.length > 100
          id = 'commListItemDesc_'+parentid+'_'+attr
          '<div class="accordion-heading">'+  #  data-parent="#'+parentid+'"  - this makes only one item visible at a time
          '<a class="accordion-toggle" data-toggle="collapse" href="#'+id+'">'+title+'</a>'+
          '<div id="'+id+'" class="accordion-body collapse">'+
          '<pre>'+value+'</pre>'+
          '</div>'+
          '</div>'
        else
          '<div class="detailAttr">'+
          '<div class="name">'+title+'</div>'+
          '<div class="value">'+value+'</div>'+
          '</div>'
          

      $("#showCommitmentsBut").show().click ->
        $("#commitmentListModal").modal()
        $("#commitmentListModal div.loading").show()
        body = $("#commitmentListModal div.modal-body")

        pagination = $("#commitmentListModal .pagination").empty()
        list = $("table tbody", body).empty()
        $('.pageCount', body).text("")

        url = "commitments.json?page=0&year=#{selectedYear}"
        url += "&nodeName=#{encodeURIComponent nodesByCode[filters.node].name}" if filters.node?
        url += "&purpose=#{filters.purpose[0]}" if filters.purpose? and filters.purpose.length>0


        maxPages = 10

        queue()
          .defer(loadJson, url)
          .defer(loadJson, url + "&pagecount=1")
          .await (err, loaded) ->
            [ data, [{ count:totalCount, pagesize:pageSize, pagecount:pageCount }] ] = loaded

            $('.pageCount', body).text(
              'Showing ' + 
              (if totalCount < pageSize then ' all ' + totalCount else ' top ' + Math.min(totalCount, pageSize) + ' of ' + totalCount)+
              ' aid commitments ' + 
              ' made ' +
              (if filters.node? then ' by of for ' + nodesByCode[filters.node].name else '') +
              ' in ' + selectedYear +
              (if filters.purpose?.length > 0 then ' with purpose "' + $("#purposeBars li.node.sel a").attr("title") + '"' else '') +
              '.'
            )

            # pagination.append '<li><a href="#">«</a></li>'
            # for i in [1..Math.min(pageCount,maxPages)]
            #   pagination.append('<li><a href="#">'+i+'</a></li>')
            # pagination.append '<li class="disabled"><a href="#">...</a></li>'  if pageCount > maxPages
            # pagination.append '<li><a href="#">»</a></li>'

            for c,i in data
              list.append("
                <tr class=\"item\">
                  <td>#{c.donor}</td>
                  <td>#{c.recipient}</td>
                  <td>#{c.purpose_name}</td>
                  <td class=\"r\">#{formatMagnitudeLong(c.amount_constant)}</td>
                </tr>
                <tr class=\"details\"><td colspan=\"4\" data-index=\"#{i}\"></td></tr>
              ")

            $("#commitmentListModal tr.item").click ->
              next = $(this).next("tr").find("td")
              div = next.find("div")
              if div.size() is 0
                index = next.data("index")
                c = data[index]
                id = "commDescAccordion#{index}"

                accordionItems = (item  for attr, value of c when (item = accordionItem(attr, value, id))?)
                info = if accordionItems.length > 0
                  accordionItems.join('')
                else
                  "No detailed information available"

                next.append(
                    "<div class=\"accordion\" id=\"#{id}\">"+
                    "<div class=\"accordion-group\">
                      #{info}
                    </div></div>"
                )
              else
                div.remove()

            
            $("#commitmentListModal div.loading").hide()

        $("#commitmentListModalClose").click -> $("#commitmentListModal").modal("hide")
        
        fitToWindow = ->
          $("#commitmentListModal")
            .css("width", (window.innerWidth*0.8) + "px")
            .css("margin-left", (- window.innerWidth*0.8/2) + "px")
          $("#commitmentListModal .modal-body")
            .css("height", (window.innerHeight - 200) + "px")
        fitToWindow()
        $(window).resize(fitToWindow)



reloadPurposes()
