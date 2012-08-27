mongodb = require 'mongodb'
conf = require('../.dbconf').mongodb


open = (callback) ->
  srv = new mongodb.Server(conf.host, conf.port)
  db = new mongodb.Db(conf.database, srv)
  db.open (err, p_client) ->
    if err? then callback err
    else
      db.authenticate conf.user, conf.password, ->
        if err? then callback err
        else
          callback err, db

@open = open


@collection = (collName, callback) ->
  open (err, db) ->
    if err? then callback err
    else
      db.collection collName, callback
