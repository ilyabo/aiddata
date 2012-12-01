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

  cachedFlowsFile = if @app.settings.env is "development"
    "flows-sample.csv"
  else
    "flows.csv"


  
  # used to validate the user input in commitments queries
  aiddataNodeNames = {}
  csv()
    .fromPath(__dirname + '/../data/static/data/cached/aiddata-nodes.csv')
    .on('data', (row, index) ->
      aiddataNodeNames[row[0]] = row[1]
    )



  getFlows = caching.loader { preload : true }, (callback) ->

    columns = 
      date : "ordinal"
      donor : "nominal"
      recipient : "nominal"
      sum_amount_usd_constant : "numeric"
      purpose : "nominal"


    dv.loadFromCsv "../data/static/data/cached/#{cachedFlowsFile}", columns, callback




  getPurposeTree = caching.loader { preload : true }, (callback) ->

    queue()
      .defer((cb) ->
        fs.readFile 'data/static/data/purpose-categories.json', (err, result) ->
          result = JSON.parse(result) unless err?
          console.log "Purpose categories file loaded"
          cb(err, result)
      )
      .defer((cb) ->
        console.log "Loading category list from postgres..."
        pg.sql(
          "select
              distinct(coalesced_purpose_code) as code,
              coalesced_purpose_name as name
            from aiddata2
            order by coalesced_purpose_name", 
            (err, data) ->
              if err?
                console.log "Category list couldn't be loaded: " + err
              else
                console.log "Category list loaded from postgres"
              cb(err, data)
        )
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

          console.log "Purpose tree was built"
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




  @get '/dv/flows/breaknsplit.csv': ->
    getFlows (err, table) => 
      if err? then @next err
      else

        agg = table.aggregate()
          .sparse()
          .sum("sum_amount_usd_constant")
          .count()



        # if @query.breakby
        #   breakby = @query.breakby.split(",")
          
        #   for b in breakby
        #     unless b in ["date", "donor", "recipient", "purpose"]
        #       @send { err: "Bad breakby" }
        #       return
        #     breakby.push b

        #   agg.by.apply(this, breakby)


        # if @query.purpose?
        #   purpose = @query.purpose
        #   if (purpose? and not /^[0-9]{1,5}$/.test purpose)
        #     @send { err: "Bad purpose" }
        #     return

        # #console.log @query.donor
        # if @query.donor? or @query.recipient?
        #   [donor, recipient] = [@query.donor, @query.recipient]

        #   re = /^[A-Za-z\-0-9\(\)]{2,10}$/
        #   if (donor? and not re.test donor) or (recipient and not re.test recipient)
        #     @send { err: "Bad donor/recipient" }
        #     return

        # if donor? or recipient? or purpose?
        #   agg.where((get) -> 
        #     (not(donor) or get("donor") is donor) and 
        #     (not(recipient) or get("recipient") is recipient) and
        #     (not(purpose) or get("purpose").indexOf(purpose) == 0)
        #   )

        plusYears = (date, numYears) ->
          d = new Date(date.getTime()); d.setFullYear(d.getFullYear() + numYears); d

        # used to sanity-filter the input data
        minDate = plusYears(new Date(), -100).getFullYear()
        maxDate = plusYears(new Date(), +5).getFullYear()

        agg.by.apply(this, @query.breakby?.split(","))

        filter = (if @query.filter? then JSON.parse(@query.filter) else null)
        
        if filter?.purpose?
          filter.purpose = filter.purpose.map (v) ->
            if /^[0-9]*\*[0-9]*$/.test(v)
              re = "^"+v.replace("*", ".*")
              console.log re
              new RegExp(re)
            else
              v

        findMatch = (values, propVal) ->                
          found = false
          for v in values
            if v instanceof RegExp
              if v.test(propVal)
                found = true
                break
            else
              if (propVal is v)
                found = true
                break
          found



        agg.where((get) ->

          return false unless (minDate <= +get("date") <= maxDate)

          if filter?
            for prop, values of filter

              found = (
                if prop is "node"
                  (findMatch(values, get("donor")) or findMatch(values, get("recipient")))
                else
                  findMatch(values, get(prop))
              )


              return false unless found

          return true
        )

        data = agg.columns()

        anykey = d3.keys(data)[0]
        anycolumn = data[anykey]

        @response.write "#{col for col of data}\n"
        csv()
          .from(anycolumn)
          .toStream(@response)
          .transform (d, i) -> vals[i] for col,vals of data








  @get '/dv/flows/by/od.csv': ->
    getFlows (err, table) => 
      if err? then @next err
      else
        agg = table.aggregate()
          .sparse()
          .by("date", "donor", "recipient")
          .sum("sum_amount_usd_constant")
          .count()

        if @query.purpose?
          purpose = @query.purpose

          re = /^[0-9]{1,5}$/
          if (purpose? and not re.test purpose)
            @send { err: "Bad purpose" }
            return

          agg.where((get) -> get("purpose").indexOf(purpose) == 0)

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
          .by("date", "purpose")
          .sum("sum_amount_usd_constant")
          .as("sum_amount_usd_constant", "sum")
          .as("purpose", "code")
          .count()

        if @query.origin? or @query.dest?
          [origin, dest] = [@query.origin, @query.dest]

          re = /^[A-Za-z\-0-9\,\.\s\(\)]{2,64}$/
          if (origin? and not re.test origin) or (dest and not re.test dest)
            @send { err: "Bad origin/dest" }
            return
              
          agg.where((get) -> 
            (not(origin) or get("donor") is origin) and (not(dest) or get("recipient") is dest)
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




  #getFlowTotalsByPurposeAndDate = caching.loader { preload : true }, (callback) ->

  getFlowTotalsByPurposeAndDate = (origin, dest, node) ->
    (callback) ->
      getFlows (err, table) -> 
        if err? then callback err
        else
          agg = table.aggregate().sparse()
            .by("date", "purpose")
            .sum("sum_amount_usd_constant")
            .as("sum_amount_usd_constant", "sum")
            .as("purpose", "code")
            .count()

          if origin? or dest? or node?
            agg.where((get) -> 
              (not(origin) or (get("donor") is origin)) and 
              (not(dest) or (get("recipient") is dest)) and
              (not(node) or (get("donor") is node)  or (get("recipient") is node)) 
            )

          data = agg.columns()

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

    # 'node' means we need flows of a specific node, both incoming and outgoing
    if @query.origin? or @query.dest? or @query.node
      [ origin, dest, node ] = [ @query.origin, @query.dest, @query.node ]

      re = /^.{2,64}$/
      if (origin? and not re.test origin) or (dest and not re.test dest) or (node and not re.test node)
        @send { err: "Bad origin/dest/node" }
        return


    queue()
      .defer(getPurposeTree)
      .defer(getFlowTotalsByPurposeAndDate(origin, dest, node))
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
                key : tree.code + "*"
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



  selectYear = "TO_CHAR(COALESCE(commitment_date, start_date, to_timestamp(to_char(year, '9999'), 'YYYY')), 'YYYY')"
  selectPurposeCode = "COALESCE(aiddata2.aiddata_purpose_code, aiddata2.crs_purpose_code, '99000')"
  selectPurposeName = "COALESCE(aiddata2.aiddata_purpose_name, aiddata2.crs_purpose_name, '99000')"



  @get '/commitments.json': ->
    pageSize = 100
    page = 0

    cond = ""

    # if @query.node
    #   node = @query.node

    #   re = /^[A-Za-z\-0-9\,\.\s\(\)]{2,64}$/
    #   unless re.test node
    #     @send { err: "Bad node" }
    #     return
    #   else
    #     cond += " AND (recipientcode='#{node}' OR recipient='#{node}' OR donor='#{node}' OR donorcode='#{node}')"

    if @query.nodeName
      nodeName = @query.nodeName

      unless aiddataNodeNames[nodeName]?
        @send { err: "Bad nodeName '#{nodeName}'"}
        return
      else
        nodeName = nodeName.replace(/'/g, "\\'")
        cond += " AND (recipient='#{nodeName}' OR donor='#{nodeName}')"


    if @query.purpose
      purpose = @query.purpose
      re = /^[0-9]{0,10}\*?$/

      unless re.test purpose
        @send { err: "Bad purpose" }
        return
      else
        if purpose.indexOf("*") >= 0
          unless purpose is "*"
            purpose = purpose.replace("*", "%")
            cond += " AND (#{selectPurposeCode} like '#{purpose}')"
        else
          cond += " AND (#{selectPurposeCode}='#{purpose}')"


    if @query.year
      year = @query.year
      re = /^[0-9]{4}$/

      unless re.test year
        @send { err: "Bad year" }
        return
      else
        cond += " AND #{selectYear} = '#{year}'"


    if @query.page
      unless /^[0-9]{0,15}$/.test @query.page
        @send { err: "Bad page" }
        return
      else
        offset = @query.page


    if @query.pagecount?
      q = "count(*) AS count, #{pageSize} AS pagesize, CEIL(count(*)/#{pageSize}) AS pagecount"
      order = ""
      limit = ""
    else
      fields = [
          #'aiddata_id',
          'year',
          'commitment_date',
          'start_date',
          'end_date',
          'donor',
          #'donorcode',
          'umbrella',
          #'donor_project_id',
          #'crsid',
          'financing_agency',
          'donor_type',
          #'bi_multi',
          'recipient',
          #'recipientcode',
          'private_recipient',
          'implementing_agency',
          'channelcode',
          'borrower',
          'beneficiary',
          'guarantor',
          'other_involved_institutions',
          'commitment_amount',
          'commitment_amount_currency',
          'commitment_amount_usd_nominal',
          'commitment_amount_usd_constant',
          'disbursement_amount',
          'disbursement_amount_currency',
          'disbursement_amount_usd_nominal',
          'disbursement_amount_usd_constant',
          'total_project_cost',
          'total_project_cost_currency',
          'total_project_cost_usd_nominal',
          'total_project_cost_usd_constant',
          'title',
          'short_description',
          'short_description_original_language',
          'long_description',
          'long_description_original_language',
          'additional_info',
          'additional_info_original_language',
          'flow_type',
          'crs_flow_name',
          'number_repayments_per_year',
          'repay_type',
          'loan_term',
          'grace_period',
          'interest_rate',
          'second_interest_rate',
          'grant_element',
          'cancelled',
          'repay_date_first',
          'repay_date_last',
          'untied_amount_usd_nominal',
          'partial_tied_amount_usd_nominal',
          'tied_amount_usd_nominal',
          'received_amount_usd_nominal',
          'irtc_amount_usd_nominal',
          'expert_commitment_amount_usd_nominal',
          'expert_extended_amount_usd_nominal',
          'export_credit_amount_usd_nominal',
          'outstanding_amount_usd_nominal',
          'arrears_principal_amount_usd_nominal',
          'arrears_interest_amount_usd_nominal',
          'future_ds_principal_amount_usd_nominal',
          'future_ds_interest_amount_usd_nominal',
          'interest_amount_usd_nominal',
          'region',
          'location',
          'source',
          'language',
          #'biodiversity',
          #'climate',
          #'desertification',
          #'crs_purpose_code',
          #'crs_purpose_name',
          'gender',
          'trade',
          #'pdgg',
          #'ftc',
          'sector_programme',
          'sector',
          #'sector_code',
          'associated_financing',
          #'initial_report',
          #'finance_t',
          #'environmental_impact_assessment',
          #'environment',
          #'investment_project',
          'aiddata_purpose_code',
          'aiddata_purpose_name',
          'aiddata_activity_code',
          'aiddata_activity_name',
          'aiddata_feasibility_study',
          'aiddata_techinical_assistance',
          #'coalesced_purpose_code',
          #'coalesced_purpose_name',
          ]
      q = fields.join(",")+","+
        "to_char(commitment_amount_usd_constant, 'FM99999999999999999999') as amount_constant,
        #{selectPurposeCode} AS purpose_code,
        #{selectPurposeName} AS purpose_name
        "

      order = "order by commitment_amount_usd_constant desc"
      limit = "limit #{pageSize} OFFSET #{pageSize * page}"



    query = "
      select #{q}
       from aiddata2
      WHERE
        commitment_amount_usd_constant is not null
        #{cond}
      #{order}
      #{limit}
    "
    #console.log query
    pg.sql query,
      (err, data) =>
        unless err?
          @send data.rows
        else
          @next(err)





  @get '/flows.csv': ->
    pg.sql """
       SELECT 
              COALESCE(
              CASE aiddata2.donorcode
                  WHEN '' THEN aiddata2.donor
                  ELSE aiddata2.donorcode
              END, "substring"(aiddata2.donor, "position"(aiddata2.donor, '('))) AS donor, 
              COALESCE(
              CASE aiddata2.recipientcode
                  WHEN '' THEN aiddata2.recipient
                  ELSE aiddata2.recipientcode
              END, "substring"(aiddata2.recipient, "position"(aiddata2.recipient, '('))) AS recipient, 
              to_char(aiddata2.commitment_amount_usd_constant, 'FM99999999999999999999')   -- 'FM99999999999999999999D99')
                AS sum_amount_usd_constant, 
              #{selectYear} AS date,
              #{selectPurposeCode} AS purpose
              
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



