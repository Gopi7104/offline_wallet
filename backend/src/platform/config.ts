/**
 * Environment configuration (ARCHITECTURE.md §11 "Configuration", §12).
 * Infra config comes from the environment; server-driven business limits
 * are fetched via GET /v1/config in a later task, not hard-coded here.
 */
export interface AppConfig {
  readonly env: string;
  readonly port: number;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return {
    env: env.NODE_ENV ?? 'development',
    port: Number(env.PORT ?? 3000),
  };
}
