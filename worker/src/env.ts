export interface Env {
  DB: D1Database;
  KV: KVNamespace;
  AUDIO: R2Bucket;
  GATEWAY_URL: string;
  GATEWAY_SHARED_SECRET: string;
  TOKEN_SIGNING_KEY: string;
}
