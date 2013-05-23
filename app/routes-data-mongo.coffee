@include = ->

  mongo = require './mongo'



  @get '/mongo/purpose-codes.json': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else
        coll.distinct "coalesced_purpose_code", (err, result) =>
          if err? then @next(err)
          else
            @send result




  @get '/mongo/aiddata-group.csv': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else
        # , date : new Date(doc.date).getFullYear() }
        # keys = (doc) -> { origin : doc.origin, dest: doc.dest }
        keys = { origin:true }   # coalesced_purpose_code:true }
        condition = { coalesced_purpose_code : "23010"}  #   (doc) -> (new Date(doc.date).getFullYear() is 2005)    # 
        initial = { ccsum : 0 }
        reduce = (obj,prev) ->  
          c = obj.commitment_amount_usd_constant
          unless isNaN(c)
            prev.ccsum += Math.round(c)

        finalize = null
        command = true
        options = null

        coll.group keys, condition, initial, reduce, finalize, command, options, (err, result) =>
          if err? then @next(err)
          else
            ###
            nested = d3.nest()
              .key((r) -> r.donor)
              .key((r) -> r.recipient)
              #.key((r) -> +r.date)
              #.key((r) -> r.purpose_code)
              #.rollup((list) -> 
              #    if list.length == 1
              #      +list[0].sum_amount_usd_constant
              #    else
              #      list.map (r) -> +r.sum_amount_usd_constant
              #)
              .map(result)
            ###
            @send utils.objListToCsv(result)



  @get '/mongo/aiddata-aggregate.csv': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else
        a = {
          $group : {
            _id : "$origin",
            total : { $sum : "$commitment_amount" }
          }
        }

        coll.aggregate a, (err, result) =>
          if err? then @next(err)
          else        
            @send utils.objListToCsv(items)




  @get '/mongo/aiddata-map-reduce.csv': ->
    mongo.collection 'aiddata', (err, coll) =>
      if err? then @next(err)
      else

        prop2sum = "commitment_amount_usd_constant"

        # map = () -> 
        #   console.log "Hi"
        #   key = this.origin
        #   #origin: this.origin
        #   #dest: this.dest
        #   #date: new Date(this.date).getFullYear()

        #   value = 
        #     # sum :
        #     #   unless isNaN(this[prop2sum])
        #     #     this[prop2sum]
        #     #   else
        #     #     0
        #     count : 1

        #   emit key, value

        # reduce = (key, values) -> 
        #   sum = 0
        #   count = 0
        #   for val in values
        #     unless isNaN(val[prop2sum]) then sum += val[prop2sum]
        #     count += val.count

        #   # { count: count, sum: sum }
        #   return { count: count }


        map = () -> emit(this.origin, { count:1 })
        reduce = (key, values) -> 
          return { count: 1 }


        coll.mapReduce map, reduce, { out: { replace : 'aiddataMapReduce' } }, (err, coll) =>
          if err? then @next(err)
          else        
            coll.find().toArray (err, items) =>
              if err? then @next(err)
              else        
                @send utils.objListToCsv(items)


