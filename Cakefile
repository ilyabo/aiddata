{spawn, exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
log = console.log
      
task 'build', ->
  run 'coffee -o static/js/coffee -c ' +
                'utils.coffee ffprints*.coffee bubbles*.coffee'

task 'rerun', ->
  invoke 'build'
  run 'PATH=$PATH:/usr/local/bin  && kill -9 `pgrep -f app.coffee`'
  now = new Date()
  date = "#{now.getFullYear()}-#{now.getMonth()+1}-#{now.getDate()}"

  if !path.existsSync('logs') then fs.mkdir('logs', 0o0755)
  run "coffee app.coffee >logs/#{date}.log  2>&1"
  run "tail -f logs/#{date}.log"
    



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
