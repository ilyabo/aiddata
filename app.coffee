require('zappa').run 3000, ->
  

  @use 'bodyParser', 'methodOverride', @app.router
  @use 'static': __dirname + '/static'
  @use 'static': __dirname + '/node_modules/d3'
  @use 'static': __dirname + '/node_modules/crossfilter'

  #@enable 'default layout'
  #@enable 'minify'


  @app.use (err, req, res, next) ->
    console.error err
    res.status = 
    res.send "Something went wrong..."


  @include './layout'
  @include './views'

  utils = @include './data-utils'
  pg = @include './pg-sql'

  @configure
    development: => @use errorHandler: {dumpExceptions: on}
    production: => @use 'errorHandler'


  @get '/': -> 
    @render ffprints: {layout: 'bootstrap.eco'}

  @get '/ffprints': -> 
    @render ffprints: {layout: 'bootstrap.eco'}

  @get '/bubbles': -> 
    @render bubbles: {layout: 'bootstrap.eco'}
 
  @get '/flowmap': -> 
    @render flowmap: {layout: 'bootstrap.eco'}
 
  @get '/chord': -> 
    @render chord: {layout: 'bootstrap.eco'}
 
  @get '/crossfilter': -> 
    @render crossfilter: {layout: 'bootstrap.eco'}
 
  @get '/time-series': -> 
    @render tseries: {layout: 'bootstrap.eco'}


  @get '/ffprints?refugees': -> 
    @render ffprints: {layout: 'bootstrap.eco', dataset: "refugees"}

  ###
  @get '/': -> 
    sql 'select * from group_by_donor_recipient_year_purpose_ma limit 5 offset 0',
      (err, data) =>
        @render index: {err, data, layout: 'ffprints'}
  ###

  #@get '/data.js/:id': ->


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


  @get '/flows.csv': ->
    pg.sql """
       SELECT 
              --aiddata2.year, 
              to_char(COALESCE(commitment_date,  start_date, to_timestamp(to_char(year, '9999'), 'YYYY')), 'YYYYMM') as date,
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
         FROM aiddata2  --limit 50
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

          console.log utils.objListToCsv(nodeToId)
          
          @send utils.objListToCsv(data.rows)

        else
          @next(err)



