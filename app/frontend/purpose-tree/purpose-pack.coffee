###
width = 960
height = 960

format = d3.format(",d")
pack = d3.layout.pack()
  .size([ width - 4, height - 4 ])
  #.sort((a, b) -> b.amount - a.amount)
  .value((d) -> +d.amount)
  .children((d) -> d.values)


vis = d3.select("#purposePack").append("svg")
    .attr("width", width)
    .attr("height", height)
    .attr("class", "pack")
  .append("g")
    .attr("transform", "translate(2, 2)")


d3.csv "aiddata-purposes-with-totals.csv", (csv) ->

  #csv = csv.filter((d) -> d.code.substr(0,2) == "32")


  purposesNested = d3.nest()
    .key((p) -> p.category)
    .key((p) -> p.subcategory)
    .key((p) -> p.subsubcategory)
    #.key((p) ->
    #  if p.subsubcategory? and p.subsubcategory.trim().length > 0
    #    p.subsubcategory
    #  else
    #    p.subcategory
    #)
    .rollup((ps) -> 
      #if ps.length == 1 then ps[0].code else ps.map (p) -> p.code
      ps.map (p) ->
        key : p.code +  " - " + p.name
        num : +p.total_num
        amount : +p.total_amount
    )
    .entries(csv)



  data =
    key : "AidData"
    values : purposesNested

  #data = data.values[0].values[0].values[1]
  #removeSingleChildNodes(data)
  provideWithTotalAmount(data)


  node = vis.data([ data ]).selectAll("g.node")
      .data(pack.nodes)
    .enter()
      .append("g")
        .attr("class", (d) -> (if d.children then "node" else "leaf node"))
        .attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")

  node.append("title")
    .text (d) -> d.amount + (if d.values then "" else ": " + format(d.amount))

  node.append("circle")
    .attr "r", (d) -> d.r

  node
    .filter((d) -> not d.values)
    .append("text")
      .attr("text-anchor", "middle")
      .attr("dy", ".3em")
      .text (d) -> d.key.substring 0, d.r / 3

###



selectedDate = 2011
r = Math.min($(window).width()*0.7, $(window).height()*0.7)
x = d3.scale.linear().range([ 0, r ])
y = d3.scale.linear().range([ 0, r ])

pack = d3.layout.pack()
  .size([ r, r ])
  #.sort((a, b) -> a.amount - b.amount)
  .value((d) -> +d.amount)
  .children((d) -> d.values)

zoomLevel = 0

vis = d3.select("body").select("#purposePack")
  .append("svg:svg")
    .attr("width", $(window).width())
    .attr("height", $(window).height())
  .append("svg:g")


d3.select("body").append("div")
  .attr("class", "selectedDate")
  .text(selectedDate)

$(window).resize(->
  w = $(window).width()
  h = $(window).height()
  vis
    .attr("width", w)
    .attr("height", h)
    .attr("transform", "translate(" + (w - r) / 2 + "," + (h - r) / 2 + ")")
).resize()






formatPercent = d3.format(".2%")







d3.csv "aiddata-purposes-with-totals.csv/#{selectedDate}", (csv) ->

  unless csv?
    $("body").prepend('<span class="alert alert-error">Data could not be loaded</span>')

  #csv = csv.filter (d) ->  1e14 > d.total_amount > 1e11  #d.code.substr(0,3) == "322"

  #maxAmount = d3.max(csv, (d) -> +d.total_amount)



  #data = data.values[0].values[0].values[0]
  data = utils.aiddata.purposes.nestPurposeDataByCategories(csv)
  utils.aiddata.purposes.removeSingleChildNodes(data)
  utils.aiddata.purposes.provideWithTotalAmount(data)

  selectedNode = root = data

  packedNodeData = pack.nodes(root)

  nodes = vis.selectAll("g.node")
    .data(packedNodeData)
      .enter()
    .append("g")
      .attr("class", (d) -> (if d.children then "node" else "leaf node"))

  nodes.append("circle")
      .attr("class", (d) ->
        (if d.values then "parent" else "child")
        #(if d.type then " " + d.type else "") + 
        #(if d.depth is 1 then " " + d.acronym else "")
      )
      .attr("cx", (d) -> d.x)
      .attr("cy", (d) -> d.y)
      .attr("r", (d) -> d.r)
      .on "click", (d) -> zoom (if selectedNode is d then root else d)

  fontSize = 15

  updateText = (d) => 
    text = d.key #.replace(" - [0-9]{5}$", "")
    maxLen =  Math.floor(r * d.r / selectedNode.r  / fontSize * 2)
    if text.length < maxLen
      text
    else if maxLen > 0
      text.substr(0, maxLen).trim() + "..."
    else
      ""

  updateTextOpacity = (d) =>
    if (d.depth == zoomLevel + 1)  or  (not d.values? and  not selectedNode.values?)
      1
    else 
      0

  # bind separately, otherwise text is not above some of the circles
  vis.selectAll("text")
      .data(packedNodeData)
    .enter()
      .append("text")
        #.attr("class", (d) -> (if d.values then "parent" else "child") + (if d.type then " " + d.type else ""))
        .attr("x", (d) -> d.x)
        .attr("y", (d) -> d.y)
        .attr("text-anchor", "middle")
        .attr("dy", ".3em")
        .text(updateText)
        .style("opacity", updateTextOpacity)



  zoom = (d, i) ->
    if d.depth?
      zoomLevel = d.depth
    else
      zoomLevel = 0
    k = r / d.r / 2
    x.domain [ d.x - d.r, d.x + d.r ]
    y.domain [ d.y - d.r, d.y + d.r ]
    
    t = vis.transition()
      .duration((if d3.event.altKey then 7500 else 750))

    t.selectAll("circle")
      .attr("cx", (d) -> x(d.x))
      .attr("cy", (d) -> y(d.y))
      .attr "r", (d) -> k * d.r


    t.selectAll("text")
      .attr("x", (d) -> x(d.x))
      .attr("y", (d) -> y(d.y))
      .style("opacity", updateTextOpacity)
      .text(updateText)

    selectedNode = d
    d3.event.stopPropagation()


  d3.select(window).on "click", -> zoom root



  $tip = $('<div id="tooltip"></div>')
    .html("<div></div>")
    .hide()
    .appendTo($("body"))

  $(document).mousemove (e) ->
    $tip.css
      top: e.pageY + 0
      left: e.pageX + 10


  $(document).on "mouseover", "svg circle", ->
    d = @__data__
    $tip.find("div").html(
      "<strong>" + d.key + "</strong><br />" + 
      formatMagnitude(d.amount) + ' &nbsp; or &nbsp; ' + formatPercent(d.amount / root.amount)
    )
    $tip.show()

  $(document).on "mouseout", "svg circle", -> $tip.hide()

