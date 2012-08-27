@include = ->

  _ = require "underscore"

  utils = @include './data-utils'
  pg = @include './pg-sql'
  mongo = @include './mongo'
  d3 = require "d3"
  request = require "request"
  purposes = @include './aiddata/purposes'



  @get '/purpose-codes.json': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else
        coll.distinct "coalesced_purpose_code", (err, result) =>
          if err? then @next(err)
          else
            @send result




  @get '/aiddata-totals-d-r-y.json': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else
        keys = { donor:true, recipient:true, year:true }
        condition = { coalesced_purpose_code : "24030", year: 2005 }
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




  # For most purposes several different names exist
  # so we have to group them together
  groupPurposesByCode = (purposes) ->
    nopunct = (s) -> s.replace(/[\s'\.,-:;]/g, "")
    unique = {}
    for r in purposes
      if not r.code? then r.code = "00000"
      if not r.name? then r.name = "Unknown"

      r.name = r.name.trim()
      uname = r.name.toUpperCase()
      
      if not(_.has(unique, r.code))
        unique[r.code] = r
      else
        oldname = unique[r.code].name
        # prefer not to use capitalized or shortened versions
        if oldname == oldname.toUpperCase() or nopunct(r.name).length > nopunct(oldname).length
          old = unique[r.code] 
          old.name = r.name
          if old.total_amount?
            old.total_amount += r.total_amount
          if old.total_num?
            old.total_num += r.total_num

    _.values(unique)


  # Returns a list of the known purposes
  @get '/aiddata-purposes.csv': ->
    pg.sql "select distinct(purpose_code) as code,purpose_name as name
              from donor_recipient_year_purpose_ma 
            where purpose_code is not null
            order by purpose_name
          ",
      (err, data) =>
        unless err?
          @send utils.objListToCsv purposes.provideWithPurposeCategories(groupPurposesByCode(data.rows))
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
          @send utils.objListToCsv purposes.provideWithPurposeCategories(groupPurposesByCode(data.rows))
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
          @send utils.objListToCsv purposes.provideWithPurposeCategories(groupPurposesByCode(data.rows))
        else
          @next(err)



