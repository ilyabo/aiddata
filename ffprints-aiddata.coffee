width = $(document).width() * .95
height = Math.min($(document).height() * 0.8, width * 0.55)
fmt = d3.format(",.0f")

chart =
  ffprintsChart()
    .mapTitles(["Donors", "Recipients"])
    .width(width).height(height)
    .flowOriginAttr('donor')
    .flowDestAttr('recipient')
    .nodeIdAttr('code')
    .nodeLabelAttr('name')
    .latAttr('Lat')
    .lonAttr('Lon')
    .tooltipText((value, nodeData, magnAttr, flowDirection, magnAttrGroup) ->
      [amount, year] = [value, magnAttr]
      if amount > 1000000
        amount = "$<b>#{fmt(amount / 1000000)} million"
      else
        amount = "$#{fmt(amount)}"

      deed = switch flowDirection
        when "outbound" then "donated"
        when "inbound" then "received"
        else "???"

      return "<span class=sm>#{nodeData.name}</span><br>#{deed} in <b>#{year}</b><br>#{amount}"
    )
    .flowMagnitudeAttrs
      aid:
        attrs: [1947..2011],
        explain: 'In #attr# there were #magnitude# ... from #origin# in #dest#'

$(document).ready ->
  #$("#useGeoNodePositions").button('toggle')
  $('#radioset').buttonset();

  useForce = ->
    chart.forceK  0.2  # $("#slider").slider("option", "value")
  $('#useForce').click -> useForce()
  $('#useGeoNodePositions').click -> chart.useGeoNodePositions()
  ###
  $("#slider")
    .slider
      orientation: 'horizontal'
      #range: true
      min: 0.01
      max: 0.2
      value: 0.2
      #values: [25, 75]
      step:0.01
      change: (e, ui) -> useForce()
  ###



loadData()
  .csv('nodes', "#{dynamicDataPath}aiddata-nodes.csv")
  .csv('flows', "#{dynamicDataPath}aiddata-totals-d-r-y.csv")
  #.csv('originTotals', "#{dynamicDataPath}aiddata-donor-totals.csv")
  #.csv('destTotals', "#{dynamicDataPath}aiddata-recipient-totals.csv")
  .json('map', "data/world-countries.json")
  .csv('countries', "data/aiddata-countries.csv")
  .onload (data) ->
    
    
    countriesByCode = {}
    for c in data.countries
      countriesByCode[c.Code] = c

    for node in data.nodes
      c = countriesByCode[node.code]
      if c?
        node.Lat = c.Lat
        node.Lon = c.Lon

    $("#loading").hide()

    d3.select("div#ffprints")
      .datum(data)
    .call(chart)
