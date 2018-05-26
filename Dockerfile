FROM node

RUN mkdir /webapp

WORKDIR /webapp

COPY package.json .

RUN npm install --quiet

COPY . .

CMD sh ./wait-for-pg.sh db npm run test
