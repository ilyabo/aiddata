
#################    CONFIG     #################
USE_MONGOIMPORT = true

DEBUG_updateRowsLimit =  null  # set for debugging

OMIT_NULL_VALUE_FIELDS_IN_COMMITMENTS_JSON = true

IMPORT_COMMITMENT_DATES_AS_ = "epoch"    # Possibilities:  "epoch" "date" "string"
# "date" won't work for negative dates
# as long as https://jira.mongodb.org/browse/SERVER-961 is not fixed




PATH = "data/imports/"
TEMP_DIR = "temp"
AIDDATA_TEMP_FILE = PATH + TEMP_DIR + "/aiddata.json"
LOCATIONS_TEMP_FILE = PATH + TEMP_DIR + "/locations.json"

################# END OF CONFIG #################






console.log ">>>>>>>>>> Importing AidData >>>>>>>>>>"

fs = require 'fs'
os = require '../../os-utils'
dbconf = require '../../.dbconf'
mongo = require '../../app/mongo'
linereader = require './linereader'
d3 = require 'd3'

queue = require 'queue-async'

pg = require 'pg'
pgurl = dbconf.postgres


mongodb = pgclient = null

locationNameToCode = {}




importCollectionToMongo = (collection, file, upsertFields, callWhenEnded) ->

  if USE_MONGOIMPORT   # faster
    cmd = "/usr/bin/mongoimport " +
                "-d aiddata -c #{collection} --upsert --upsertFields #{upsertFields.join(',')} " +
                "-u #{dbconf.mongodb.user} -p #{dbconf.mongodb.password} "+ 
                "#{file}"

    console.log "Running command:\n#{cmd}"
    os.run cmd,
      (err) ->
        callWhenEnded(err)

  else

    
    mongodb.collection collection, (err, coll) =>
      if err? then callWhenEnded(err)
      else

        reader = linereader.open file

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
              criteria = {}
              for f in upsertFields
                criteria[f] = row[f]

              coll.update(
                criteria, row, { safe:true, upsert:true }, 
                (err, docs) ->
                  if err?
                    console.log "Upserted #{upsertCount} documents"
                    console.warn "Problem upserting aiddata_id: #{row.aiddata_id}: #{err}"
                    callWhenEnded(err)
                  else
                    upsertCount++
                    if ((upsertCount % 10000) is 0) then console.log "Upsert count: #{upsertCount}" 
                    upsert nextRow()   # proceed to next row              
                , true
              )
        upsert nextRow()



