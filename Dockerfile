FROM node

RUN mkdir /webapp

WORKDIR /webapp

COPY package.json .

RUN yarn

COPY . .

CMD sh ./wait.sh "npm run db:up:test" "yarn test"
