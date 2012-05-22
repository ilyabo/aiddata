{spawn, exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
log = console.log

cachedPath = 'static/data/cached'


option '-e', '--environment [ENVIRONMENT_NAME]', 'set the environment for `restart`'


task 'build', ->
  run 'coffee -o static/coffee -c ' +
                'frontend/*.coffee frontend/*/*.coffee'



task 'restart', 'Build, kill existing app.coffee processes and run app.coffee again', (options) ->
  options.environment or= 'production'
  invoke 'build'
  run 'PATH=/usr/bin:/usr/local/bin  && kill -9 `pgrep -f app.coffee`'
  now = new Date()
  date = "#{now.getFullYear()}-#{now.getMonth()+1}-#{now.getDate()}"

  if !path.existsSync('logs') then fs.mkdir('logs', parseInt('0755', 8))
  run "NODE_ENV=#{options.environment} coffee app.coffee"



task 'refresh-views', ->
  pg = require('./pg-sql').include()

  views = [
      "donor_recipient_year_purpose_ma",
      "totals_for_donor_ma",
      "totals_for_recipient_ma",
      "totals_for_recipient_to_donor_ma" ]

  console.log "Refreshing views #{views}"

  for view in views
    pg.sql "select '#{view}' as view, refresh_matview('#{view}')",
      (err, data) =>
        v = data.rows[0].view
        unless err?
          console.log "Success refreshing #{v}"
        else
          console.log "Refreshing #{v} failed", err
    


task 'refresh-cached', ->
  if !path.existsSync(cachedPath) then fs.mkdirSync(cachedPath, parseInt('0755', 8))

  files = [
    "aiddata-donor-totals.csv",  
    "aiddata-recipient-totals.csv", 
    "flows.json",
    "aiddata-nodes.csv", 
    "aiddata-totals-d-r-y.csv"]
  for file in files
    console.log "Refreshing file #{file}"
    run  "wget http://localhost:3000/#{file} -O #{cachedPath}/#{file}"



run = (args...) ->
  for a in args
    switch typeof a
      when 'string' then command = a
      when 'object'
        if a instanceof Array then params = a
        else options = a
      when 'function' then callback = a
  
  command += ' ' + params.join ' ' if params?
  cmd = spawn '/bin/sh', ['-c', command], options
  cmd.stdout.on 'data', (data) -> process.stdout.write data
  cmd.stderr.on 'data', (data) -> process.stderr.write data
  process.on 'SIGHUP', -> cmd.kill()
  cmd.on 'exit', (code) -> callback() if callback? and code is 0
