import { join } from 'path';
import url from 'url';
import bluebird from 'bluebird';
import ca from './rds-combined-ca-bundle.pem';

const DATABASE = 'middleman';

const {
  PORT = 3000,
  NODE_ENV = 'development',
  JWT_SECRET = 'lololol',
  DB_URL = `postgresql://williamhuang@localhost/${DATABASE}`,
} = process.env;

const params = url.parse(DB_URL);
const auth = params.auth.split(':');

export const ENV = NODE_ENV;

export const isDevelopment = NODE_ENV === 'development';
export const isTest = NODE_ENV === 'test';
export const isProduction = NODE_ENV === 'production';

export const APPPORT = PORT;

export const POSTGRAPHQLCONFIG = {
  dynamicJson: true,
  graphiql: true,
  watchPg: isDevelopment,
  graphqlRoute: '/',
  disableQueryLog: isProduction,
  extendedErrors: ['hint', 'detail', 'errcode'],
  jwtSecret: JWT_SECRET,
  jwtPgTypeIdentifier: `${DATABASE}_pub.jwt_token`,
  pgDefaultRole: `${DATABASE}_visitor`,
  legacyRelations: 'omit',
  exportGqlSchemaPath: join(__dirname, '../../dist', 'schema.graphql'),
  jwtVerifyOptions: {
    algorithms: ['HS256'],
    maxAge: '1h',
    audience: 'postgraphile',
    issuer: 'postgraphile',
  },
};

export const schemas = [`${DATABASE}_pub`];

export const PGCONFIG = {
  user: auth[0],
  password: auth[1],
  host: params.hostname,
  port: params.port,
  database: params.pathname.split('/')[1],
  idleTimeoutMillis: 1000,
  connectionTimeoutMillis: 5000,
  Promise: bluebird,
};

export const cachePath = '../../dist/postgraphile.cache';

if (!isDevelopment && !isTest) {
  PGCONFIG.ssl = {
    rejectUnauthorized: true,
    ca,
  };
  POSTGRAPHQLCONFIG.readCache = join(__dirname, cachePath);
}
