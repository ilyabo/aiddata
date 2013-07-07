config = require '../config'

require('zappa').run config.port, ->
  

  express = require('express')
  @include './layout'
  @include './views'
  @include './routes-data-extern'
  @include './routes-data'
  @include './routes-views'

  log4js = require('log4js')
  logger = null

  @configure
    development: => 
      #log4js.addAppender(log4js.consoleAppender())
      logger = log4js.getLogger('app')
      @use log4js.connectLogger logger, 
        level: log4js.levels.DEBUG
        format: ':method :url :status :response-time'
      @use errorHandler: {dumpExceptions: on}
      logger.info "Starting in development mode"

    production: => 
      log4js.configure('log4js-production.json')
      logger = log4js.getLogger('app')
      @use log4js.connectLogger logger, 
        level: log4js.levels.INFO
        format: ':method :url :status :response-time'
      @use 'errorHandler'
      logger.info "Starting in production mode"


  @include './charts/time-series'
  @include './charts/bar-hierarchy'
  @include './charts/bubbles'
  @include './charts/time-slider'

  @include './frontend/utils-aiddata'
  @include './frontend/utils'
  @include './frontend/bubbles'
  @include './frontend/horizon/horizon3'
  @include './frontend/horizon/horizon4'
  @include './frontend/query-history'
  @include './frontend/breaknsplit'



  @use 'bodyParser', 'methodOverride', @app.router
  @use 'static': __dirname + '/../static'
  @use 'static': __dirname + '/../data/static'
  @use 'static': __dirname + '/../node_modules/underscore'
  @use 'static': __dirname + '/../node_modules/d3'
  @use 'static': __dirname + '/../node_modules/queue-async'
  @use 'static': __dirname + '/../node_modules/history.js'

  #@enable 'default layout'
  #@enable 'minify'


  @app.use (err, req, res, next) ->
    console.error err
    res.status = 
    res.send "Something went wrong..."
