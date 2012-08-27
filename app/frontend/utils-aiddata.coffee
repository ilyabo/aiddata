fmt = d3.format(",.0f")

@formatMagnitudeLong = (d) -> "$#{fmt(d)}"

@formatMagnitude = @magnitudeFormat = (d) ->
  if (d >= 1e15)
    "$#{fmt(d / 1e15)}P"
  else if (d >= 1e12)
    "$#{fmt(d / 1e12)}T"
  else if (d >= 1e9)
    "$#{fmt(d / 1e9)}G"
  else if (d >= 1e6)
    "$#{fmt(d / 1e6)}M"
  else if (d >= 1e3)
    "$#{fmt(d / 1e3)}k"
  else
    "$#{fmt(d)}" 

@formatMagnitudeShort = @shortMagnitudeFormat = (d) -> formatMagnitude(d)




@utils ?= {} 

@utils.aiddata =

  purposes :

    fromCsv : (csv) ->

      data = utils.aiddata.purposes.nestPurposeDataByCategories(csv)
      utils.aiddata.purposes.removeSingleChildNodes(data)
      utils.aiddata.purposes.provideWithTotalAmount(data)

      return data


    nestPurposeDataByCategories : (csv) ->

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

      return data =
        key : "AidData"
        values : purposesNested


    removeSingleChildNodes : (tree) ->

      recurse = (subtree) ->
        if not subtree.values?
          return subtree

        if subtree.values.length == 1
          name = subtree.key
          node = recurse(subtree.values[0])
          if not node.key or node.key.trim().length == 0
            node.key = name
          return node

        for i, child of subtree.values
          subtree.values[i] = recurse(child)

        return subtree

      recurse(tree)

      ###
      values = [] 
      for i, child of tree.values
        console.log("Check in '#{tree.key}' '"+child.key + "'")
        if child.key.trim().length == 0  or child.values?.length == 1
          console.log("Replace '#{tree.key}' '"+child.key+"' with " + child.values.length + " children: " + child.values.map((d)->d.key).join(","))
          for c in child.values        
            values.push removeSingleChildNodes(c)
        else
          values.push removeSingleChildNodes child

        #res = removeSingleChildNodes(child)
        #tree.values[i] = res
      tree.values = values
      ###
      


    provideWithTotalAmount : (tree) ->

      recurse = (subtree) ->
        if subtree.amount or not subtree.values? then return
        total = 0
        for child in subtree.values
          recurse(child)
          total += if child.amount then +child.amount else 0
        subtree.amount = total
        return subtree

      recurse(tree)

      

