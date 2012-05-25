$("body").append(
  '<div id="loading">Loading view...'+
  '<br><br> Over a million commitments are being loaded now. This may take a minute.</div>')

parseDate = (d) ->
  new Date(d, 0, 1)
  #new Date(2001, d.substring(0, 2) - 1, d.substring(2, 4), d.substring(4, 6), d.substring(6, 8))


maxNumberOfFlows = 
  #100000 
  Infinity

# The flows data is nested in order to save space
unnest = (flowsByDonorRecipientDatePurpose) ->  
  flows = []
  newFlow = (donor, recipient, date, purpose, amount) ->
    donor: donor
    recipient: recipient
    date: parseDate(date)
    purpose: purpose
    amount: amount

  for donor, recipientDatePurposeFlows of flowsByDonorRecipientDatePurpose
    for recipient, datePurposeFlows of recipientDatePurposeFlows
      for date, purposeFlows of datePurposeFlows
        for purpose, flowOrFlows of purposeFlows
          if _.isArray(flowOrFlows)
            for amount in flowOrFlows
              flows.push newFlow(donor, recipient, date, purpose, amount)
          else
            flows.push newFlow(donor, recipient, date, purpose, flowOrFlows)

          if flows.length >= maxNumberOfFlows
            return flows

  return flows


# data/cached/
d3.json "data/cached/flows.json", (data) ->

  $("#loading").html("Preparing data...")

  console.log "unnesting"
  flows = unnest(data)
  console.log flows.length

  data = null # let it be garbage collected


  maxAmount = d3.max(flows, (d) -> d.amount)
  dateExtent =  [parseDate(1947), new Date()] # d3.extent(flows, (d) -> d.date)
  console.log "maxAmount= #{maxAmount}"


  formatNumber = d3.format(",d")
  formatChange = d3.format("+,d")
  #formatDate = d3.time.format("%B %d, %Y")
  #formatTime = d3.time.format("%I:%M %p")
  formatDate = d3.time.format("%Y")
  nestByDate = d3.nest().key (d) -> d3.time.year d.date


  # A little coercion, since the CSV is untyped.
  flows.forEach (d, i) ->
    d.index = i
    #d.date = parseDate(d.date)
    d.amount = +d.amount

  flow = crossfilter(flows)


  all = flow.groupAll()
  date = flow.dimension (d) -> d.date   #d3.time.day d.date
  dates = date.group()
  #hour = flow.dimension (d) -> d.date.getHours() + d.date.getMinutes() / 60
  #hours = hour.group(Math.floor)
  amount = flow.dimension (d) -> d.amount
  amounts = amount.group (d) -> Math.floor(d / 50 * 1e3) * 50 * 1e3 



  render = (method) ->
    d3.select(this).call method

  renderAll = ->
    chart.each render
    list.each render
    d3.select("#active").text formatNumber(all.value())



  flowList = (div) ->


    #flowsByDate = nestByDate.entries(amount.top(40))

    #console.log flowsByDate

    flowsByDate = [
      key : "Top 40 of the selected commitments"
      values: amount.top(40)
    ]

    div.each ->
      dateListEntry = d3.select(this).selectAll(".date")
        .data(flowsByDate, (d) ->  d.key)

      dateListEntry.enter()
        .append("div")
          .attr("class", "date")
        .append("div")
          .attr("class", "day")
          .text (d) -> d.key  #formatDate d.values[0].date

      dateListEntry.exit().remove()

      flow = dateListEntry.order()
        .selectAll(".flow")
        .data(((d) -> d.values), ((d) -> d.index))
      
      flowEnter = flow.enter().append("div").attr("class", "flow")

      ###
      flowEnter.append("div")
        .attr("class", "date")
        .text (d) ->  "date: " +  formatDate(d.date)  # formatTime d.date
      ###

      flowEnter.append("div")
        .attr("class", "origin")
        .text (d) -> 
          formatDate(d.date) 
          

      
      flowEnter.append("div")
        .attr("class", "destination")
        .text (d) ->
            d.donor + " -> " + d.recipient
           #d.recipient
      

      flowEnter.append("div")
        .attr("class", "purpose")
        .text (d) -> d.purpose

      flowEnter.append("div")
        .attr("class", "amount")
        .text (d) -> magnitudeFormat(d.amount)

      flow.exit().remove()
      flow.order()







  ###
  crossfilter.barChart()
      .dimension(hour)
      .group(hours)
    .x(d3.scale.linear()
      .domain([0, 24])
      .rangeRound([0, 10 * 24])),
  ###
  ###
  crossfilter.barChart()
      .dimension(amount)
      .group(amounts)
    .x(d3.scale.linear()
      .domain([0, maxAmount])
      .rangeRound([0, 10 * 40])
      #.tickFormat(magnitudeFormat)
      ),
  ###
  charts = [ 
    crossfilter.barChart()
        .dimension(date)
        .group(dates)
        .round(d3.time.year.round)
      .x(d3.time.scale()
        .domain(dateExtent) #[1947, 2011])
        .rangeRound([0, 700])
        #.tickFormat((d) -> d)
        )
        .filter(dateExtent) #[new Date(2001, 1, 1), new Date(2001, 2, 1)])
  ]

  # Given our array of charts, which we assume are in the same order as the
  # .chart elements in the DOM, bind the charts to the DOM and render them.
  # We also listen to the chart's brush events to update the display.
  chart = d3.selectAll(".chart")
    .data(charts)
    .each((chart) -> chart.on("brush", renderAll).on "brushend", renderAll)

  list = d3.selectAll(".list")
    .data([ flowList ])

  d3.selectAll("#total").text formatNumber(flow.size())

  $("#loading").html("Rendering...")
  
  renderAll()
  
  $("#loading").hide()
  $("#charts").show()


  window.filter = (filters) ->
    filters.forEach (d, i) ->
      charts[i].filter d

    renderAll()

  window.reset = (i) ->
    charts[i].filter null
    renderAll()


