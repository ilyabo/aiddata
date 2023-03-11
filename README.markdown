Visualizations of the [AidData][aiddata]. View in action [here][demo].

To install dependencies run

    npm install

or

    yarn install

Then, to run locally:

    npm start

or

     yarn start

Install [foreman][foreman] (it is included in the Heroku toolbelt, see below).

Then, run

    foreman start

This is a Heroku-ready version. To publish a new app, install the [Heroku toolbelt][toolbelt] and use:

    heroku create

    git push heroku master

    heroku ps:scale web=1
    heroku config:set NODE_ENV=production

For more details, check out [Getting Started with Node.js on Heroku][guide].

[foreman]: https://github.com/ddollar/foreman
[demo]: http://aiddata.herokuapp.com
[aiddata]: http://aiddata.org
[toolbelt]: https://toolbelt.heroku.com/
[guide]: https://devcenter.heroku.com/articles/nodejs
