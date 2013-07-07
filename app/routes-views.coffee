@include = ->

  @get '/': -> @render 'bubbles', layout: 'layout'
  @get '/bubbles': -> @render 'bubbles', layout: 'layout'
  @get '/breaknsplit': -> @render 'breaknsplit', layout: 'layout'
  @get '/horizon3': -> @render 'horizon3', layout: 'layout'
  @get '/horizon4': -> @render 'horizon4', layout: 'layout'
 



  config = require '../config'

  menu = 
    bubbles : "Bubbles"

    horizon3 : "Horizons"

    horizon4 : "Horizons (small)"

    breaknsplit : "Break'n'split"


  @view layout: ->
    doctype 5
    html ->
      head ->    

        style '@import url("libs/bootstrap/css/bootstrap.css")'
        style '@import url("libs/bootstrap/css/bootstrap-responsive.css")'
        style '@import url("css/layout.css")'
        style 'body { padding-top: 30px; }'

        script -> 'dynamicDataPath = "data/";'
        script src: 'js/browser-check.js'
        script src: 'libs/jquery/jquery-1.7.1.min.js'
        script src: 'libs/bootstrap/js/bootstrap.js'
        script src: 'd3.v2.js'

      body ->
        div class: 'container', -> @body

 