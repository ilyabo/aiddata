this.timeSliderControl = ->

  step = d3.time.day
  format = d3.time.format("%d.%m.%Y")

  min = d3.time.month.offset(new Date(), -1)
  max = new Date()

  width = 300
  height = 25


  chart = (selection) -> init(selection)

  chart.min = (_) -> if (!arguments.length) then min else min = _; chart

  chart.max = (_) -> if (!arguments.length) then max else max = _; chart

  # Expects a d3.time interval
  chart.step = (_) -> if (!arguments.length) then step else step = _; chart

  chart.format = (_) -> if (!arguments.length) then format else format = _; chart

  chart.width = (_) -> if (!arguments.length) then width else width = _; chart

  chart.height = (_) -> if (!arguments.length) then height else height = _; chart


  outerDiv = null
  current = scale = null
  stepSize = null
  rangeValues = null

  init = (selection) ->

    data = selection.datum()

    if (data?)
      min = d3.min(data)
      max = d3.max(data)


    min = step(min)
    max = step(max)
    current = min

    rangeValues = step.range(min, max)
    rangeValues.push(max) # will not be in the range
    rangeValues = rangeValues.map (d) -> d.getTime()

    numSteps = rangeValues.length

    stepSize = width / numSteps

    #console.log min, max, numSteps

    ###
    numSteps = do ->
      count = 0; a = min
      (a = step.offset(a, 1); count++) while a < max
      count
    ###
    timeScale = d3.time.scale().domain([min, max]).range([0, width])

    mousemove = (d) ->
      r = outerDiv.select(".range")[0][0]
      # the handle must be in the middle of the mouse cursor => +3
      time = step(timeScale.invert(d3.mouse(r)[0] + 3))  

      time = min if time < min
      time = max if time > max
      chart.setTime(time)

    outerDiv = selection.append("div")
      .attr("class", "timeSlider")
      #.on 'mousemove', mousemove

    caption = outerDiv.append("div")
      .attr("class", "caption")
      #.on 'mousemove', mousemove


    range = outerDiv.append("div")
      .attr("class", "range")
      .style("width", "#{width}px")
      .style("height", "#{height}px")
      .on 'mousemove', mousemove
        

 
    handle = range.append("div")
      .attr("class", "handle")
      .style("width", stepSize + "px")
      .style("height", "#{height}px")

    update()


  listeners = { change: [] }

  chart.on = (event, handler) ->
    listeners.change.push handler
    chart


  chart.setTime = (time) ->
    time = step(time)        # align to step
    if current.getTime() != time.getTime()
      #console.log "slider.setTime",time, "<>", current
      if min <= time <= max 
        old = current
        current = time
        handler(current, old) for handler in listeners.change
        update()

  chart.current = -> current

  chart.currentIndex = -> rangeValues.indexOf(step(current).getTime())

  update = ->

    #pos = Math.round(100 * chart.currentIndex() / rangeValues.length) + "%"
    pos = $(".range", outerDiv[0]).offset().left + 1  +
      (chart.currentIndex() * stepSize) + "px"
    #console.log pos
    outerDiv.select(".handle")
      .style("left", pos)

    outerDiv.select(".caption")
      .text(format(current))



  chart
