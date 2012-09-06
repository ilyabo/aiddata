@include = ->

  request = require 'request'



  @get '/wb-indicators.json': ->
    request "http://api.worldbank.org/indicator?format=json&per_page=10000", (err, response, body) =>
      unless err?
        @send JSON.parse body
      else
          @next(err)



  @get '/wb.json/:indicator/:countryCode': ->
    url =
      "http://api.worldbank.org/countries/" +
      "#{@params.countryCode}/indicators/" + 
      "#{@params.indicator}?format=json"

    console.debug "Loading #{url}"
    request url, 
    (err, response, body) =>
      unless err?
        pages = JSON.parse body
        entries = {}
        for page in pages
          for entry in page
            entries[entry.date] =
              value : entry.value
              date : entry.date             

        @send entries 
      else
          @next(err)

