@run = ->
  
  {spawn, exec} = require 'child_process'
  fs = require 'fs'

  mongo = require 'mongodb'
  mongoConf = require('../.dbconf').mongodb

  pg = require 'pg'
  pgurl = require('../.dbconf').postgres


  runImportTasks = (importTasks) ->
    for taskName, importFunc of importTasks
      console.log ">>>>>>>>>> Importing '#{taskName}' >>>>>>>>>>"
      importFunc()


  runImportTasks

    aiddata : ->    

      omitNullValueFields = true

      pgclient = new pg.Client(pgurl)
      # disconnect client when all queries are finished        
      #pgclient.on('drain', pgclient.end.bind(pgclient))
      pgclient.connect()

      limit = 10

      cntQuery = pgclient.query(
        if limit? 
          "SELECT #{limit} AS count"
        else
          "SELECT COUNT(*) AS count FROM aiddata2"
      )

      cntQuery.on 'row', (row) ->
        
        totalRecordsNum = row.count
        console.log "totalRecordsNum: " + totalRecordsNum

        numProcessed = 0


        jsonFile = fs.createWriteStream("data/_aiddata.json")
        jsonFile.write "["

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

          if numProcessed < totalRecordsNum
            jsonFile.write JSON.stringify(row) + ","
          else
            jsonFile.write JSON.stringify(row) + "]"
            console.log "Read in: #{numProcessed}"
            importIntoMongoDB()


        query.on 'end', -> pgclient.end()

