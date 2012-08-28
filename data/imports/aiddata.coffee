console.log ">>>>>>>>>> Importing AidData >>>>>>>>>>"

fs = require 'fs'
os = require '../../os-utils'
dbconf = require '../../.dbconf'
mongo = require '../../app/mongo'
linereader = require './linereader'

pg = require 'pg'
pgurl = dbconf.postgres

DEBUG_updateRowsLimit =  null   # set for debugging
TEMP_DIR = "data/imports/temp"
OMIT_NULL_VALUE_FIELDS_IN_COMMITMENTS_JSON = false
AIDDATA_TEMP_FILE = TEMP_DIR + "/_aiddata.json" 

mongodb = pgclient = null
aiddataColl = null


queue = require('queue-async')

runTasksSerially = (tasks, callWhenEnded) ->
  q = queue(1)  # no parallelism
  tasks.forEach (t) -> q.defer t
  q.await callWhenEnded


runTasksSerially [

  (callWhenEnded) ->
    console.log "> Connecting to MongoDB"
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
    console.log "> Ensure aiddata_id index"
  
    aiddataColl.ensureIndex { aiddata_id : 1 }, (err) -> 
      if err? then callWhenEnded(err)
      else 
        console.log "Index for aiddata_id ensured"
        callWhenEnded()



  (callWhenEnded) ->
    console.log "> Export AidData commitments from PostgreSQL to a temporary file"

    os.mkdir TEMP_DIR
    fd = fs.openSync(AIDDATA_TEMP_FILE, 'w')

    query = pgclient.query "SELECT * FROM aiddata2 #{if DEBUG_updateRowsLimit? then 'LIMIT '+DEBUG_updateRowsLimit}"
    query.on 'row', (row) ->

      if OMIT_NULL_VALUE_FIELDS_IN_COMMITMENTS_JSON
        for k,v of row
          unless v?
            delete row[k]

      # assuming that stringify produces a one-liner
      fs.writeSync fd, JSON.stringify(row) + "\n"

    query.on 'end', ->  
      fs.closeSync fd
      callWhenEnded()


  (callWhenEnded) ->
    console.log "> Upserting AidData commitments in MongoDB"

    reader = linereader.open AIDDATA_TEMP_FILE

    nextRow = ->
      if reader.hasNextLine()
        JSON.parse reader.nextLine()
      else
        null


    # update synchronously
    upsert = do -> 
      upsertCount = 0
      (row) ->
        unless row?
          callWhenEnded()
          console.log "Upserted #{upsertCount} documents"
        else
          aiddataColl.update(
            { aiddata_id:row.aiddata_id }, row, { safe:true, upsert:true }, 
            (err, docs) ->
              if err?
                console.log "Upserted #{upsertCount} documents"
                console.warn "Problem upserting aiddata_id: #{row.aiddata_id}: #{err}"
                callWhenEnded(err)
              else
                upsertCount++
                upsert nextRow()   # proceed to next row              
            , true
          )


    upsert nextRow()


], (err, results) ->

    if err?
      console.warn "> There was an error: " + err
    else
      console.log("> All tasks finished")
    
    mongodb.close()
    pgclient.end()

