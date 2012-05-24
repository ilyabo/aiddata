
#parseDate = (d) ->
#  new Date(d, 1, 1)
  #new Date(2001, d.substring(0, 2) - 1, d.substring(2, 4), d.substring(4, 6), d.substring(6, 8))


maxNumberOfFlows = 10000

# The flows data is nested in order to save space
unnest = (flowsByDonorRecipientDatePurpose) ->  
  flows = []
  newFlow = (donor, recipient, year, purpose, amount) ->
    donor: donor
    recipient: recipient
    year: year
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

  console.log "unnesting"
  flows = unnest(data)
  console.log flows.length

  maxAmount = d3.max(flows, (d) -> d.amount)
  console.log "maxAmount= #{maxAmount}"


  render = (method) ->
    d3.select(this).call method

  renderAll = ->
    chart.each render
    list.each render
    d3.select("#active").text formatNumber(all.value())



  flowList = (div) ->
    flowsByYear = nestByYear.entries(year.top(40))
    div.each ->
      date = d3.select(this).selectAll(".date")
        .data(flowsByYear, (d) ->  d.key)

      date.enter()
        .append("div")
          .attr("class", "date")
        .append("div")
          .attr("class", "day")
          .text (d) -> d.values[0].year #formatDate d.values[0].date

      date.exit().remove()

      flow = date.order()
        .selectAll(".flow")
        .data(((d) -> d.values), ((d) -> d.index))
      
      flowEnter = flow.enter().append("div").attr("class", "flow")

      flowEnter.append("div")
        .attr("class", "year")
        .text (d) ->  d.year  # formatTime d.date

      ###
      flowEnter.append("div")
        .attr("class", "origin")
        .text (d) -> d.origin

      flowEnter.append("div")
        .attr("class", "destination")
        .text (d) -> d.destination
      ###

      flowEnter.append("div")
        .attr("class", "amount")
        .text (d) -> magnitudeFormat(d.amount)

      flow.exit().remove()
      flow.order()



  formatNumber = d3.format(",d")
  formatChange = d3.format("+,d")
  formatDate = d3.time.format("%B %d, %Y")
  formatTime = d3.time.format("%I:%M %p")
  nestByYear = d3.nest().key (d) -> d.year
  ###
  nestByDate = d3.nest().key((d) ->
    d3.time.day d.date
  )
  ###



  # A little coercion, since the CSV is untyped.
  flows.forEach (d, i) ->
    d.index = i
    #d.date = parseDate(d.date)
    d.amount = +d.amount

  flow = crossfilter(flows)


  all = flow.groupAll()
  year = flow.dimension (d) -> d.year   #d3.time.day d.date
  years = year.group()
  #hour = flow.dimension (d) -> d.date.getHours() + d.date.getMinutes() / 60
  #hours = hour.group(Math.floor)
  amount = flow.dimension (d) -> d.amount
  amounts = amount.group (d) -> Math.floor(d / 50 * 1e3) * 50 * 1e3 



  ###
  crossfilter.barChart()
      .dimension(hour)
      .group(hours)
    .x(d3.scale.linear()
      .domain([0, 24])
      .rangeRound([0, 10 * 24])),
  ###
  charts = [ 

    crossfilter.barChart()
        .dimension(amount)
        .group(amounts)
      .x(d3.scale.linear()
        .domain([0, maxAmount])
        .rangeRound([0, 10 * 40])
        #.tickFormat(magnitudeFormat)
        ),

    crossfilter.barChart()
        .dimension(year)
        .group(years)
        #.round(d3.time.day.round)
      .x(d3.scale.linear()
        .domain([1947, 2011])
        .rangeRound([0, 10 * 90])
        #.tickFormat((d) -> d)
        )
        #.filter([new Date(2001, 1, 1), new Date(2001, 2, 1)])
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

  renderAll()


  window.filter = (filters) ->
    filters.forEach (d, i) ->
      charts[i].filter d

    renderAll()

  window.reset = (i) ->
    charts[i].filter null
    renderAll()


