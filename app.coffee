require('zappa').run 3000, ->
  

  @use 'bodyParser', 'methodOverride', @app.router
  @use 'static': __dirname + '/static'
  @use 'static': __dirname + '/node_modules/d3'
  @use 'static': __dirname + '/node_modules/crossfilter'
  @use 'static': __dirname + '/node_modules/cubism'

  #@enable 'default layout'
  #@enable 'minify'


  @app.use (err, req, res, next) ->
    console.error err
    res.status = 
    res.send "Something went wrong..."


  @include './layout'
  @include './views'
  @include './queries'


  @configure
    development: => @use errorHandler: {dumpExceptions: on}
    production: => @use 'errorHandler'

