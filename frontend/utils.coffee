root = exports ? this

root.isNumber = (n) ->
    !isNaN(parseFloat(n))  and  isFinite(n)

root.asNumber = (str) ->
      if (not str?) or (str.trim() == "") then NaN else Number(str)


root.loadData = ->
  
  loadedCallback = null
  toload = {}
  data = {}

  loaded = (name, d) ->
    delete toload[name]
    data[name] = d
    notifyIfAll()

  notifyIfAll = ->
    if loadedCallback?  and  d3.keys(toload).length == 0
      loadedCallback data

  loader =

    json : (name, url) ->
      toload[name] = url
      d3.json url, (d) -> loaded name, d
      loader

    csv : (name, url) ->
      toload[name] = url
      d3.csv url, (d) -> loaded name, d
      loader

    onload : (callback) ->
      loadedCallback = callback
      notifyIfAll()
      loader

  loader


root.winkelTripel =
  
  () ->
    dx = 0; dy = 0
    scale = 1.0;
    phi1 = Math.acos(2/Math.PI)
    cos_phi1 = Math.cos(phi1)

    sinc = (x) -> Math.sin(x) / x
    radians = (degrees) -> degrees * Math.PI / 180
    
    proj = (coords) ->
      lplam = radians(coords[0])
      lpphi = radians(coords[1])

      c = 0.5 * lplam
      cos_lpphi = Math.cos(lpphi)
      alpha = Math.acos(cos_lpphi * Math.cos(c))

      unless alpha is 0
        sinc_alpha = sinc(alpha)
        x = 2.0 * cos_lpphi * Math.sin(c) / sinc_alpha
        y = Math.sin(lpphi) / sinc_alpha
      else
        x = y = 0.0

      x = (x + lplam * cos_phi1) * 0.5
      y = (y + lpphi) * 0.5

      y = -y

      [x*scale+dx, y*scale+dy]

    proj.scale = (x) -> if !arguments.length then scale; else scale=+x; proj
    proj.translate = (x) -> if !arguments.length then [dx,dy] else dx =+x[0]; dy=+x[1]; proj

    proj




root.provideCountryNodesWithCoords = 

  (nodes, nodeAttrs, countries, countryAttrs) ->

    { code: ncode, lat:nlat, lon:nlon } = nodeAttrs
    { code: ccode, lat:clat, lon:clon } = countryAttrs

    countriesByCode = {}
    for c in countries
      countriesByCode[c[ccode]] = c

    for node in nodes
      c = countriesByCode[node[ncode]]
      if c?
        node[nlat] = c[clat]
        node[nlon] = c[clon]



root.provideNodesWithTotals =

    (data, conf) ->
      max = 0
      totals = {}
      for flow in data.flows
        origin = flow[conf.flowOriginAttr]
        dest = flow[conf.flowDestAttr]

        totals[origin] ?= {}
        totals[dest] ?= {}

        for attrGroup, props of conf.flowMagnAttrs
          
          o = totals[origin][attrGroup] ?= {}
          d = totals[dest][attrGroup] ?= {}

          o.outbound ?= []
          d.inbound ?= []

          for attr,i in props.attrs
            o.outbound[i] ?= 0
            d.inbound[i] ?= 0

            magnitude = asNumber(flow[attr])
            unless isNaN(magnitude)
              o.outbound[i] += magnitude
              d.inbound[i] += magnitude
              if (o.outbound[i] > max) then max = o.outbound[i]
              if (d.inbound[i] > max) then max = d.inbound[i]

      for node in data.nodes
        nodeId = node[conf.nodeIdAttr]
        node.totals = totals[nodeId]


root.calcMaxTotalMagnitudes = (data, conf) ->
    # max of totals
    totalsMax = {}
    for attrGroup, props of conf.flowMagnAttrs
      max = (dir, attr) -> ( 
        d3.max(data.nodes, (node) -> node.totals?[attrGroup][dir]?[attr]) 
      )
      
      max_out = (max('outbound', attr)  for attr of props.attrs)
      max_in = (max('inbound', attr)  for attr of props.attrs)

      totalsMax[attrGroup] =
        outbound : max_out
        inbound : max_in
        max : Math.max(d3.max(max_out), d3.max(max_in))
    
    totalsMax
