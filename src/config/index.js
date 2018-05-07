import { join } from 'path';
import url from 'url';
import bluebird from 'bluebird';
import { Pool } from 'pg';
import ca from './rds-combined-ca-bundle.pem';

const {
  PORT = 3000,
  NODE_ENV = 'development',
  JWT_SECRET = 'lololol',
  DB_URL = 'postgresql://williamhuang@localhost/mass-consensus',
} = process.env;

const params = url.parse(DB_URL);
const auth = params.auth.split(':');

export const ENV = NODE_ENV;
export const isDevelopment = NODE_ENV === 'development';
export const isProduction = NODE_ENV === 'production';
export const APPPORT = PORT;
export const POSTGRAPHQLCONFIG = {
  dynamicJson: true,
  graphiql: true,
  graphqlRoute: '/',
  disableQueryLog: isProduction,
  extendedErrors: ['hint', 'detail', 'errcode'],
  jwtSecret: JWT_SECRET,
  jwtPgTypeIdentifier: 'm_pub.jwt_token',
  pgDefaultRole: 'person_anonymous',
  legacyRelations: 'omit',
  jwtVerifyOptions: {
    algorithms: ['HS256'],
    maxAge: '1h',
    audience: 'postgraphile',
    issuer: 'postgraphile',
  },
};
export const schemas = ['m_pub'];
export const PGCONFIG = {
  user: auth[0],
  password: auth[1],
  host: params.hostname,
  port: params.port,
  database: params.pathname.split('/')[1],
  idleTimeoutMillis: isDevelopment ? 1000 : 0.001,
  connectionTimeoutMillis: 5000,
  Promise: bluebird,
};
export const cachePath = join(__dirname, '../../dist/postgraphile.cache');

if (!isDevelopment) {
  PGCONFIG.ssl = {
    rejectUnauthorized: true,
    ca,
  };
  // POSTGRAPHQLCONFIG.readCache = cachePath;
}

export const pool = new Pool(PGCONFIG);
