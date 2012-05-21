years = [1947..2011]

$("body").append('<div id="loading">Loading view...</div>')

monthsInCell = 2
width = (2012 - 1947) * 12 / monthsInCell
$(".horizonChart").css("width", width)


useLogScale = false



createContext = ->
  context = cubism.context()
    #.step(1.6e9)
    .step(1000 * 60 * 60 * 24 * 30 * monthsInCell)
    .size(width)
    #.size(500)
    .serverDelay(new Date(2011, 1, 1) - Date.now())


colorsBetween = (min, max, numColors) ->
  scale = new chroma.ColorScale
    colors: [min, max]
    limits: [1..numColors]
  [1..numColors].map (n) -> scale.getColor(n).hex()

colors = 
  colorsBetween("#e0f3f8","#313695", 10).reverse().concat(
    colorsBetween("#e5f5e0","#00441b", 10)
  )



render = (selection, nodes, getdata, maxValue, context) ->
  selection = selection.append("div")
    .attr("class", "content")

  selection.selectAll(".axis")
      .data([ "top", "bottom" ])
    .enter()
      .append("div")
      .attr("class", (d) ->
        d + " axis"
      ).each (d) ->
        d3.select(this).call context.axis().ticks(12).orient(d)

  selection.append("div").attr("class", "rule").call context.rule()

  selection.selectAll(".horizon")
    .data(nodes.map((n) -> getdata(n, context)))
      .enter()
    .insert("div", ".bottom")
      .attr("class", "horizon")
      .call context.horizon()
        .extent([ 0, if useLogScale then log10(maxValue) else maxValue  ])
        .height(20)
        .colors(colors)

  context.on "focus", (i) ->
    d3.selectAll(".value")
      .style("right", (if not i? then null else context.size() - i + "px"))


#    nameAttr = "recipient"    
#    years = d3.keys(nodes[0]).filter((n) -> n != "recipient").map((n) -> +n).sort()


provideWithMax = (nodes) ->
  nodes.forEach((n) -> n.max = d3.max(years, (y) -> +n[y]))
  maxValue = d3.max(nodes, (n) -> n.max)

provideWithNames = (nodes, nameAttr) -> 
  nodes.forEach((n) -> n.name = n[nameAttr])

getdata = (node, context) ->

  context.metric ((start, stop, step, callback) ->
    values = []
    date = start

    while date < stop
      date = d3.time.second.offset(date, step / 1000)
      val = +node[date.getFullYear()]
      if useLogScale
        if val > 0 then val = log10(val)

      values.push(val)

    callback(null, values.slice(-context.size()))

  ), node.name


queue()
  .defer(loadCsv, "#{dynamicDataPath}aiddata-recipient-totals.csv")
  .defer(loadCsv, "#{dynamicDataPath}aiddata-donor-totals.csv")
  #.defer(loadCsv, "#{dynamicDataPath}aiddata-nodes.csv")
  #.defer(loadCsv, "data/aiddata-countries.csv")
  .await (error, loadedData) ->
    

    loadedData.forEach (nodes) -> 
      provideWithMax(nodes)
      nodes.sort((a, b) -> b.max - a.max)
      #nodes.sort((a, b) -> a[nameAttr].localeCompare(b[nameAttr]))

    [ recipients, donors ] = loadedData
    maxValue = Math.max d3.max(recipients, (n) -> n.max), d3.max(donors, (n) -> n.max)
    provideWithNames(recipients, "recipient")
    provideWithNames(donors, "donor")

    $("#originsChart").append('<div class="viewTitle">Donors</div>')
    $("#destsChart").append('<div class="viewTitle">Recipients</div>')

    render(d3.select("#originsChart"), donors, getdata, maxValue, createContext())
    render(d3.select("#destsChart"), recipients, getdata, maxValue, createContext())

    $("#loading").hide()

