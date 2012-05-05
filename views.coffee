@include = ->

  

  @view ffprints: ->
    @page = "aiddata-ffprints"
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
    @page = "aiddata-bubbles"
    @dataset = "aiddata"

    style '@import url("css/bubbles.css");'

    div id: "yearSliderOuter", ->
      div id:'yearLabel', -> "Year: "
      div id:'yearSlider'
      a id:"play", -> "Play"
      #div class:"icons ui-widget ui-helper-clearfix", ->
      #  div class:"ui-state-default ui-corner-all", title:".ui-icon-play",->
      #    span id:"playButton", class: "ui-icon ui-icon-play"

    script src: 'js/fit-projection.js'
    script src: 'coffee/utils.js'
    script src: "coffee/bubbles-#{@dataset}.js"




    



  @view flowmap: ->
  @view crossfilter: ->
  @view "time-series": ->
  @view chord: ->
