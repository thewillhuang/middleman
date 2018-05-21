import { Pool } from 'pg';

let cachedPool = null;

export default (PGCONFIG) => {
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
