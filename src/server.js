import express from "express";
import { postgraphile } from "postgraphile";
import morgan from "morgan";
import cachedPool from "./cachedPool";
import {
  POSTGRAPHQLCONFIG,
  schemas,
  isDevelopment,
  PGCONFIG
} from "./config/index";

const app = express();

if (isDevelopment) {
  app.use(morgan("dev"));
}

app.get("/", (req, res) => {
  res.send("pong");
});
app.use(postgraphile(cachedPool(PGCONFIG), schemas, POSTGRAPHQLCONFIG));

export default app;
