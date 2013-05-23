@include = ->

  @get '/': -> @render 'bubbles': {layout: 'bootstrap.eco'}

  @get '/breaknsplit': ->    
    @render breaknsplit: {layout: 'bootstrap.eco'}

  @get '/ffprints': -> @render ffprints: {layout: 'bootstrap.eco'}

  @get '/bubbles': -> @render bubbles: {layout: 'bootstrap.eco'}

  @get '/horizon': -> @render horizon: {layout: 'bootstrap.eco'}
 
  @get '/horizon3': -> @render horizon3: {layout: 'bootstrap.eco'}
  @get '/horizon4': -> @render horizon4: {layout: 'bootstrap.eco'}
 
  @get '/flowmap': -> @render flowmap: {layout: 'bootstrap.eco'}
 
  @get '/chord': -> @render chord: {layout: 'bootstrap.eco'}
 
  @get '/crossfilter': -> @render crossfilter: {layout: 'bootstrap.eco'}
 
  @get '/time-series': -> @render tseries: {layout: 'bootstrap.eco'}

  @get '/purpose-tree': -> @render purposeTree: {layout: 'bootstrap.eco'}

  @get '/purpose-pack': -> @render purposePack: {layout: 'bootstrap.eco'}

  @get '/purpose-bars': -> @render purposeBars: {layout: 'bootstrap.eco'}

  @get '/us-donations': -> @render "us-donations": {layout: 'bootstrap.eco'}

  @get '/streemap': -> @render spatialTreemap: {layout: 'bootstrap.eco'}

  @get '/ffprints?refugees': -> 
    @render ffprints: {layout: 'bootstrap.eco', dataset: "refugees"}
