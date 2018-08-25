import { join } from "path";
import url from "url";
import bluebird from "bluebird";
import ca from "./rds-combined-ca-bundle.pem";

const {
  PORT = 3000,
  DATABASE = "middleman",
  NODE_ENV = "development",
  JWT_SECRET = "lololol",
  DB_URL = `postgresql://williamhuang@localhost/${DATABASE}`
} = process.env;

export const ENV = NODE_ENV;
export const isDevelopment = NODE_ENV === "development";
export const isTest = NODE_ENV === "test";
export const isProduction = NODE_ENV === "production";

const params = url.parse(
  isTest ? `postgresql://williamhuang@db/${DATABASE}` : DB_URL
);
const auth = params.auth.split(":");

export const APPPORT = PORT;

export const schemas = [`${DATABASE}_pub`];

export const PGCONFIG = {
  user: auth[0],
  password: auth[1],
  host: params.hostname,
  port: params.port,
  database: params.pathname.split("/")[1],
  idleTimeoutMillis: 1000,
  connectionTimeoutMillis: 5000,
  Promise: bluebird
};

// export const cachePath = '../dist/postgraphile.cache';

export const POSTGRAPHQLCONFIG = {
  dynamicJson: true,
  graphiql: true,
  // watchPg: isDevelopment,
  graphqlRoute: "/",
  enableQueryBatching: true,
  ignoreRBAC: false,
  includeExtensionResources: false,
  disableQueryLog: isProduction,
  extendedErrors: [
    "severity",
    "code",
    "detail",
    "hint",
    "position",
    "internalPosition",
    "internalQuery",
    "where",
    "schema",
    "table",
    "column",
    "dataType",
    "constraint",
    "file",
    "line",
    "routine"
  ],
  jwtSecret: JWT_SECRET,
  jwtPgTypeIdentifier: `${DATABASE}_pub.jwt_token`,
  pgDefaultRole: `${DATABASE}_visitor`,
  legacyRelations: "omit",
  jwtVerifyOptions: {
    algorithms: ["HS256"],
    maxAge: "1h",
    audience: "postgraphile",
    issuer: "postgraphile"
  }
};

export const cachePath = "../dist/postgraphile.cache";

if (!isDevelopment && !isTest) {
  PGCONFIG.ssl = {
    rejectUnauthorized: true,
    ca
  };
  // POSTGRAPHQLCONFIG.readCache = join(__dirname, cachePath);
}

if (isDevelopment) {
  POSTGRAPHQLCONFIG.exportGqlSchemaPath = join(
    __dirname,
    "../../dist",
    "schema.graphql"
  );
}
