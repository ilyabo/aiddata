root = exports ? this



root.nestPurposeDataByCategories = (csv) ->
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


root.removeSingleChildNodes = (tree) ->
  if not tree.values?
    return tree

  if tree.values.length == 1
    name = tree.key
    node = removeSingleChildNodes(tree.values[0])
    if not node.key or node.key.trim().length == 0
      node.key = name
    return node

  for i, child of tree.values
    tree.values[i] = removeSingleChildNodes(child)


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
  
  return tree







root.provideWithTotalAmount = (tree) ->
  if tree.amount or not tree.values? then return
  total = 0
  for child in tree.values
    provideWithTotalAmount child
    total += if child.amount then +child.amount else 0
  tree.amount = total