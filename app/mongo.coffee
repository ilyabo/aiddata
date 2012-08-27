mongodb = require 'mongodb'
conf = require('../.dbconf').mongodb


open = (callback) ->
  ifnot = (err, cb) -> if not err then cb() else callback(err)
  srv = new mongodb.Server(conf.host, conf.port)
  db = new mongodb.Db(conf.database, srv)
  db.open (err, p_client) -> ifnot err, -> 
    db.authenticate conf.user, conf.password, -> ifnot err, -> 
      callback err, db

@open = open


@collection = (collName, callback) ->
  open (err, db) ->
    if err? then callback err
    else
      db.collection collName, callback
