{spawn, exec} = require 'child_process'
fs = require 'fs'
path = require 'path'
log = console.log
      
task 'build', ->
  run 'coffee -o static/coffee -c ' +
                'frontend/*.coffee frontend/*/*.coffee'

task 'restart', ->
  invoke 'build'
  run 'PATH=$PATH:/usr/local/bin  && kill -9 `pgrep -f app.coffee`'
  invoke '_start'
    

task 'start', ->
  invoke 'build'
  invoke '_start'

task '_start', ->
  now = new Date()
  date = "#{now.getFullYear()}-#{now.getMonth()+1}-#{now.getDate()}"

  if !path.existsSync('logs') then fs.mkdir('logs', parseInt('0755', 8))
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
