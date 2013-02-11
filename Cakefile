log = console.log
app = "app/app.coffee"
util = (require './os-utils')


cachedPath = 'data/static/data/cached'


option '-e', '--environment [ENVIRONMENT_NAME]', 'set the environment for `restart`'


task 'build', ->
  util.mkdir "static"
  util.mkdir "static/coffee"
  util.mkdir "static/coffee/charts"

  util.run 'coffee -o static/coffee -c app/frontend/*.coffee app/frontend/*/*.coffee'
  util.run 'coffee -o static/coffee/charts -c app/charts/*.coffee'


# See: http://stackoverflow.com/questions/7259232/how-to-deploy-node-js-in-cloud-for-high-availability


task 'restart', 'Build, kill existing app processes and util.run it again', (options) ->
  options.environment or= 'production'
  invoke 'build'
  util.run 'PATH=/usr/bin:/usr/local/bin  && kill -9 `pgrep -f "coffee '+app+'"`'

  util.run "NODE_ENV=#{options.environment} coffee "+app


forever = (action, options) ->
  invoke 'build'
  options.environment or= 'production'
  #if !path.existsSync('logs') then fs.util.mkdir('logs', parseInt('0755', 8))
  util.run "NODE_ENV=#{options.environment} " +
      "node_modules/forever/bin/forever #{action} -c coffee " +
      " --sourceDir ./" +
      " -p ./" +
      " --pidFile forever.pid "+
      #" -l ./logs/aiddata.log "+
      #" -o ./logs/logs/aiddata.out "+
      #" -e ./logs/logs/aiddata.err "+
      " -a" +   # append logs
      " " + app


task 'restart-forever', (options) -> forever 'restart', options
task 'start-forever', (options) -> forever 'start', options
task 'stop-forever', (options) -> util.run "node_modules/forever/bin/forever stop -c coffee " + app
task 'list-forever', (options) -> util.run "node_modules/forever/bin/forever list"


task 'import-data', ->
  require './data/imports/aiddata'


task 'refresh-views', ->
  pg = require('./pg-sql')

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
  util.mkdir cachedPath

  files = [
    "aiddata-donor-totals.csv",  
    "aiddata-recipient-totals.csv", 
    "flows.csv",
    #"flows.json",
    "aiddata-nodes.csv", 
    "aiddata-totals-d-r-y.csv"]
  for file in files
    console.log "Refreshing file #{file}"
    cmd = "wget http://localhost:3000/#{file} -O #{cachedPath}/#{file}"
    console.log "Running '#{cmd}'"
    util.run  cmd




