declare module '@opennextjs/cloudflare' {
  type EnvBindings = Record<string, unknown>;
  type CfMeta = {
    country?: string;
  } & Record<string, unknown>;

  export function getCloudflareContext(): { env: EnvBindings; cf?: CfMeta };
  export function initOpenNextCloudflareForDev(): void;
  export function defineCloudflareConfig<T = Record<string, unknown>>(config: T): T;
}
