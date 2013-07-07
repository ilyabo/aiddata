Visualizations of the [AidData][aiddata]. View in action [here][demo].


To install dependencies run

    npm install


Install [foreman][foreman] (it is a part of Heroku toolbelt)

Then, run

    foreman start


This is a Heroku-ready version. To publish a new app install the [Heroku toolbelt][https://toolbelt.heroku.com/] and use:

    heroku create

    git push heroku master

    heroku ps:scale web=1
    heroku config:set NODE_ENV=production


For more details, check out [Getting Started with Node.js on Heroku][https://devcenter.heroku.com/articles/nodejs].



[foreman]: https://github.com/ddollar/foreman
[demo]: http://aiddata.herokuapp.com
[aiddata]: http://aiddata.org