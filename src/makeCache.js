import { createPostGraphileSchema } from 'postgraphile-core';
import { POSTGRAPHQLCONFIG, schemas, cachePath, PGCONFIG } from './config';
import cachedPool from './cachedPool';

async function main() {
  console.log('generating cache');
  const pool = cachedPool(PGCONFIG);
  await createPostGraphileSchema(pool, schemas, {
    ...POSTGRAPHQLCONFIG,
    writeCache: cachePath,
  });
  await pool.end();
}

main().then(null, (e) => {
  if (e) {
    console.error(e);
  }
  console.log('completed successfully');
  process.exit(1);
});
