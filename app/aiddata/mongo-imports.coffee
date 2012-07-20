@run = ->

  client = new Db('test', new Server("127.0.0.1", 27017, {})),
    test = (err, collection) ->
      collection.insert {a:2}, (err, docs) -> 


        
        collection.find().toArray (err, results) ->
          test.assertEquals(1, results.length)
          test.assertTrue(results[0].a === 2)


          client.close()
    

  client.open (err, p_client) ->
    client.collection('test_insert', test)
