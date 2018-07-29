import express from 'express';
import { postgraphile } from 'postgraphile';
import cachedPool from './cachedPool';
import {
  POSTGRAPHQLCONFIG,
  schemas,
  isDevelopment,
  PGCONFIG,
} from './config/index';

const app = express();

app.get('/', (req, res) => {
  res.send('pong');
});
app.use(postgraphile(cachedPool(PGCONFIG), schemas, POSTGRAPHQLCONFIG));

export default app;
