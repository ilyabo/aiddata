console.log ">>>>>>>>>> Importing AidData >>>>>>>>>>"

fs = require 'fs'
os = require '../../os-utils'
dbconf = require '../../.dbconf'
mongo = require '../../app/mongo'

pg = require 'pg'
pgurl = dbconf.postgres

DEBUG_updateRowsLimit = null   # set for debugging

mongodb = pgclient = null
aiddataColl = null


queue = require('queue-async')


os.runTasksSerially [

  (callWhenEnded) ->
    console.log "> Connecting to mongodb"
    mongo.open (err, db) ->
      if err? then callWhenEnded(err)
      else
        mongodb = db
        db.collection 'aiddata', (err, coll) =>
          if err? then callWhenEnded(err)
          else
            aiddataColl = coll
            callWhenEnded()

  (callWhenEnded) ->
    console.log "> Connecting to PostgreSQL"
  
    pgclient = new pg.Client(pgurl)
    # disconnect client when all queries are finished        
    #pgclient.on('drain', pgclient.end.bind(pgclient))
    pgclient.connect()
    callWhenEnded()

  (callWhenEnded) ->
    console.log "> Ensure aiddata index"
  
    aiddataColl.ensureIndex { aiddata_id : 1 }, (err) -> 
      if err? then callWhenEnded(err)
      else 
        console.log "Index for aiddata_id ensured"
        callWhenEnded()

  (callWhenEnded) ->
    console.log "> Import AidData commitments from PostgreSQL"

    upsertCount = 0
    upsertQueue = queue(1)
    upsert = (row, callWhenEnded) ->
      aiddataColl.update(
        { aiddata_id:row.aiddata_id }, row, { safe:true, upsert:true }, 
        (err, docs) ->
          if err?
            console.warn "Problem upserting aiddata_id: #{row.aiddata_id}: #{err}"
          else
            upsertCount++
            #console.log "Upserted aiddata_id: #{row.aiddata_id}"
            if upsertCount % 1000 == 0
              console.log "Upsert count: #{upsertCount}"
          callWhenEnded(err)
        , true
      )


    query = pgclient.query "SELECT * FROM aiddata2 #{if DEBUG_updateRowsLimit? then 'LIMIT '+DEBUG_updateRowsLimit}"
    query.on 'row', (row) -> upsertQueue.defer upsert, row
    query.on 'end', -> upsertQueue.await (err, results) -> 
      console.log "Upserted #{upsertCount} documents"
      callWhenEnded err, results



], (err, results) ->

    if err?
      console.warn "> There was an error: " + err
    else
      console.log("> All tasks finished")
    
    mongodb.close()
    pgclient.end()

