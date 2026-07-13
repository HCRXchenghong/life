import { env } from "cloudflare:workers";
import {
  authorizeBootstrapPolicy,
  type BootstrapAuthorization,
} from "./security/bootstrap-policy";

type BootstrapEnv = {
  ADMIN_BOOTSTRAP_EMAILS?: string;
};

export function authorizeBootstrap(
  requestHeaders: Headers,
  hostname: string,
): BootstrapAuthorization {
  const configured = (env as unknown as BootstrapEnv).ADMIN_BOOTSTRAP_EMAILS;
  return authorizeBootstrapPolicy(requestHeaders, hostname, configured);
}
