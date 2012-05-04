require('zappa').run 3000, ->
  

  @use 'bodyParser', 'methodOverride', @app.router
  @use 'static': __dirname + '/static'
  @use 'static': __dirname + '/node_modules/d3'

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
    @render flowmap: {layout: 'bootstrap.eco'}
 
  @get '/crossfilter': -> 
    @render flowmap: {layout: 'bootstrap.eco'}
 
  @get '/time-series': -> 
    @render flowmap: {layout: 'bootstrap.eco'}


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