ensureIndices = (collName, indices, callWhenEnded) ->
  mongodb.collection collName, (err, coll) =>
    if err? then callWhenEnded(err)
    else
      ensure = (index, ended) ->
        console.log "Ensuring #{collName} index #{JSON.stringify(index)}"
        coll.ensureIndex index, (err) ->
          if err? then callWhenEnded(err)
          else 
            ended()


      q = queue(1)  # no parallelism
      indices.forEach (index) -> q.defer ensure, index
      q.await -> callWhenEnded()




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
        callWhenEnded()











  (callWhenEnded) ->
    console.log "> Ensure aiddata commitments indices"
    
    indices = [
      { aiddata_id : 1 }
      { origin : 1 }
      { dest : 1 }
      { origin : 1, dest : 1 }
      { coalesced_purpose_code : 1 }
    ]
    ensureIndices 'aiddata', indices, callWhenEnded



  (callWhenEnded) ->
    console.log "> Ensure locations indices"    
    indices = [
      { code : 1 }
    ]
    ensureIndices 'locations', indices, callWhenEnded





  (callWhenEnded) ->
    console.log "> Connecting to PostgreSQL"
  
    pgclient = new pg.Client(pgurl)
    # disconnect client when all queries are finished        
    #pgclient.on('drain', pgclient.end.bind(pgclient))
    pgclient.connect()
    callWhenEnded()





  (callWhenEnded) ->
    console.log "> Export locations (countries & organizations) to a temp file"

    pgclient.query("
      SELECT donor as name,donorcode as code from aiddata2
        UNION
      SELECT recipient as name,recipientcode as code from aiddata2 
      ORDER BY code, name"
      , (err, result) ->
        if err? then callWhenEnded(err)
        else
          
          codes = {}


          acronym = (name) -> 
            words = name.split(/\W/)
            if words.length > 2
              # use each word's first letter as the code
              words.map((s) -> s[0]).join("")
            else
              name.substr(0, 3).toUpperCase()


          # Ensure each location has a meaningful code
          do -> 
            for r in result.rows
              oldname = r.name

              if /, regional/.test r.name
                r.type = "region"
                match = /(.*), regional/.exec r.name
                r.name = match[1]
                r.code = "R-"+acronym(r.name)
              else if (r.name in ["GLOBAL", "Bilateral, unspecified", "MADCT Unspecified", 
              "Sts Ex-Yugo. Unspec."])
                r.code = "C-"+acronym(r.name) 
                r.type = "congl" 
              else if r.code?
                r.type = "country" 
                unless r.code.trim().length > 0
                  r.code = acronym(r.name)

                # fix the problem with the wrong country code of Italy
                if (r.code in ["IRA", "ITA"] and r.name is "Italy")
                  r.code = "ITA"
                  delete codes["ITA"]

              else
                r.type = "org"
                match = /(.*)\(([A-Z]+)\)(.*)/.exec r.name 
                if match?
                  # if there is an acronym in parethesis in the name, use it as the code
                  r.code = "O-"+match[2]
                  r.name = (match[1] + match[3]).trim()
                else
                  r.code = "O-"+acronym(r.name)

              # if code was already used, add a number at the end
              do -> 
                c = r.code
                i = 1
                while codes[c]?
                  c = r.code + i++
                codes[c] = true
                r.code = c

              locationNameToCode[oldname] = r.code


          # add coordinates and polygons
          do ->
            countries = d3.csv.parse(fs.readFileSync("data/static/data/aiddata-countries.csv", "utf8"))
            countriesByCode = d3.nest().key((c) -> c.Code).rollup((a) -> a[0]).map(countries)

            geometry = JSON.parse(fs.readFileSync("data/static/data/world-countries.json", "utf8"))
            geometryByCode = d3.nest().key((c) -> c.id).rollup((a) -> a[0]).map(geometry.features)

            for r in result.rows when r.type is "country"
              c = countriesByCode[r.code]
              if c?
                r.lat = c.Lat
                r.lon = c.Lon
              g = geometryByCode[r.code]
              if g?
                r.geometry = g.geometry
                delete geometryByCode[r.code]


            console.log "! Countries with no centroid coords:\n" + 
              ("(#{r.name},#{r.code})" for r in result.rows when r.type is "country" and not r.lat?) + "\n"
            console.log "! Countries with no geometry:\n" +
              ("(#{r.name},#{r.code})" for r in result.rows when r.type is "country" and not r.geometry?) + "\n"
            console.log "! Countries found in the map, but not in the list of locations:\n" +
              ("(#{code},#{obj.properties.name})" for code,obj of geometryByCode) + "\n"

          # writing to the temp file for importing into Mongo
          do ->
            os.mkdir TEMP_DIR
            fd = fs.openSync(LOCATIONS_TEMP_FILE, 'w')
            for r in result.rows
              fs.writeSync fd, JSON.stringify(r) + "\n"
            fs.closeSync fd


          callWhenEnded()
    )








  (callWhenEnded) ->
    console.log "> Export aiddata commitments from PostgreSQL to a temporary file"

    os.mkdir TEMP_DIR
    fd = fs.openSync(AIDDATA_TEMP_FILE, 'w')

    dateFieldQ = (field, q) ->
      switch IMPORT_COMMITMENT_DATES_AS_
        when "date", "epoch" then "EXTRACT(EPOCH FROM #{q})*1000 AS #{field}"
        when "string" then "#{q} AS #{field}"

    dateFields = 
      "date" : "COALESCE(commitment_date, start_date, to_timestamp(to_char(year, '9999'), 'YYYY'))"
      "start_date" : "start_date"
      "commitment_date" : "commitment_date"
      "end_date" : "end_date"
    
    dateFieldsSelect = (dateFieldQ(f,q) for f,q of dateFields).join(',') 

    query = pgclient.query "
        SELECT
          *, #{dateFieldsSelect}
        FROM 
          aiddata2 
        #{if DEBUG_updateRowsLimit? then 'LIMIT '+DEBUG_updateRowsLimit}
      "
    query.on 'row', (row) ->

      if OMIT_NULL_VALUE_FIELDS_IN_COMMITMENTS_JSON
        for k,v of row
          unless v?
            delete row[k]


      row.origin = locationNameToCode[row.donor]
      row.dest = locationNameToCode[row.recipient]

      # won't work for negative dates as long as https://jira.mongodb.org/browse/SERVER-961 is not fixed
      if IMPORT_COMMITMENT_DATES_AS_ is "date"
        for f,q of dateFields 
          if row[f]?
            row[f] = { "$date" : row[f] }

      delete row.donor
      delete row.donorcode
      delete row.recipient
      delete row.recipientcode
      delete row.year

      # assuming that stringify produces a one-liner
      fs.writeSync fd, JSON.stringify(row) + "\n"

    query.on 'end', ->  
      fs.closeSync fd
      callWhenEnded()







  (callWhenEnded) ->
    console.log "> Upserting locations in MongoDB"

    importCollectionToMongo  "locations", LOCATIONS_TEMP_FILE, ["code"], callWhenEnded



  (callWhenEnded) ->
    console.log "> Upserting commitments in MongoDB"

    importCollectionToMongo  "aiddata", AIDDATA_TEMP_FILE, ["aiddata_id"], callWhenEnded




], (err, results) ->

    if err?
      console.warn "> There was an error: " + err
    else
      console.log("> All tasks finished")
      fs.unlink(AIDDATA_TEMP_FILE)
      fs.unlink(LOCATIONS_TEMP_FILE)
    
    mongodb.close()
    pgclient.end()

