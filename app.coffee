require('zappa').run 3000, ->
  
 # require("./includes/d3_parts")

  @use 'bodyParser', 'methodOverride', @app.router, 'static': __dirname + '/static'

  @enable 'default layout' #, 'serve jquery' #, 'minify'


  @app.use (err, req, res, next) ->
    console.error err
    res.status = 
    res.send "Something went wrong..."


  @include './layout'
  @include './views'

  utils = @include './app-utils'
  pg = @include './pg-sql'

  @configure
    development: => @use errorHandler: {dumpExceptions: on}
    production: => @use 'errorHandler'


  @get '/': -> 
    @render ffprints: {layout: 'bootstrap.eco'}

  @get '/aiddata-ffprints': -> 
    @render ffprints: {layout: 'bootstrap.eco', dataset:"aiddata"}

  @get '/aiddata-bubbles': -> 
    @render bubbles: {layout: 'bootstrap.eco', dataset:"aiddata"}


  @get '/refugees-ffprints': -> 
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



