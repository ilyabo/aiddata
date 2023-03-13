FROM node:8-alpine
ENV NODE_ENV=production
WORKDIR /usr/src/app
COPY . .
RUN yarn install --frozen-lockfile
EXPOSE 8080
RUN chown -R node /usr/src/app
USER node
CMD ["yarn", "start"]