@include = ->

  @coffee '/coffee/query-history.js' : -> 
    #
    # queries are expected to support two methods: copy() and load()
    #
    @queryHistory = ->

      current = null
      history = []
      forwardHistory = []

      load = (q, callback, updateHistory, clearForwardHistory) ->

        q.load (err, data) ->
          if err?
            callback err
          else
            if clearForwardHistory
              forwardHistory = []

            if updateHistory
              if current?
                history.push(current)

            current = q.copy()

            if callback? then callback(null, data)

      top = -> 
        if history.length > 0
          history[history.length - 1]
        else
          null


      {
        top : top

        current : -> current?.copy()

        back : (callback) ->
          if history.length > 0
            top = history.pop()
            forwardHistory.push(current)
            load(top.copy(), callback, false, false)

        forward : (callback) ->
          if forwardHistory.length > 0
            top = forwardHistory.pop()
            load(top.copy(), callback, true, false)

        isBackEmpty : -> history.length is 0

        isForwardEmpty : -> forwardHistory.length is 0

        load : (q, callback) -> load(q, callback, true, true)
      }


