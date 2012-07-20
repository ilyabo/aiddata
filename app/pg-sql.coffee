@include = ->

  pg = require 'pg'
  fs = require 'fs'

  pgurl = require('../.dbconf').postgres
  ###
  try
    pgurl = fs.readFileSync(".pgurl", "ascii")
  catch err
    console.error("Could not read the postgres URL from the file '.pgurl'")
    console.log(err)
  ###

  sql : (q, callback) ->
    pg.connect pgurl, (err, client) ->
      if client?
        client.query q, callback
      else
        console.log "No valid sql client"
        callback
          message: "No valid sql client"
