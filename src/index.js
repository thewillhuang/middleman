import app from "./server";
import { APPPORT as PORT, ENV } from "./config/index";

app.listen(PORT);

console.log(`nodejs server starting at port: ${PORT} in ${ENV} mode`);
