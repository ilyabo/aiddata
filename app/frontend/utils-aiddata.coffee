@include = ->

  @coffee '/coffee/utils-aiddata.js' : ->
  
    fmt = d3.format(",.1f")

    @shortNumberFormat = (d) ->
      abs = Math.abs(d)
      if (abs >= 1e15)
        "#{fmt(d / 1e15)}P"
      else if (abs >= 1e12)
        "#{fmt(d / 1e12)}T"
      else if (abs >= 1e9)
        "#{fmt(d / 1e9)}G"
      else if (abs >= 1e6)
        "#{fmt(d / 1e6)}M"
      else if (abs >= 1e3)
        "#{fmt(d / 1e3)}k"
      else
        "#{fmt(d)}" 

    @formatMagnitudeLong = (d) -> "$#{fmt(d)}"

    @formatMagnitudeLongNoCurrency = (d) -> "#{fmt(d)}"

    @formatMagnitude = @magnitudeFormat = (d) -> "$" + shortNumberFormat(d)

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

          if tree instanceof Array
            tree.map recurse
          else
            recurse tree

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
          

        # Given a tree in which the leaves have valueAttrs. the function provides the parent nodes in 
        # the whole tree with totals for the valueAttrs over each node's children.
        #
        # Example input tree:
        #
        # {
        #     "key": "Basic education",
        #     "values": [
        #         { "key": "11220", "name": "Primary education", "amount" : 20000 },
        #         { "key": "11230", "name": "Basic life skills for youth and adults", "amount" : 30000 },
        #         { "key": "11240", "name": "Early childhood education", "amount" : 10000 }
        #     ]
        # }
        #
        # The input tree can be also an array of trees. Each of them will be processed, but no overall totals
        # will be computed summarizing all the trees.
        #
        # The valueAttrs can be a list of attributes. In this case totals will be provided for each of them.
        #
        #
        provideWithTotals: (tree, valueAttrs, childrenAttr) ->

          unless valueAttrs instanceof Array
            valueAttrs = [ valueAttrs ]


          recurse = (subtree) ->

            return unless subtree[childrenAttr]?

            for child in subtree[childrenAttr]
              recurse child

            for attr in valueAttrs
              total = 0
              for child in subtree[childrenAttr]
                total += +(child[attr] ? 0)
              subtree[attr] = total

            return subtree

          if tree instanceof Array
            tree.map recurse
          else
            recurse tree





        provideWithTotalAmount : (tree) ->
          utils.aiddata.purposes.provideWithTotals ["amount"], "values"


          

