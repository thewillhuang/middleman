import { createPostGraphileSchema } from 'postgraphile-core';
import { POSTGRAPHQLCONFIG, schemas, cachePath, pool } from './config';

async function main() {
  console.log('generating cache');
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
