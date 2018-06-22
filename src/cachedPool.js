import { Pool } from 'pg';

let cachedPool = null;

export default PGCONFIG => {
  if (cachedPool === null) {
    console.log('initializing a new pool');
    cachedPool = new Pool(PGCONFIG);
  }

  cachedPool.on('error', async (error, client) => {
    client.release();
    await cachedPool.end();
    cachedPool = new Pool(PGCONFIG);
  });

  return cachedPool;
};
