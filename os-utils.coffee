fs = require 'fs'
path = require 'path'
{spawn, exec} = require 'child_process'


@mkdir = (dir) -> if !path.existsSync(dir) then fs.mkdirSync(dir, parseInt('0755', 8))

@run = (args...) ->
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
  cmd.on 'exit', (code) -> 
    if callback?
      if code is 0
        callback()
      else
        callback("Exec exit code: #{code}")
