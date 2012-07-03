width = 1700
height = 4000

tree = d3.layout.tree()
  .size([ height, width - 500 ])
  .children((d) -> d.values)

diagonal = d3.svg.diagonal().projection((d) ->
  [ d.y, d.x ]
)

vis = d3.select("#purposeTree").append("svg")
    .attr("width", width)
    .attr("height", height)
  .append("g")
    .attr("transform", "translate(40, 0)")





d3.csv "aiddata-purposes-with-totals.csv", (csv) ->
  
  scaleTransform = (x) -> x  # log10

  maxAmount = d3.max(csv, (d) -> +d.total_amount)
  colorsForAmount = new chroma.ColorScale
    #colors: ["#fff","#00441b"]
    
    colors: ['#F7E1C5', '#6A000B'],
    mode: 'hcl'
    limits: [0, scaleTransform(maxAmount)]


  purposesNested = d3.nest()
    .key((p) -> p.category)
    .key((p) -> p.subcategory)
    .key((p) -> p.subsubcategory)
    #.key((p) -> p.name)
    .rollup((ps) -> 
      #if ps.length == 1 then ps[0].code else ps.map (p) -> p.code
      ps.map (p) ->
        key : p.code +  " - " + p.name
        num : p.total_num
        amount : p.total_amount
    )
    .entries(csv)

  data =
    key : "AidData"
    values : purposesNested
  #removeSingleChildNodes(data)
  provideWithTotalAmount(data)

  nodes = tree.nodes(data)




  link = vis.selectAll("path.link")
      .data(tree.links(nodes))
    .enter().append("path")
      .attr("class", "link")
      .attr("d", diagonal)


  node = vis.selectAll("g.node")
      .data(nodes)
    .enter().append("g")
      .attr("class", "node")
      .classed("leaf",  (d) -> not d.values? )
      .attr("transform", (d) ->  "translate(" + d.y + "," + d.x + ")" )



  node.append("circle")
    .attr("r", 4.5)
    .attr("fill", (d) ->
      if d.amount? and d.amount > 0 
        colorsForAmount.getColor(scaleTransform(+d.amount))
      else 
        "#fff"
    )
    #.attr("visibility", (d) -> if d.key != "" and d.key != "undefined" then "visible" else "hidden")


  node.append("text")
    .attr("dx", (d) -> (if d.values then 0 else 8))
    .attr("dy",  (d) -> (if d.values then 15 else 3))
    .attr("text-anchor", (d) -> (if d.values then "middle" else "start"))
    .text (d) ->
      unless d.key is "undefined"
        if d.key.length > 100 then d.key.substr(0, 97)+"..." else d.key


  $('g.node.leaf').tipsy
    gravity: 'e'
    opacity: 0.9
    html: true
    title: ->
      d = d3.select(this).data()[0]
      magnitudeFormat(d.amount) + "<br>" + d.num + " commitments"


  $('g.node').not('.leaf').tipsy
    gravity: 's'
    opacity: 0.9
    html: true
    title: ->
      d = d3.select(this).data()[0]
      magnitudeFormat(d.amount)

