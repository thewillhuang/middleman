import { Pool } from 'pg';
import { PGCONFIG } from './config/index';

let cachedPool = null;

export default () => {
  if (!cachedPool) {
    cachedPool = new Pool(PGCONFIG);
  }

  cachedPool.on('error', async (error, client) => {
    client.release();
    await cachedPool.end();
    cachedPool = null;
  });

  return cachedPool;
};
