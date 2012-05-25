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


$window = $(window)
$body = $("body")


w = 0
h = 0
r = 720
x = d3.scale.linear().range([ 0, r ])
y = d3.scale.linear().range([ 0, r ])
node = undefined
root = undefined

pack = d3.layout.pack()
  .size([ r, r ])
  #.sort((a, b) -> +b.amount - +a.amount)
  .value((d) -> +d.amount)
  .children((d) -> d.values)

curZoomLevel = 0

vis = d3.select("body").select("#purposePack")
  .append("svg:svg")
    .attr("width", $(window).width() - 50)
    .attr("height", $(window).height() * 0.8)
  .append("svg:g")

$window.resize(->
  w = $window.width()
  h = $window.height()  * 0.8
  vis
    .attr("width", w)
    .attr("height", h)
    .attr("transform", "translate(" + (w - r) / 2 + "," + (h - r) / 2 + ")")
).resize()

$rootNodeInfo = $("#rootNodeInfo")
$hoverNodeInfo = $("#hoverNodeInfo")
$sizeCalculator = $("#sizeCalculator")


displayedNodes = {}

setDisplayNodeInfo = (node, type) ->
  $nodeInfo = undefined
  animated = true
  $nodeInfo = switch type
    when "root" then $rootNodeInfo
    when "hover" then $hoverNodeInfo  

  if displayedNodes["root"] is node
    $nodeInfo.animate
      opacity: 0
      height: 0
      queue: false

  displayedNodes[type] = node
  setText = ($target) ->
    $target.find("h2").text node.key
    $target.find("p").text formatMagnitude(node.amount)


  $nodeInfo.stop().animate
    opacity: 0
    queue: false
    complete: ->
      setText $sizeCalculator
      setText $nodeInfo
      $nodeInfo.slideDown()
      $nodeInfo.animate
        opacity: 1
        height: $sizeCalculator.height()
        queue: false




formatPercent = d3.format(".2%")
$tip = $("<div id=\"tooltip\"></div>").html("<div></div>").hide().appendTo($body)
$tipInner = $tip.find("div")
$(document).mousemove (e) ->
  $tip.css
    top: e.pageY + 0
    left: e.pageX + 10

$(document).on "mouseover", "svg circle", ->
  d = @__data__
  $tipInner.html "<strong>" + d.key + 
              "</strong><br />" + formatMagnitude(d.amount) + " (" + formatPercent(d.amount / root.amount) + ")"
  $tip.show()

$(document).on "mouseout", "svg circle", ->
  $tip.hide()




d3.csv "aiddata-purposes-with-totals.csv/2008", (csv) ->

  #csv = csv.filter((d) -> d.code.substr(0,3) == "322"
  #maxAmount = d3.max(csv, (d) -> +d.total_amount)


  purposesNested = d3.nest()
    .key((p) -> p.category)
    .key((p) -> p.subcategory)
    .key((p) -> p.subsubcategory)
    #.key((p) -> p.name)
    .rollup((ps) -> 
      #if ps.length == 1 then ps[0].code else ps.map (p) -> p.code
      ps.map (p) ->
        key : "#{p.name} - #{p.code}"
        num : +p.total_num
        amount : +p.total_amount
    )
    .entries(csv)



  data =
    key : "AidData"
    values : purposesNested

  #data = data.values[0].values[0].values[0]
  removeSingleChildNodes(data)
  provideWithTotalAmount(data)

  node = root = data
  setDisplayNodeInfo node, "root"

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
      .on "click", (d) -> zoom (if node is d then root else d)

  fontSize = 15
  updateText = (d) => 
    text = d.key #.replace(" - [0-9]{5}$", "")
    maxLen =  Math.ceil(r * d.r / d.parent?.r  / fontSize * 2)
    if text.length < maxLen
      text
    else
      text.substr(0, maxLen) + "..."

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
        .style("opacity", (d) -> if (d.depth == (curZoomLevel + 1)) then 1 else 0)



  zoom = (d, i) ->
    if d.depth?
      curZoomLevel = d.depth
    else
      curZoomLevel = 0
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
      .style("opacity", (d) -> if (d.depth == (curZoomLevel + 1)) then 1 else 0)
      .text(updateText)

    node = d
    d3.event.stopPropagation()


  ###
  .attr("dy", (d) ->
    dy = undefined
    if d.type is "product_group"
      dy = "-2.35em"
    else if d.type is "product" and d.parent.values.length < 3
      dy = "2.35em"
    else
      dy = ".35em"
    dy
  )
  .attr("text-anchor", "middle")
  .style("opacity", (d) ->
    (if zoomLevels[d.type] <= curZoomLevel then 1 else 0)
  )
  .text (d) -> d.key
  ###

  d3.select(window).on "click", -> zoom root


