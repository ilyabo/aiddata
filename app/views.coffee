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


#    div id:"bottomButtons", ->
#      button id:"exportCsvBut", class:"btn btn-mini", title:"Export data for the current commitments selection as CSV", -> "Export CSV"
#      button id:"showCommitmentsBut", class:"btn btn-mini", title:"Show detailed info for the top commitments of the selection",
#         -> "Show top details"

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






