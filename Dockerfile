FROM node

RUN mkdir /webapp

WORKDIR /webapp

COPY package.json .

RUN yarn

COPY . .

CMD sh ./wait-for-pg.sh db yarn test
