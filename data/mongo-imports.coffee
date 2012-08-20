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
          unless err?
            callback(mongodb, coll)
          else
            console.log err

  runImportTasks = (importTasks) ->
    for taskName, importFunc of importTasks
      console.log ">>>>>>>>>> Importing '#{taskName}' >>>>>>>>>>"
      importFunc()


  runImportTasks

    aiddata : ->    

      omitNullValueFields = true

      connectToMongo 'aiddata', 'aiddata', (mongodb, coll) ->

        pgclient = new pg.Client(pgurl)
        # disconnect client when all queries are finished        
        #pgclient.on('drain', pgclient.end.bind(pgclient))
        pgclient.connect()



        cntQuery = pgclient.query "SELECT COUNT(*) AS count FROM aiddata2"
        cntQuery.on 'row', (row) ->

          totalRecordsNum = row.count

          numUpserted = 0
 

          query = pgclient.query "SELECT * FROM aiddata2"
          query.on 'row', (row) ->

            row._id = row.aiddata_id
            delete row.aiddata_id

            if omitNullValueFields
              for k,v of row
                unless v?
                  delete row[k]

            coll.update({ _id:row._id }, row, { safe:true, upsert:true }, (err, docs) ->
              numUpserted++
              console.log "Upserted #{numUpserted} of #{totalRecordsNum}, last _id: #{row._id}"
              if numUpserted >= totalRecordsNum
                #pgclient.end()
                mongodb.close()
            , true)  # means upsert

          query.on 'end', -> pgclient.end()
          #mongodb.close()



