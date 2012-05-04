@include = ->

  _ = require "underscore"


  ##
  # Creates a pivot table out of a list of objects
  # returns [table, columns] 
  #          table - list of objects representing rows of the table
  #          columns - full list of the columns (empty values are omitted in the row objects)
  #
  # columnProp - for each distinct value of this prop a column will be
  #              created in the pivot table
  # cellValueProp - property to be used for the cell values of the pivot
  # rowIdProps - properties which identify a row
  # 
  # All the other properties of the input objects are ignored.
  ##
  pivotTable : (objList, columnProp, cellValueProp, rowIdProps) ->
    ##
    # nestedProp(obj, [a,b,c]) will return obj[a][b][c]
    ##
    nestedProp = (obj, props, createIfMissing) ->
      i = 0
      value = obj
      while value?  and  i < props.length
        p = props[i]
        if createIfMissing
          unless value[p]? then value[p] = {}
        value = value[p]
        i++
      value


    flattenNestedObj = (obj, propNames) ->
      copy = (obj) ->
        newobj = {}
        for key of obj
          newobj[key] = obj[key]
        newobj

      iterate = (obj, row, level) ->
        #console.log "iterate "+ level + " "+propNames[level]
        if level < propNames.length
          for key, value of obj
            o = copy(row)
            o[propNames[level]] = key
            iterate(value, o, level + 1)
        else          
          for key, value of obj
            row[key] = value
          table.push row

      table = []
      #console.log obj
      iterate(obj, {}, 0)
      #console.log _.first(table, 5)
      table

    rows = {}
    rowFor = (obj) -> 
      id = rowIdProps.map (p) -> obj[p]
      nestedProp(rows, id, true)

    newColumns = {}
    for obj in objList
      col = obj[columnProp]
      if col?
        newColumns[col] = true
        row = rowFor(obj)
        row[col] = obj[cellValueProp]

    #console.log rows
    
    columns = _.union(rowIdProps, _.keys(newColumns).sort())

    [flattenNestedObj(rows, rowIdProps), columns]





  ##
  # Generate CSV out of a list of objects (e.g. list of results of a SELECT query).
  #
  # If columns are not specified, the property names of the first element are used.
  ##
  objListToCsv : (objList, columns) ->
    unless columns
      columns = (k for k of objList[0])

    list2csv = (list) ->
      list.map((v) ->
        if (not(v?) or v.length == 0) then ""
        else if (v.indexOf? and v.indexOf(",") >= 0) then '"'+v.replace('"','\"')+'"'
        else v
      ).join(",")

    obj2csv = (obj) -> list2csv(columns.map((k) -> obj[k]))

    list2csv(columns) + "\n" + 
    objList.map(obj2csv).join("\n")



