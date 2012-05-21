@include = ->

  

  @view horizon: ->
    @page = "horizon"
    
    div id:'horizonChart'

    style '@import url("css/cubism.css");'
    script src: 'cubism.v1.js'
    #script src: 'js/cubism-aiddata.js'
    script src: 'coffee/horizon-aiddata.js'





  @view ffprints: ->
    @page = "ffprints"
    @dataset = "aiddata"

    style '@import url("css/ffprints.css");'
    div id:"radioset", style:"display:inline-block", ->
      
      span style:"margin-right:10px","Positioning:"

      input name:"nodePositioningMode", id:"useGeoNodePositions", type:"radio", checked:"checked"
      label "for":"useGeoNodePositions", -> "Geo"

      input name:"nodePositioningMode", id:"useForce", type:"radio"
      label "for":"useForce", -> "Pack"

      input name:"nodePositioningMode", id:"useGrid", type:"radio", disabled:"disabled"
      label "for":"useGrid", style:"margin-left:5px", -> "Grid"

      input name:"nodePositioningMode", id:"useAligned", type:"radio", disabled:"disabled"
      label "for":"useAligned", style:"margin-left:5px", -> "Align"

    #div id:'slider', style:'width:300px;display:inline-block; margin-left:20px; margin-top:7px;'
    div id: 'loading', style:'margin-top:20px', -> "Loading view..."
    div id: 'ffprints', style:'margin-top:20px'

    script src: 'js/fit-projection.js'
    script src: 'coffee/ffprints.js'
    script src: 'coffee/utils.js'

    script src: "coffee/ffprints-#{@dataset}.js"
    




  @view bubbles: ->
    @page = "bubbles"
    @dataset = "aiddata"

    style '@import url("css/bubbles.css");'

    div id:"bubblesChart"

    div id: "yearSliderOuter", ->

      div id:"play", class:"ui-state-default ui-corner-all", ->
          span class:"ui-icon ui-icon-play"

      div id:'yearSliderInner', ->
        div id:'yearSlider'
        #a id:"play", -> "Play"
        div id:'yearTicks'
        #div class:"icons ui-widget ui-helper-clearfix", ->
        #  div class:"ui-state-default ui-corner-all", title:".ui-icon-play",->
        #    span id:"playButton", class: "ui-icon ui-icon-play"


    div id:"tseriesPanel"

    script src: 'js/fit-projection.js'
    script src: 'coffee/utils.js'
    script src: "coffee/bubbles-#{@dataset}.js"





  @view crossfilter: ->
    @page = "crossfilter"
    @dataset = "aiddata"
    #script src: 'coffee/utils.js'


    div id: "charts", ->
      div id: "hour-chart", class: "chart", ->
        div class: "title", -> "Time of Day"
      
      div id: "delay-chart", class: "chart", ->
        div class: "title", -> "Arrival Delay (min.)"
      
      div id: "distance-chart", class: "chart", ->
        div class: "title", -> "Distance (mi.)"
      
      div id: "date-chart", class: "chart", ->
        div class: "title", -> "Date"
    
      aside id:"totals", ->
        span id:"active", -> "-"
        " of "
        span id:"total", -> "-"
        " flights selected."

      div id:"lists", ->
        div id:"flight-list", class:"list"


    script src: 'crossfilter.js'
    script src: 'js/crossfilter-ex.js'
    script src: 'js/crossfilter-barchart.js'




  @view flowmap: ->
  

  @view "time-series": ->
  @view chord: ->
