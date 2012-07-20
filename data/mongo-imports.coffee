@run = ->

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
          callback(mongodb, coll)

  runImportTasks = ->
    for taskName, importFunc of importTasks
      console.log ">>>>>>>>>> Importing '#{taskName}' >>>>>>>>>>"
      importFunc()




  importTasks =

    aiddata : ->    

      omitNullValueFields = true

      connectToMongo 'aiddata', 'aiddata', (mongodb, coll) ->

        pgclient = new pg.Client(pgurl)
        # disconnect client when all queries are finished        
        #pgclient.on('drain', pgclient.end.bind(pgclient))
        pgclient.connect()


        q = "SELECT * FROM aiddata2"

        query = pgclient.query q.replace("*", "COUNT(*) AS count")
        query.on 'row', (row) ->

          console.log row

          toprocess = row.count
          processed = 0
          scheduledForInsertion = 0

          closeIfFinished = ->
            console.log "Processed "+processed+" of " +toprocess
            if scheduledForInsertion == 0  and  processed == toprocess
              console.log "Closing connections"
              pgclient.end()    
              mongodb.close()      


          query = pgclient.query q
          query.on 'row', (row) ->

            

            if omitNullValueFields
              for k,v of row
                unless v?
                  delete row[k]

            #coll.insert row, (err, docs) ->
            #  console.log "Inserted aiddata_id: " + row.aiddata_id

            #console.log "Scedule insert "+ row.aiddata_id
            ###
            coll.findOne { aiddata_id: row.aiddata_id }, (err, item) -> 
              console.log "Inserting aiddata_id: " + row.aiddata_id
            ###
            coll.find({ aiddata_id: row.aiddata_id }).toArray (err, found) -> 
              console.log "Found for aiddata_id: " + row.aiddata_id + " num: " + found.length
              if found.length == 0
                scheduledForInsertion++
                coll.insert row, (err, docs) ->
                  console.log "Inserted aiddata_id: " + row.aiddata_id
                  scheduledForInsertion--
                  closeIfFinished()
              processed++
              closeIfFinished()









  runImportTasks()

