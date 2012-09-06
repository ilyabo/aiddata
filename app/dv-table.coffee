dv = require '../lib/datavore'
csv = require 'csv'



@loadFromCsv = do ->

  fn = (fname, columnTypes, callback) ->
    
    loadCsvAsColumns fname, (err, csvColumns) -> 
      if err? then callback err
      else
        table = dv.table()

        for col of csvColumns
          unless col of columnTypes
            columnTypes[col] = "unknown"

        for col, type of columnTypes
          unless (col of csvColumns)
            callback new Error("Column data for '#{col}' is not supplied")
            return null

          d = csvColumns[col]
          if type is "numeric" then d = numerize d
          table.addColumn col, d, dv.type[type]

        improveDv table
        callback null, table

  loadCsvAsColumns = (fname, callback) ->
    columnNames = []
    columns = {}
    console.log "Loading '#{fname}'"
    csv()
      .fromPath(__dirname + '/' + fname)
      .on('data', (row, index) ->
        if (index is 0) then columnNames = row.slice()
        else
          for v,i in row
            (columns[columnNames[i]] ?= []).push v
            
      )
      .on('end', (count) ->
        console.log "Loaded #{count} lines of '#{fname}'"
        callback null, columns
      )
      .on('error', (err) ->
        if err? then console.error "Could not load '#{fname}'" + err.message
        callback err
      )

  numerize = (a) -> a[i] = +v for v,i in a

  fn 



improveDv = (table) ->

  columnIndex = (name) ->
    for col,index in table
      if col.name is name then return index
    console.warn "Column '#{name}' not found. Available columns: #{(c.name for c in table)}"
    return null

  table.aggregate = ->
    query = table.query
    dims = []
    vals = []
    rcols = []
    agg = {}
    where = null
    rename = {}
    agg.sparse = -> query = table.sparse_query; agg
    agg.count = -> vals.push dv.count(); rcols.push("count"); agg

    agg.by = (cols...) -> 
      for c in cols
        rcols.push c
        dims.push(columnIndex(c))
      agg

    pushVals = (columns, fn) ->
      for c in columns
        rcols.push c
        vals.push fn(columnIndex(c))
      agg

    agg.sum = (cols...) -> pushVals cols, dv.sum
    agg.avg = (cols...) -> pushVals cols, dv.avg
    agg.min = (cols...) -> pushVals cols, dv.min
    agg.max = (cols...) -> pushVals cols, dv.max
    agg.variance = (cols...) -> pushVals cols, dv.variance
    agg.stdev = (cols...) -> pushVals cols, dv.stdev

    agg.where = (fn) ->
      where = (table, row) ->
        get = (field) -> table.get(field, row)
        fn(get)
      agg

    agg.as = (from, to) -> rename[from] = to; agg

    agg.columns = ->
      columnsData = query { dims: dims, vals: vals, where: where }
      data = {}
      for d, i in columnsData
        col = rcols[i]
        col = rename[col] if rename[col]?
        data[col] = d
      data

    agg
