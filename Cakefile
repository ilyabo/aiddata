{exec} = require 'child_process'

task 'build', 'Build project: compile app/*.coffee', ->
  exec 'coffee --compile --output app/ app/*.coffee', (err, stdout, stderr) ->
    throw err if err
    console.log stdout + stderr


