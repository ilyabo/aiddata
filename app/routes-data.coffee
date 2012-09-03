@include = ->

  request = require 'request'

  utils = require './data-utils'
  pg = require './pg-sql'
  mongo = require './mongo'
  purposes = require '../data/purposes'
  _ = require "underscore"

  d3 = require 'd3'
  dv = require '../lib/datavore'
  csv = require 'csv'




  loadCsvAsDvTable = do ->

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
      console.log "Loading '#{fname}' in memory"
      csv()
        .fromPath(__dirname + '/' + fname)
        .on('data', (row, index) ->
          if (index is 0) then columnNames = row.slice()
          else
            for v,i in row
              (columns[columnNames[i]] ?= []).push v
              
        )
        .on('end', (count) ->
          console.log "Loaded #{count} lines of '#{fname}' in memory"
          callback null, columns
        )
        .on('error', (err) ->
          if err? then console.error "Could not load '#{fname}'" + err.message
          callback err
        )

    numerize = (a) -> a[i] = +v for v,i in a

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

        agg.where = (fn) -> where = fn; agg

        agg.columns = ->
          columnsData = query { dims: dims, vals: vals, where: where }
          data = {}
          for d, i in columnsData
            data[rcols[i]] = d
          data

        agg

    fn 




  flowsDvTable = do ->
    columns = 
      date : "ordinal"
      donorcode : "nominal"
      recipientcode : "nominal"
      sum_amount_usd_constant : "numeric"
      purpose_code : "nominal"

    loadCsvAsDvTable '../data/static/data/cached/flows.csv', columns, (err, table) -> 
      if err? then console.log err
      else
        flowsDvTable = table

    null






  @get '/dv-flows-by-o-d.csv': ->
    unless flowsDvTable?
      #@next(new Error("Requested data is not available at the moment"))
      message = "Requested data is not available at the moment"
      console.warn message
      @send { err: message }
    else

      data = flowsDvTable.aggregate()
        .sparse()
        .by("date", "donorcode", "recipientcode")
        .sum("sum_amount_usd_constant")
        .count()
        .columns()


      @response.write "#{col for col of data}\n"
      csv()
        .from(data.date)
        .toStream(@response)
        .transform (d, i) -> vals[i] for col,vals of data




  @get '/dv-flows-by-purpose.csv': ->
    unless flowsDvTable?
      #@next(new Error("Requested data is not available at the moment"))
      @send { err: "Requested data is not available at the moment" }
    else

      data = flowsDvTable.aggregate()
        .sparse()
        .by("date", "purpose_code")
        .sum("sum_amount_usd_constant")
        .count()
        .columns()


      @response.write "#{col for col of data}\n"
      csv()
        .from(data.date)
        .toStream(@response)
        .transform (d, i) -> vals[i] for col,vals of data




  @get '/mongo-purpose-codes.json': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else
        coll.distinct "coalesced_purpose_code", (err, result) =>
          if err? then @next(err)
          else
            @send result




  @get '/mongo-aiddata-group.csv': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else
        # , date : new Date(doc.date).getFullYear() }
        # keys = (doc) -> { origin : doc.origin, dest: doc.dest }
        keys = { origin:true }   # coalesced_purpose_code:true }
        condition = { coalesced_purpose_code : "23010"}  #   (doc) -> (new Date(doc.date).getFullYear() is 2005)    # 
        initial = { ccsum : 0 }
        reduce = (obj,prev) ->  
          c = obj.commitment_amount_usd_constant
          unless isNaN(c)
            prev.ccsum += Math.round(c)

        finalize = null
        command = true
        options = null

        coll.group keys, condition, initial, reduce, finalize, command, options, (err, result) =>
          if err? then @next(err)
          else
            ###
            nested = d3.nest()
              .key((r) -> r.donor)
              .key((r) -> r.recipient)
              #.key((r) -> +r.date)
              #.key((r) -> r.purpose_code)
              #.rollup((list) -> 
              #    if list.length == 1
              #      +list[0].sum_amount_usd_constant
              #    else
              #      list.map (r) -> +r.sum_amount_usd_constant
              #)
              .map(result)
            ###
            @send utils.objListToCsv(result)



  @get '/mongo-aiddata-aggregate.csv': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else
        a = {
          $group : {
            _id : "$origin",
            total : { $sum : "$commitment_amount" }
          }
        }

        coll.aggregate a, (err, result) =>
          if err? then @next(err)
          else        
            @send utils.objListToCsv(items)




  @get '/mongo-aiddata-map-reduce.csv': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else

        prop2sum = "commitment_amount_usd_constant"

        # map = () -> 
        #   console.log "Hi"
        #   key = this.origin
        #   #origin: this.origin
        #   #dest: this.dest
        #   #date: new Date(this.date).getFullYear()

        #   value = 
        #     # sum :
        #     #   unless isNaN(this[prop2sum])
        #     #     this[prop2sum]
        #     #   else
        #     #     0
        #     count : 1

        #   emit key, value

        # reduce = (key, values) -> 
        #   sum = 0
        #   count = 0
        #   for val in values
        #     unless isNaN(val[prop2sum]) then sum += val[prop2sum]
        #     count += val.count

        #   # { count: count, sum: sum }
        #   return { count: count }


        map = () -> emit(this.origin, { count:1 })
        reduce = (key, values) -> 
          return { count: 1 }


        coll.mapReduce map, reduce, { out: { replace : 'aiddataMapReduce' } }, (err, coll) =>
          if err? then @next(err)
          else        
            coll.find().toArray (err, items) =>
              if err? then @next(err)
              else        
                @send utils.objListToCsv(items)





  @get '/wb-indicators.json': ->
    request "http://api.worldbank.org/indicator?format=json&per_page=10000", (err, response, body) =>
      unless err?
        @send JSON.parse body
      else
          @next(err)



  @get '/wb.json/:indicator/:countryCode': ->
    url =
      "http://api.worldbank.org/countries/" +
      "#{@params.countryCode}/indicators/" + 
      "#{@params.indicator}?format=json"

    console.debug "Loading #{url}"
    request url, 
    (err, response, body) =>
      unless err?
        pages = JSON.parse body
        entries = {}
        for page in pages
          for entry in page
            entries[entry.date] =
              value : entry.value
              date : entry.date             

        @send entries 
      else
          @next(err)









  @get '/aiddata-nodes.csv': ->
    pg.sql "select donor as Name,donorcode as Code from totals_for_donor_ma
        UNION 
        select recipient as Name,recipientcode as Code from totals_for_recipient_ma",
      (err, data) =>
        unless err?
          @send utils.objListToCsv(data.rows)
        else
          @next(err)


  @get '/aiddata-totals-d-r-y.csv': ->
    #sql 'select recipient,recipientcode AS code,sum,year from totals_for_recipients_mat',
    pg.sql "select
              recipientcode as recipient,
              donorcode as donor,
              sum,year
            from totals_for_recipient_to_donor_ma", # where recipientcode='CMR' and donorcode='ISR'",
      (err, data) =>
        unless err?
          [table, columns] = utils.pivotTable(data.rows, "year", "sum", ["donor", "recipient"])
          @send utils.objListToCsv(table, columns)
        else
          @next(err)


  @get '/aiddata-recipient-totals.csv': ->
    pg.sql 'select recipientcode AS recipient,sum,year from totals_for_recipient_ma',
      (err, data) =>
        unless err?
           [table, columns] = utils.pivotTable(data.rows, "year", "sum", ["recipient"])
           @send utils.objListToCsv(table, columns)
        else
          @next(err)


  @get '/aiddata-donor-totals.csv': ->
    pg.sql 'select donorcode AS donor,sum,year from totals_for_donor_ma',
      (err, data) =>
        unless err?
           [table, columns] = utils.pivotTable(data.rows, "year", "sum", ["donor"])
           @send utils.objListToCsv(table, columns)
        else
          @next(err)


  @get '/aiddata-donor-totals.json/:countryCode': ->
    unless @params.countryCode.match /^[A-Z]{3}$/
      @send "Bad country code"
      return

    countryCode = @params.countryCode

    pg.sql "select donorcode AS donor,sum,year from totals_for_donor_ma
             WHERE donorcode='#{countryCode}'",
      (err, data) =>
        unless err?
           [table, columns] = utils.pivotTable(data.rows, "year", "sum", ["donor"])
           @send table
        else
          @next(err)




  @get '/aiddata-donor-totals-nominal.json/:countryCode': ->
    unless @params.countryCode.match /^[A-Z]{3}$/
      @send "Bad country code"
      return

    countryCode = @params.countryCode
    dateQ = "TO_CHAR(COALESCE(commitment_date, start_date, to_timestamp(to_char(year, '9999'), 'YYYY')), 'YYYY')"

    pg.sql """
       SELECT 
           #{dateQ} AS date,

          aiddata2.donorcode, 

          to_char(SUM(aiddata2.commitment_amount_usd_constant), 'FM99999999999999999999')              
            AS sum_amount_usd_nominal

        FROM aiddata2

        WHERE donorcode = '#{countryCode}'

        GROUP BY
          donorcode, #{dateQ}

      """, (err, data) =>

        unless err?
           @send data.rows
        else
          @next(err)







  ###

  @get '/flows.csv': ->
    pg.sql """
       SELECT 
              --aiddata2.year, 
              to_char(COALESCE(commitment_date,  
                      start_date, to_timestamp(to_char(year, '9999'), 'YYYY')), 'YYYY'  --'YYYYMM' 
              ) as date,
              COALESCE(
              CASE aiddata2.donorcode
                  WHEN '' THEN aiddata2.donor
                  ELSE aiddata2.donorcode
              END, "substring"(aiddata2.donor, "position"(aiddata2.donor, '('))) AS donorcode, 
              COALESCE(
              CASE aiddata2.recipientcode
                  WHEN '' THEN aiddata2.recipient
                  ELSE aiddata2.recipientcode
              END, "substring"(aiddata2.recipient, "position"(aiddata2.recipient, '('))) AS recipientcode, 
              to_char(aiddata2.commitment_amount_usd_constant, 'FM99999999999999999999')   -- 'FM99999999999999999999D99')
                AS sum_amount_usd_constant, 
              COALESCE(aiddata2.aiddata_purpose_code, aiddata2.crs_purpose_code) AS purpose_code
         FROM aiddata2  --limit 5
      """, (err, data) =>
        unless err?
          numNodes = 0
          nodeToId = {}

          nodeId = (n) ->
            unless nodeToId[n]?
              nodeToId[n] = ++numNodes
            nodeToId[n]
          
          data.rows.forEach (r) -> 
            r.donorcode = nodeId(r.donorcode)
            r.recipientcode = nodeId(r.recipientcode)
          
          @send utils.objListToCsv(data.rows)

        else
          @next(err)
  ###





  @get '/flows.json': ->
    pg.sql """
       SELECT 
              --aiddata2.year, 
              to_char(COALESCE(commitment_date,  
                      start_date, to_timestamp(to_char(year, '9999'), 'YYYY')), 'YYYY'  --'YYYYMM' 
              ) as date,
              COALESCE(
              CASE aiddata2.donorcode
                  WHEN '' THEN aiddata2.donor
                  ELSE aiddata2.donorcode
              END, "substring"(aiddata2.donor, "position"(aiddata2.donor, '('))) AS donorcode, 
              COALESCE(
              CASE aiddata2.recipientcode
                  WHEN '' THEN aiddata2.recipient
                  ELSE aiddata2.recipientcode
              END, "substring"(aiddata2.recipient, "position"(aiddata2.recipient, '('))) AS recipientcode, 
              to_char(aiddata2.commitment_amount_usd_constant, 'FM99999999999999999999')   -- 'FM99999999999999999999D99')
                AS sum_amount_usd_constant, 
              COALESCE(aiddata2.aiddata_purpose_code, aiddata2.crs_purpose_code) AS purpose_code
         FROM aiddata2  
         
         --limit 50

      """, (err, data) =>
        unless err?

          flows = d3.nest()
            .key((r) -> r.donorcode)
            .key((r) -> r.recipientcode)
            .key((r) -> +r.date)
            .key((r) -> r.purpose_code)
            .rollup((list) -> 
                if list.length == 1
                  +list[0].sum_amount_usd_constant
                else
                  list.map (r) -> +r.sum_amount_usd_constant
            )
            .map(data.rows)
          @send flows

        else
          @next(err)






  # Returns a list of the known purposes
  @get '/aiddata-purposes.csv': ->
    pg.sql "select distinct(purpose_code) as code,purpose_name as name
              from donor_recipient_year_purpose_ma 
            where purpose_code is not null
            order by purpose_name
          ",
      (err, data) =>
        unless err?
          @send utils.objListToCsv purposes.provideWithPurposeCategories(purposes.groupPurposesByCode(data.rows))
        else
          @next(err)






  @get '/aiddata-purposes-with-totals.csv': ->
    pg.sql "select
              purpose_code as code,
              purpose_name as name,
              SUM(num_commitments) as total_num,
              SUM(to_number(sum_amount_usd_constant, 'FM99999999999999999999')) as total_amount
            from donor_recipient_year_purpose_ma 
            group by purpose_code, purpose_name
            order by purpose_name
          ",
      (err, data) =>
        unless err?
          @send utils.objListToCsv purposes.provideWithPurposeCategories(purposes.groupPurposesByCode(data.rows))
        else
          @next(err)



  # Returns a list of the purposes used in the database (including NULLS)
  # along with the total amounts and numbers of commitments
  @get '/aiddata-purposes-with-totals.csv/:year': ->

    if !/^[0-9]{4}$/.test(@params.year)
      @send "Something went wrong with this request URL"
      return

    year = parseInt(@params.year)

    pg.sql "select
              purpose_code as code,
              purpose_name as name,
              SUM(num_commitments) as total_num,
              SUM(to_number(sum_amount_usd_constant, 'FM99999999999999999999')) as total_amount
            from donor_recipient_year_purpose_ma 
            where year='#{year}'
            group by purpose_code, purpose_name
            order by purpose_name
          ",
      (err, data) =>
        unless err?
          @send utils.objListToCsv purposes.provideWithPurposeCategories(purposes.groupPurposesByCode(data.rows))
        else
          @next(err)



