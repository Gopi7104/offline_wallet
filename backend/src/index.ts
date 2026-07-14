import { createServer } from './platform/httpServer';
import { loadConfig } from './platform/config';

const config = loadConfig();
const app = createServer();

app.listen(config.port, () => {
  // Structured, secret-free logging (ARCHITECTURE.md §11, NFR-SEC-08).
  console.log(
    JSON.stringify({
      msg: 'backend.started',
      env: config.env,
      port: config.port,
      version: '1.1.0',
    }),
  );
});
