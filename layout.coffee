@include = ->

  @view 'bootstrap.eco': '''
    <% @title = "AidData" %>
    <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <title><%= @title %></title>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="description" content="<%= @title %>">
          <meta name="author" content="Ilya Boyandin">

          <!-- Le styles -->
          <link href="libs/bootstrap/css/bootstrap.css" rel="stylesheet">
          <link href="libs/jquery-ui-bootstrap/css/custom-theme/jquery-ui-1.8.16.custom.css" rel="stylesheet">
          <link href="libs/tipsy-new/stylesheets/tipsy.css" rel="stylesheet">
          <link href="css/layout.css" rel="stylesheet">

          <style>
            body {
              padding-top: 60px; 
            }
          </style>
          <link href="libs/bootstrap/css/bootstrap-responsive.css" rel="stylesheet">

          <!-- Le HTML5 shim, for IE6-8 support of HTML5 elements -->
          <!--[if lt IE 9]>
            <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
          <![endif]-->

          <!-- Le fav and touch icons -->
          <link rel="shortcut icon" href="libs/bootstrap/ico/favicon.ico">
          <link rel="apple-touch-icon-precomposed" sizes="114x114" href="libs/bootstrap/ico/apple-touch-icon-114-precomposed.png">
          <link rel="apple-touch-icon-precomposed" sizes="72x72" href="libs/bootstrap/ico/apple-touch-icon-72-precomposed.png">
          <link rel="apple-touch-icon-precomposed" href="libs/bootstrap/ico/apple-touch-icon-57-precomposed.png">

          <script>dynamicDataPath = "data/cached/";</script>
        </head>

        <body>

          <div class="navbar navbar-fixed-top">
            <div class="navbar-inner">
              <div class="container">
                <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse" href="#">
                  <span class="icon-bar"></span>
                  <span class="icon-bar"></span>
                  <span class="icon-bar"></span>
                </a>
                <a class="brand" href="bubbles"><%= @title %></a>

                <div class="nav-collapse">
                  <ul class="nav">


                    <li <%=(if @page == "bubbles" then 'class=active' else "") %> >
                    <a href="bubbles">Bubbles</a></li>

                    <li <%=(if @page == "ffprints" then 'class=active' else "") %>>
                      <a href="ffprints">Flowprints</a></li>

                    <li <%=(if @page == "horizon" then 'class=active' else "") %> >
                    <a href="horizon">Horizon</a></li>

                    <li <%=(if @page == "crossfilter" then 'class=active' else "") %> >
                    <a href="crossfilter">Crossfilter</a></li>


                    <li <%=(if @page == "purposeTree" then 'class=active' else "") %> >
                    <a href="purpose-tree">Purposes</a></li>

                    <!--
                    <li <%=(if @page == "flowmap" then 'class=active' else "") %> >
                    <a href="flowmap">Flowmap</a></li>


                    <li <%=(if @page == "time-series" then 'class=active' else "") %> >
                    <a href="time-series">Time series</a></li>

                    <li <%=(if @page == "chord" then 'class=active' else "") %> >
                    <a href="chord">Chord</a></li>
                    -->

                    <!--<li><a href="refugees-ffprints">Refugees</a></li>-->
                  </ul>
                </div><!--/.nav-collapse -->


              </div>
            </div>
          </div>

          <script src="js/browser-check.js"></script>
          <script src="d3.v2.js"></script>
          <script src="libs/chroma/chroma.pack.min.js"></script>
          <script src="libs/jquery/jquery-1.7.1.min.js"></script>
          <script src="libs/tipsy-new/javascripts/jquery.tipsy.js"></script>

          <script src="libs/bootstrap/js/bootstrap.min.js"></script>
          <script src="libs/jquery-ui-bootstrap/js/jquery-ui-1.8.16.custom.min.js"></script>

          <div class="container">

            <%- @body %>

          </div> <!-- /container -->


        </body>
      </html>
    '''
