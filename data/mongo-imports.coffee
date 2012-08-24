@run = ->
  
  console.log ">>>>>>>>>> Importing aiddata >>>>>>>>>>"

  fs = require 'fs'
  util = (require '../cakeutils').include()

  mongo = require 'mongodb'
  mongoConf = require('../.dbconf').mongodb

  pg = require 'pg'
  pgurl = require('../.dbconf').postgres

  connectToMongo = (dbName, collName, callback) ->
    ifnot = (err, callback) -> if not err then callback() else console.error err
    mongosrv = new mongo.Server(mongoConf.host, mongoConf.port)
    mongodb = new mongo.Db(dbName, mongosrv)
    mongodb.open (err, p_client) -> ifnot err, -> 
      mongodb.authenticate mongoConf.user, mongoConf.password, (err) -> ifnot err, -> 
        mongodb.collection collName, (err, coll) ->
          unless err?
            callback(mongodb, coll)
          else
            console.log err


  limit = undefined

  connectToMongo 'aiddata', 'aiddata', (mongodb, coll) ->
    coll.ensureIndex { aiddata_id : 1 }, -> 
      console.log "Index for aiddata_id ensured"

      mongodb.close()

      tempDir = "data/temp"
      tempFile = tempDir + "/_aiddata.json" 
      util.mkdir tempDir

      omitNullValueFields = true

      pgclient = new pg.Client(pgurl)
      # disconnect client when all queries are finished        
      #pgclient.on('drain', pgclient.end.bind(pgclient))
      pgclient.connect()


      cntQuery = pgclient.query(
        if limit? 
          "SELECT #{limit} AS count"
        else
          "SELECT COUNT(*) AS count FROM aiddata2"
      )

      cntQuery.on 'row', (row) ->
        
        totalRecordsNum = row.count
        console.log "Reading #{totalRecordsNum} records from postgres..."

        numProcessed = 0


        #jsonFile = fs.createWriteStream(tempFile)
        fd = fs.openSync(tempFile, 'w')

        firstRow = true
        query = pgclient.query "SELECT * FROM aiddata2 #{if limit? then 'LIMIT '+limit}"
        query.on 'row', (row) ->

          #row._id = row.aiddata_id
          #delete row.aiddata_id

          if omitNullValueFields
            for k,v of row
              unless v?
                delete row[k]

          #console.log "Upserted #{numUpserted} of #{totalRecordsNum}, last _id: #{row._id}"
          numProcessed++

          # assuming that stringify produces a one-liner
          fs.writeSync fd, JSON.stringify(row) + "\n"

          if numProcessed % 1000 == 0
            console.log "Processed #{numProcessed} of #{totalRecordsNum}"


          if numProcessed >= totalRecordsNum
            console.log "#{numProcessed} records were saved temporarily in #{tempFile}"
            console.log "Now importing into MongoDB"
            util.run "/usr/bin/mongoimport " +
                        "-d aiddata -c aiddata --upsert --upsertFields aiddata_id " +
                        "-u #{mongoConf.user} -p #{mongoConf.password} "+ 
                        "#{tempFile}",
              ->
                fs.closeSync fd
                fs.unlink tempFile 
                console.log "Done"


        query.on 'end', -> pgclient.end()

