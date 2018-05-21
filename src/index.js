import express from 'express';
import { postgraphile } from 'postgraphile';
import morgan from 'morgan';
import {
  APPPORT as PORT,
  PGCONFIG,
  POSTGRAPHQLCONFIG,
  schemas,
  ENV,
  isDevelopment,
  pool,
} from './config/index';

// use cachedPool from container before using another pool
let cachedPool;
if (!cachedPool) {
  cachedPool = pool;
}

const app = express();

if (isDevelopment) {
  app.use(morgan('dev'));
}
app.get('/', (req, res) => {
  res.send('pong');
});
app.use(postgraphile(cachedPool, schemas, POSTGRAPHQLCONFIG));
app.listen(PORT);

console.log(`nodejs server starting at port: ${PORT} in ${ENV} mode`);
