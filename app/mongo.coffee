@include = ->

  mongo = require 'mongodb'
  conf = require('../.dbconf').mongodb


  open = (callback) ->
    ifnot = (err, cb) -> if not err then cb() else callback(err)
    srv = new mongo.Server(conf.host, conf.port)
    db = new mongo.Db(conf.database, srv)
    db.open (err, p_client) -> ifnot err, -> 
      db.authenticate conf.user, conf.password, -> ifnot err, -> 
        callback err, db


  collection : (collName, callback) ->
    open (err, db) ->
      if err? then
      else
        db.collection collName, callback
