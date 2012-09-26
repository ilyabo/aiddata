@include = ->

  request = require 'request'
  caching = require './caching-loader'
  csv = require 'csv'
  queue = require 'queue-async'
  _ = require 'underscore'
  utils = require './data-utils'


  getWbIndicators = caching.loader { preload : true }, (callback) ->
    request "http://api.worldbank.org/indicator?format=json&per_page=10000", (err, response, body) =>
      if err?
        callback err
      else
        paged = JSON.parse body
        unpaged = unpage paged
        console.log "Preloaded #{unpaged.length} World Bank indicators"
        # nested = d3.nest()
        #   .key((d) -> d.id)
        #   .rollup((arr) -> if arr.length is 1 then arr[0] else arr)
        #   .map(unpaged)
        callback(null, unpaged)


  @get '/wb/full/indicators.json': ->
    getWbIndicators (err, indicators) =>
      unless err?
        @send indicators
      else
        @next(err)


  @get '/wb/brief/indicators.csv': ->
    getWbIndicators (err, indicators) =>
      unless err?
        @response.write "id,name,source\n"
        re = /^([A-Z0-9]+)(\.[A-Z0-9]+)+$/

        indicators = indicators.filter (d) -> re.test(d.id)

        csv()
          .from(indicators)
          .toStream(@response)
          .transform (d) -> [ d.id.trim(), d.name.trim(), d.source?.value?.trim() ]
      else
        @next(err)


  unpage = (pagedData) ->
    entries = []
    for page in pagedData when page instanceof Array
      for entry in page
        entries.push entry
    entries


  requestWorldBankIndicator = (indicator, countryCode, callback) ->
    url = "http://api.worldbank.org/countries/#{countryCode}/indicators/#{indicator}?format=json&per_page=32000"
    console.debug "Loading #{url}"
    request url, (err, response, body) ->
      # console.log err
      if err?
        callback err
      # TODO: if there is no data for a country just return an empty list and no error
      # Ignoring the response
      try        
        if body.indexOf("The provided parameter value is not valid") >= 0
          console.warn "WB API reported invalid param value for country '#{countryCode}'. Returning empty data."
          data = []
        else
          data = unpage(JSON.parse(body))

        callback(null, data)

      catch err
        console.error "Could not parse WB API response: " + body?.substr(0, 1024)
        callback "WB API response parse error: " + err





  @get '/wb/brief/:indicator/:countryCode.csv': ->
    q = queue()

    for countryCode in @params.countryCode.split(",")
      q.defer(requestWorldBankIndicator, @params.indicator, countryCode)

    q.await (err, results) =>
      unless err?
        try
          entries = (result.filter((d) -> d.value?) for result in results)
          #  asking for one country       asking for all countries
          if (entries.length is 1)  and  (@params.countryCode isnt "ALL")
            data = entries[0]
          else
            sumByDate = {}
            for list in entries
              for d in list when d.value?
                sumByDate[d.date] = (sumByDate[d.date] ? 0) + (+d.value)

            data = ({date : date, value : sum} for date, sum of sumByDate)


          @response.write "date,value\n"
          csv()
            .from(data)
            .toStream(@response)
            .transform (d) -> [ d.date, d.value ]
          # @send JSON.stringify(entries)
        catch err
          #msg = "Response from the World Bank API could not be processed: " + body
          console.error "Response from the World Bank API could not be processed"
          #@send ""
          @next(err)
      else
        @next(err)


  @get '/wb/full/:indicator/:countryCode.json': ->
    requestWorldBankIndicator @params.indicator, @params.countryCode,
      (err, response, body) =>
        unless err?
          try 
            parsed = JSON.parse body
            @send parsed
          catch err
            @next("Couldn't parse response: " + body?.substr(0, 1024))
        else
          @next(err)

