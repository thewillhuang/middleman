FROM node

RUN mkdir /src

WORKDIR /src

ADD ./package.json /src/package.json

RUN npm install
