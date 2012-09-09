@include = ->


  _ = require 'underscore'
  fs = require 'fs'
  d3 = require 'd3'
  csv = require 'csv'
  queue = require 'queue-async'

  pg = require './pg-sql'
  dv = require './dv-table'
  utils = require './data-utils'
  pu = require '../data/purposes'
  aidutils = require './frontend/utils-aiddata'
  caching = require './caching-loader'



  getFlows = caching.loader { preload : true }, (callback) ->

    columns = 
      date : "ordinal"
      donorcode : "nominal"
      recipientcode : "nominal"
      sum_amount_usd_constant : "numeric"
      purpose_code : "nominal"

    dv.loadFromCsv '../data/static/data/cached/flows.csv', columns, callback




  getPurposeTree = caching.loader { preload : true }, (callback) ->

    queue()
      .defer((cb) ->
        fs.readFile 'data/static/data/purpose-categories.json', (err, result) ->
          result = JSON.parse(result) unless err?
          cb(err, result)
      )
      .defer(
        pg.sql 
          "select
              distinct(coalesced_purpose_code) as code,
              coalesced_purpose_name as name
            from aiddata2
            order by coalesced_purpose_name"
      )
      .await (err, results) =>
        if err? then callback(err)
        else
          [ cats, { 'rows': purposes } ] = results

          # insert purpose into the tree of the categories
          # by so that the purpose code corresponds to the prefix
          insert = (p, tree) ->
            if tree.values?
              for e in tree.values
                if p.code?.indexOf(e.code) is 0  # startsWith
                  return insert(p, e)

            tree.values ?= []
            tree.values.push { name:p.name, code:p.code }
            tree



          insert(p, cats) for p in pu.groupPurposesByCode purposes

          callback(null, cats)


          # cats = pu.provideWithPurposeCategories pu.groupPurposesByCode data.rows

          # nested = d3.nest()
          #   .key((p) -> p.category)
          #   .key((p) -> p.subcategory)
          #   #.key((p) -> p.subsubcategory)
          #   #.key((p) -> p.name)
          #   # .rollup((ps) -> 
          #   #   #if ps.length == 1 then ps[0].code else ps.map (p) -> p.code
          #   #   ps.map (p) ->
          #   #     key : p.code
          #   #     name : p.name
          #   # )
          #   .entries(cats)

          # data = aidutils.utils.aiddata.purposes.removeSingleChildNodes {
          #   key : "AidData"
          #   values : nested
          # }


          #callback null, data





  @get '/dv/flows/by/od.csv': ->
    getFlows (err, table) => 
      if err? then @next err
      else
        agg = table.aggregate()
          .sparse()
          .by("date", "donorcode", "recipientcode")
          .sum("sum_amount_usd_constant")
          .count()

        if @query.purpose?
          purpose = @query.purpose

          re = /^[0-9]{1,5}$/
          if (purpose? and not re.test purpose)
            @send { err: "Bad purpose" }
            return

          agg.where((get) -> get("purpose_code").indexOf(purpose) == 0)

        data = agg.columns()

        @response.write "#{col for col of data}\n"
        csv()
          .from(data.date)
          .toStream(@response)
          .transform (d, i) -> vals[i] for col,vals of data








  @get '/dv/flows/by/purpose.csv': -> 

    getFlows (err, table) =>
      if err? then @next err
      else
        agg = table.aggregate().sparse()
          .by("date", "purpose_code")
          .sum("sum_amount_usd_constant")
          .as("sum_amount_usd_constant", "sum")
          .as("purpose_code", "code")
          .count()

        if @query.origin? or @query.dest?
          [origin, dest] = [@query.origin, @query.dest]

          re = /^[A-Za-z\-0-9]{2,10}$/
          if (origin? and not re.test origin) or (dest and not re.test dest)
            @send { err: "Bad origin/dest" }
            return
              
          agg.where((get) -> 
            (not(origin) or get("donorcode") is origin) and (not(dest) or get("recipientcode") is dest)
          )


        data = agg.columns()

        @response.write "#{col for col of data}\n"
        csv()
          .from(data.date)
          .toStream(@response)
          .transform (d, i) -> vals[i] for col,vals of data
      










  @get '/purposes.json': -> 
    getPurposeTree (err, data) =>
      if err? then @next(err)
      else
        @send data
          
  
  # input: { col1:["a", "b"], col2:["A", "B"], ... } 
  # output: [ {col1:"a", col2:"b"}, {col1:"A", col2:"B"}, ... ]
  columnsAsRows = do ->
    anyProp = (obj) -> return prop for prop of obj
    (data) ->
      anyColumn = anyProp(data)
      length = data[anyColumn].length
      rows = []
      for i in [0..length-1]
        row = {}
        row[f] = data[f][i] for f of data
        rows.push row
      rows




  getFlowTotalsByPurposeAndDate = caching.loader { preload : true }, (callback) ->
    getFlows (err, table) -> 
      if err? then callback err
      else
        data = table.aggregate().sparse()
          .by("date", "purpose_code")
          .sum("sum_amount_usd_constant")
          .as("sum_amount_usd_constant", "sum")
          .as("purpose_code", "code")
          .count()
          .columns()

        rows = columnsAsRows(data)

        nested = d3.nest()
          .key((d) -> d.code)
          .key((d) -> d.date)
          .rollup((arr) ->
            for d in arr
              delete d.code; delete d.date
              #d.sum = ~~(d.sum / 1000)
            if arr.length is 1 then arr[0] else arr
          )
          .map(rows)

        callback null, nested




  @get '/purposes-with-totals.json': ->

    if @query.origin? or @query.dest?
      [ origin, dest ] = [ @query.origin, @query.dest ]

      re = /^[A-Za-z\-0-9]{2,10}$/
      if (origin? and not re.test origin) or (dest and not re.test dest)
        @send { err: "Bad origin/dest" }
        return


    queue()
      .defer(getPurposeTree)
      .defer(getFlowTotalsByPurposeAndDate)
      .await (err, results) =>

        if err? then @next(err)
        else
          [ purposeTree, flowsByPurpose ] = results

          # provide the leaves (not the parent nodes!) with totals

          recurse = (tree) ->
            unless tree.values?
              # leaf nodes
              t =   
                key : tree.code
                name : tree.name
                #totals : flowsByPurpose[tree.code]

              # flatten sum and count attrs to simplify "provideWithTotals"
              for date, vals of flowsByPurpose[tree.code]
                for name, v of vals
                  t["#{name}_#{date}"] = v

            else
              t =
                #key : tree.code
                name : tree.name
                values : (recurse(n) for n in tree.values)

            t

          # the tree is deeply cloned 
          # so that the tree in the cache stays intact


          @send recurse(purposeTree)




















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
              COALESCE(aiddata2.aiddata_purpose_code, aiddata2.crs_purpose_code, '99000') AS purpose_code
         FROM aiddata2  --limit 5
      """, (err, data) =>
        unless err?
          ###
          numNodes = 0
          nodeToId = {}

          nodeId = (n) ->
            unless nodeToId[n]?
              nodeToId[n] = ++numNodes
            nodeToId[n]
          
          data.rows.forEach (r) -> 
            r.donorcode = nodeId(r.donorcode)
            r.recipientcode = nodeId(r.recipientcode)
          ###
          
          @send utils.objListToCsv(data.rows)

        else
          @next(err)
  





  # @get '/flows.json': ->
  #   pg.sql """
  #      SELECT 
  #             --aiddata2.year, 
  #             to_char(COALESCE(commitment_date,  
  #                     start_date, to_timestamp(to_char(year, '9999'), 'YYYY')), 'YYYY'  --'YYYYMM' 
  #             ) as date,
  #             COALESCE(
  #             CASE aiddata2.donorcode
  #                 WHEN '' THEN aiddata2.donor
  #                 ELSE aiddata2.donorcode
  #             END, "substring"(aiddata2.donor, "position"(aiddata2.donor, '('))) AS donorcode, 
  #             COALESCE(
  #             CASE aiddata2.recipientcode
  #                 WHEN '' THEN aiddata2.recipient
  #                 ELSE aiddata2.recipientcode
  #             END, "substring"(aiddata2.recipient, "position"(aiddata2.recipient, '('))) AS recipientcode, 
  #             to_char(aiddata2.commitment_amount_usd_constant, 'FM99999999999999999999')   -- 'FM99999999999999999999D99')
  #               AS sum_amount_usd_constant, 
  #             COALESCE(aiddata2.aiddata_purpose_code, aiddata2.crs_purpose_code) AS purpose_code
  #        FROM aiddata2  
         
  #        --limit 50

  #     """, (err, data) =>
  #       unless err?

  #         flows = d3.nest()
  #           .key((r) -> r.donorcode)
  #           .key((r) -> r.recipientcode)
  #           .key((r) -> +r.date)
  #           .key((r) -> r.purpose_code)
  #           .rollup((list) -> 
  #               if list.length == 1
  #                 +list[0].sum_amount_usd_constant
  #               else
  #                 list.map (r) -> +r.sum_amount_usd_constant
  #           )
  #           .map(data.rows)
  #         @send flows

  #       else
  #         @next(err)






  # Returns a list of the known purposes
  @get '/aiddata-purposes.csv': ->
    pg.sql "select distinct(purpose_code) as code,purpose_name as name
              from donor_recipient_year_purpose_ma 
            where purpose_code is not null
            order by purpose_name
          ",
      (err, data) =>
        unless err?
          @send utils.objListToCsv pu.provideWithPurposeCategories(pu.groupPurposesByCode(data.rows))
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
          @send utils.objListToCsv pu.provideWithPurposeCategories(pu.groupPurposesByCode(data.rows))
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
          @send utils.objListToCsv pu.provideWithPurposeCategories(pu.groupPurposesByCode(data.rows))
        else
          @next(err)



