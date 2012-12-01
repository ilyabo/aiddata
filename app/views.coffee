@include = ->


  ############# break and split ###############

  @view breaknsplit : ->

    @title = "AidData Break'n'split"
    @page = "breaknsplit"

    
    style '@import url("css/charts/time-series.css");'
    style '@import url("css/breaknsplit.css");'
    script src: 'coffee/charts/time-series.js'
    script src: 'coffee/utils-aiddata.js'
    script src: 'coffee/utils.js'
    script src: 'coffee/query-history.js'
    script src: 'queue.min.js'
    script src: 'libs/history.js/html5/jquery.history.js'
    # script src: 'libs/chroma/chroma.min.js'
    # script src: 'libs/chroma/chroma.colors.js'
    script src: 'coffee/breaknsplit.js'

    div id:"content", ->

      #div class:"row-fluid", ->

      div id:"outerTop", -> 
        table ->
          tr ->
            td -> table ->

              # td class:"backForwardBtns", ->
              #   div class:"btn-toolbar", ->
              #     div class:"btn-group", ->
              #       button id:"backButton",class:"btn btn-mini", disabled:"disabled", ->
              #         i class:"icon-chevron-left"
              #       button id:"forwardButton",class:"btn btn-mini", disabled:"disabled", ->
              #         i class:"icon-chevron-right"

              # td style:"width:30px" #, ->
              #   #div id:"loading", -> img src:"images/loading.gif"
              td class:"messageArea",->
                div id:"error", class:"alert-error alert", ->
                  button type:"button", class:"close", 'data-dismiss':"alert", -> "&times;"
                  span id:"errorText"

                div id:"warn", class:"alert", ->
                  button type:"button", class:"close", 'data-dismiss':"alert", -> "&times;"
                  span id:"warningText"

            td rowspan:"2",  -> 
              table -> td -> div id:"status", class:"alert alert-info"
              div id:"tseries", class:"tseries"
              table class:"sm-ctls",->
                td class:"split", -> button id:"split",class:"split btn btn-mini", "data-toggle":"button", -> "Split in multiple"

          tr -> td ->
            table ->
              tr ->
                td -> div class:"hdr", -> "Donors"
                td -> div class:"hdr", -> "Recipients"
                td -> div class:"hdr", -> "Purposes"

              tr ->
                td -> select id:"donorList", class:"filter", 'data-prop':"donor", size:"10", multiple:"multiple"
                td -> select id:"recipientList", class:"filter",'data-prop':"recipient",  size:"10", multiple:"multiple"
                td -> select id:"purposeList", class:"filter", 'data-prop':"purpose", size:"10", multiple:"multiple"

              tr class:"ctls",->
                td ->
                    div class:"btn-group filter",'data-prop':"donor",->
                      button class:"filter btn btn-mini", 'data-prop':"donor", -> "Filter"
                      button class:"resetFilter btn btn-mini", 'data-prop':"donor", -> "&times;"
                    div class:"btn-group breakDown",'data-prop':"donor",->
                      button class:"breakDown btn btn-mini",'data-prop':"donor", -> "Break&nbsp;down"
                      button class:"resetBreakDown btn btn-mini", 'data-prop':"donor", -> "&times;"
                td ->
                    div class:"btn-group filter",'data-prop':"recipient",->
                      button class:"filter btn btn-mini",'data-prop':"recipient", -> "Filter"
                      button class:"resetFilter btn btn-mini", 'data-prop':"recipient", -> "&times;"
                    div class:"btn-group breakDown",'data-prop':"recipient",->
                      button class:"breakDown btn btn-mini",'data-prop':"recipient", -> "Break&nbsp;down"
                      button class:"resetBreakDown btn btn-mini", 'data-prop':"recipient", -> "&times;"
                td ->
                    div class:"btn-group filter",'data-prop':"purpose",->
                      button class:"filter btn btn-mini", 'data-prop':"purpose", -> "Filter"
                      button class:"resetFilter btn btn-mini", 'data-prop':"purpose", -> "&times;"
                    div class:"btn-group breakDown",'data-prop':"purpose",->
                      button class:"breakDown btn btn-mini",'data-prop':"purpose", -> "Break&nbsp;down"
                      button class:"resetBreakDown btn btn-mini", 'data-prop':"purpose", -> "&times;"


        div id:"indicatorOuter", class:"ctls", ->
          table ->
            tr ->
              td class:"indicatorLabel",-> span class:"label btn-mini", "Compare with an indicator for:"
              td -> select id:"indicatorFor",class:"ctl",->
                option -> "donor"
                option -> "recipient"
              td -> input id:"indicatorTypeahead", class:"ctl btn-mini",type:"text", "data-provide":"typeahead"
            tr ->
              td colspan:"2"
              td class:"ctl-hint", -> "Start typing to find an indicator"

        div id:"splitPanel", class:"tseries"


    div id:"loading", -> 
      div class:"blockUI"
      img src:"images/loading.gif"





  
  ############# bubbles ###############

  @view bubbles: ->
    @page = "bubbles"
    @dataset = "aiddata"

    style '@import url("css/charts/bar-hierarchy.css");'
    style '@import url("css/charts/time-series.css");'
    style '@import url("css/charts/time-slider.css");'

    style '@import url("css/charts/bubbles.css");'
    style '@import url("css/bubbles.css");'




    div id:"blockUI"
    div id:"loading", -> 
      img src:"images/loading.gif"

    div id:"error", class:"alert-error alert", ->

    div id:"leftSidebar", ->
      div id:"timeSlider"
      div id:"tseriesPanel"

    div id:"purposeBars"

    div id:"bubblesChart"


    button id:"showCommitmentsBut", type:"button", class:"btn btn-mini", -> "Show table"

    div id:"commitmentListModal", class:"modal hide fade", ->
      div class:"modal-header", ->
        button type:"button", class:"close", 'data-dismiss':"modal", 'aria-hidden':"true", -> "&times;"
        #h3 -> "Commitment details"
      div class:"modal-body", ->
        
        table class:"table table-striped table-hover commitments", ->
          thead ->
            tr -> 
              th width:"30%",-> "Donor"
              th width:"30%",-> "Recipient"
              th width:"30%",-> "Purpose"
              th width:"10%",-> "Amount"
            tr ->
              td colspan:"4", class:"pages", ->
                div class:"pageCount"
                div class:"pagination-mini pagination", -> ul
          tbody -> ""


        div class:"loading", -> img src:"images/loading.gif"


      div class:"modal-footer", ->
        a href:"#", id:"commitmentListModalClose", class:"btn", -> "Close"


    ###
    div id: "yearSliderOuter", ->

      div id:"play", class:"ui-state-default ui-corner-all", ->
          span class:"ui-icon ui-icon-play"

      div id:'yearSliderInner', ->
        div id:'yearSlider'
        div id:'yearTicks'
    ###




    style '@import url("libs/tipsy-new/stylesheets/tipsy.css");'
    script src: "libs/tipsy-new/javascripts/jquery.tipsy.js"

    script src: 'js/fit-projection.js'
    script src: 'coffee/utils.js'
    script src: 'queue.js'
    script src: 'coffee/utils-aiddata.js'
    #script src: "coffee/time-slider.js"
    script src: "coffee/charts/bubbles.js"
    script src: "coffee/charts/bar-hierarchy.js"
    script src: "coffee/charts/time-series.js"
    script src: "coffee/charts/time-slider.js"
    script src: "coffee/bubbles.js"








  ############# horizon ###############


  @view horizon: ->
    @page = "horizon"

  

    div id:'horizonParent', ->
      div id:'originsChart',class:'horizonChart'
      div id:'destsChart',class:'horizonChart'

    style '@import url("css/horizon.css");'
    script src: 'queue.min.js'
    script src: 'js/cubism.v1.my.js'
    script src: 'coffee/utils.js'
    #script src: 'js/cubism-aiddata.js'
    script src: 'libs/chroma/chroma.min.js'
    script src: 'libs/chroma/chroma.colors.js'
    script src: 'coffee/horizon-aiddata.js'






  ############# horizon3 ###############


  @view horizon3: ->
    @page = "horizon3"

  
    div id:"loading", -> 
      div class:"blockUI"
      img src:"images/loading.gif"

    div id:'horizonParent', ->
      div id:'donorsChart', class:'horizonChart'
      div id:'recipientsChart', class:'horizonChart'
      div id:'purposesChart', class:'horizonChart'

    div id:"indicatorModal", class:"modal hide fade", ->
      div class:"modal-header", ->
        button type:"button", class:"close", 'data-dismiss':"modal", 'aria-hidden':"true", -> "&times;"
        h3 -> "Indicators"
      div class:"modal-body", ->
        div class:"input-append", ->
          input id:"indicatorTypeahead", class:"", type:"text", "data-provide":"typeahead"
          button id:"indicatorClear", class:"btn", type:"button", -> "&times;"

        div class:'ctl-hint',-> "Start typing to find an indicator"
        div id:'indicatorChart', class:'horizonChart'
        div id:'indicatorDesc', ->
          div class:'name'
          div class:'topics'
          div class:'sourceNote'
          div class:'source'

      div class:"modal-footer", ->
        a href:"#", id:"indicatorModalClose", class:"btn", -> "Cancel"
        a href:"#", id:"indicatorModalLoad", class:"btn btn-primary", -> "Load"

    style '@import url("css/horizon3.css");'
    script src: 'queue.min.js'
    # script src: 'js/cubism.v1.my.js'
    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    # #script src: 'js/cubism-aiddata.js'
    # script src: 'libs/chroma/chroma.min.js'
    # script src: 'libs/chroma/chroma.colors.js'
    #script src: 'js/horizon.js'
    script src: 'coffee/horizon3.js'









  @view horizon4: ->
    @page = "horizon4"
  
    div id:"loading", -> 
      div class:"blockUI"
      img src:"images/loading.gif"

    div id:'horizonParent', ->
      div id:'donorsChart', class:'horizonChart'
      div id:'recipientsChart', class:'horizonChart'
      # div id:'purposesChart', class:'horizonChart'

    # div id:"indicatorModal", class:"modal hide fade", ->
    #   div class:"modal-header", ->
    #     button type:"button", class:"close", 'data-dismiss':"modal", 'aria-hidden':"true", -> "&times;"
    #     h3 -> "Indicators"
    #   div class:"modal-body", ->
    #     div class:"input-append", ->
    #       input id:"indicatorTypeahead", class:"", type:"text", "data-provide":"typeahead"
    #       button id:"indicatorClear", class:"btn", type:"button", -> "&times;"

    #     div class:'ctl-hint',-> "Start typing to find an indicator"
    #     div id:'indicatorChart', class:'horizonChart'
    #     div id:'indicatorDesc', ->
    #       div class:'name'
    #       div class:'topics'
    #       div class:'sourceNote'
    #       div class:'source'

    #   div class:"modal-footer", ->
    #     a href:"#", id:"indicatorModalClose", class:"btn", -> "Cancel"
    #     a href:"#", id:"indicatorModalLoad", class:"btn btn-primary", -> "Load"

    style '@import url("css/horizon4.css");'
    script src: 'queue.min.js'
    # script src: 'js/cubism.v1.my.js'
    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    # #script src: 'js/cubism-aiddata.js'
    # script src: 'libs/chroma/chroma.min.js'
    # script src: 'libs/chroma/chroma.colors.js'
    #script src: 'js/horizon.js'
    script src: 'coffee/horizon4.js'




  ############# ffprints ###############

  @view ffprints: ->
    @page = "ffprints"
    @dataset = "aiddata"

    style '@import url("css/ffprints.css");'
    div id:"radioset", style:"display:inline-block", ->
      table ->
        td -> span style:"margin-right:10px","Positioning:"

        td -> input name:"nodePositioningMode", id:"useGeoNodePositions", type:"radio", checked:"checked"
        td -> label "for":"useGeoNodePositions", -> "Geo"

        td -> input name:"nodePositioningMode", id:"useForce", type:"radio"
        td -> label "for":"useForce", -> "Pack"

      # input name:"nodePositioningMode", id:"useGrid", type:"radio", disabled:"disabled"
      # label "for":"useGrid", style:"margin-left:5px", -> "Grid"

      # input name:"nodePositioningMode", id:"useAligned", type:"radio", disabled:"disabled"
      # label "for":"useAligned", style:"margin-left:5px", -> "Align"

    #div id:'slider', style:'width:300px;display:inline-block; margin-left:20px; margin-top:7px;'
    div id: 'loading', style:'margin-top:20px', -> "Loading view..."
    div id: 'ffprints', style:'margin-top:20px'

    style '@import url("libs/tipsy-new/stylesheets/tipsy.css");'
    script src: "libs/tipsy-new/javascripts/jquery.tipsy.js"

    script src: 'libs/chroma/chroma.min.js'
    script src: 'libs/chroma/chroma.colors.js'
    script src: 'js/fit-projection.js'
    script src: 'coffee/ffprints.js'
    script src: 'coffee/utils.js'

    script src: "coffee/ffprints-#{@dataset}.js"
    






  ############# crossfilter ###############

  @view crossfilter: ->
    @page = "crossfilter"
    @dataset = "aiddata"
    #script src: 'coffee/utils.js'

    style '@import url("css/crossfilter.css");'


    div id: "charts", ->

      
      div id: "year-chart", class: "chart", ->
        div class: "title", -> "Num of commitments by Year"

      div id: "amount-chart", class: "chart", ->
        div class: "title", -> "Commitment amounts"
    
      aside id:"totals", ->
        span id:"active", -> "-"
        span " of "
        span id:"total", -> "-"
        " commitments selected."

      div id:"lists", ->
        div id:"flow-list", class:"list"


    script src: 'crossfilter.js'
    script src: 'underscore.js'
    script src: 'coffee/utils-aiddata.js'
    script src: 'coffee/crossfilter-barchart.js'
    script src: 'coffee/crossfilter-aiddata.js'




  ############# purposeTree ###############

  @view purposeTree: ->
    @page = "purposeTree"

    style '@import url("css/purpose-tree.css");'
    div id:"purposeTree"

    script src: 'libs/chroma/chroma.min.js'
    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    
    script src: "coffee/purpose-tree.js"




  ############# purposePack ###############

  @view purposePack: ->
    @page = "purpose-pack"

    style '@import url("css/purpose-pack.css");'
    div id:"purposePack"

    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    
    script src: "coffee/purpose-pack.js"





  ############# purposeBars ###############

  @view purposeBars: ->
    @page = "purposeBars"

    style '@import url("css/charts/bar-hierarchy.css");'

    div id:"purposeBars"

    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    
    script src: "coffee/charts/bar-hierarchy.js"
    script src: "purpose-bars.js"


  @coffee '/purpose-bars.js': ->
    $ ->
      percentageFormat = d3.format(",.2%")

      chart = barHierarchyChart()
        .width(550)
        .height(300)
        .childrenAttr("values")
        .valueAttr("amount")
        .nameAttr("key")
        .valueFormat(formatMagnitude)
        .breadcrumbText(
          (currentNode) ->
            data = currentNode; (data = data.parent) while data.parent?
            formatMagnitude(currentNode.amount) + " (" + 
            percentageFormat(currentNode.amount / data.amount) + " of total)"
        )


      d3.csv "aiddata-purposes-with-totals.csv/2007", (csv) ->
        d3.select("#purposeBars")
          .datum(utils.aiddata.purposes.fromCsv(csv))
          .call(chart)

    










  ############# US donations vs GDP ###############

  @view "us-donations": ->
    style '@import url("css/charts/time-series.css");'

    div id:"tseries2", class:"tseries", style:"margin-bottom:40px"
    div id:"tseries3", class:"tseries", style:"margin-bottom:40px"
    div id:"tseries1", class:"tseries", style:"margin-bottom:40px"

    script src: "coffee/charts/time-series.js"
    script src: 'coffee/utils.js'
    script src: 'coffee/utils-aiddata.js'
    script src: "coffee/us-donations.js"










  ############# break and split ###############

  @view spatialTreemap : ->

    @page = "spatialTreemap"
    script src: 'queue.min.js'
    script src: 'coffee/utils.js'
    script src: "coffee/spatial-treemap.js"
    script src: "spatialTreemapView.js"

  
  @coffee '/spatialTreemapView.js': ->

    map1 = spatialTreemap()
      .width(1000)
      .height(600)


    queue()
      .defer(loadCsv, "data/aiddata-countries.csv")
      .await (err, loaded) ->
        [ countries ] = loaded

        d3.select("body").append("div")
          .datum(countries)
          .call(map1)
        
    

