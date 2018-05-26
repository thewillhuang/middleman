FROM node

RUN mkdir /src

WORKDIR /src

ADD ./package.json /src/package.json

RUN npm install

CMD sh ./wait-for-pg.sh db npm run test
