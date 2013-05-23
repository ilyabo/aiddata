# 
# Simple caching loader. 
# 
# Will call the passed in loader() function and cache the result as soon
# as it is ready. 
#
# If several callers ask for the same thing, it will not initiate loading
# more than once.
# 
# Options: preload (true or false)
#
# Example use:
#
#     getBirds = caching.loader { preload: true }, (callback) ->
#       fetchBirds (err, data) -> callback(err, data)
#     
#
#     getBirds (err, birds) ->
#       console.log "Here they are: " + birds
#     
#
@loader = (options, loader) ->

  cached = null
  waiting = []

  get = (callback) ->
    if cached? then callback(null, cached)
    else
      waiting.push callback

      if waiting.length is 1       # don't load twice: if loading was already
                                   # initiated, just wait until it loads
        loader (err, data) ->
          if err? then console.log err
          else
            cached = data

          # notify all waiters
          cb(err, data) for cb in waiting

  if options.preload then get(-> )

  get

