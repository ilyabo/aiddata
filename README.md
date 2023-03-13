# Visualizations of the [AidData](http://aiddata.org)

![image](https://user-images.githubusercontent.com/351828/224481037-fee5fcb6-6211-4051-ae3f-1317b2193446.png)

Try in action [here](https://aiddata.boyandin.me/).

To install dependencies run

    npm install  # or   yarn install

Then, to run locally:

    npm start  # or  yarn start

Then, open in browser: [http://localhost:8080](http://localhost:8080).

## Run in Docker

Build an image:

    docker build -t aiddata .

Run the container:

    docker run --name aiddata -dp 8080:8080 aiddata

## Heroku

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
