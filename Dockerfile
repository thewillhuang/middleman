FROM node

RUN mkdir /src

WORKDIR /src

COPY package.json .

RUN npm install --quiet

COPY . .

CMD sh ./wait-for-pg.sh db npm run test
