# Module: FileLineReader
# Constructor: FileLineReader(filename, bufferSize = 8192)
# Methods: hasNextLine() -> boolean
#          nextLine() -> String
#

fs = require "fs"

@open = (filename, bufferSize) ->

  bufferSize = 8192  unless bufferSize
  
  #private:
  currentPositionInFile = 0
  buffer = ""
  fd = fs.openSync(filename, "r")
  
  # return -1
  # when EOF reached
  # fills buffer with next 8192 or less bytes
  fillBuffer = (position) ->
    res = fs.readSync(fd, bufferSize, position, "ascii")
    buffer += res[0]
    return -1  if res[1] is 0
    position + res[1]

  currentPositionInFile = fillBuffer(0)
  
  #public:
  @hasNextLine = ->
    while buffer.indexOf("\n") is -1
      currentPositionInFile = fillBuffer(currentPositionInFile)
      return false  if currentPositionInFile is -1
    return true  if buffer.indexOf("\n") > -1
    false

  
  #public:
  @nextLine = ->
    lineEnd = buffer.indexOf("\n")
    result = buffer.substring(0, lineEnd)
    buffer = buffer.substring(result.length + 1, buffer.length)
    result

  return @
