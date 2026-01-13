# rudl-dl-v2

Next.js 15 + React 19 application prepared for Cloudflare Workers via OpenNext. The app serves localized dashboards and API routes backed by a Cloudflare D1 database and files distributed through an R2-backed CDN.

## Development
- Install dependencies with `npm install`.
- Run the dev server with `npm run dev` (http://localhost:3000).
- The project relies on a D1 binding named `DB`. For local development you can run `npm run dev` (bindings are stubbed via `initOpenNextCloudflareForDev()`), or preview the Worker runtime after building with OpenNext.

### ECPay integration
- The recharge page posts to `/api/recharge/ecpay`, which returns a dynamic form that forwards the user to ECPay.
- Set the following environment variables before running the API:
  - `ECPAY_MERCHANT_ID`
  - `ECPAY_HASH_KEY`
  - `ECPAY_HASH_IV`
  - `ECPAY_MODE` (`stage` by default, set to `production` for live cashier URL)
  - `ECPAY_RETURN_URL` (server-side background callback endpoint, e.g. `https://your-domain/api/recharge/ecpay/notify`)
  - `ECPAY_ORDER_RESULT_URL` (front-end result page)
  - `ECPAY_CLIENT_BACK_URL` (optional: customer back URL, defaults to `/recharge`)
  - `ECPAY_PAYMENT_METHOD` (optional: `Credit`, `ATM`, `CVS`, `BARCODE`; defaults to `Credit`)
  - `ECPAY_PAYMENT_INFO_URL` (background callback for ATM/CVS/BARCODE issue codes, defaults to `/api/recharge/ecpay/payment-info`)
  - `ECPAY_CLIENT_REDIRECT_URL` (front-end redirect after code issuance, defaults to `/recharge/payment-info`)
  - `ECPAY_NEED_EXTRA_PAID_INFO` (`Y` or `N`, defaults to `Y`)
  - `ECPAY_BASE_URL` (optional: base URL used to build defaults; falls back to `http://localhost:3000`)
- The helper also exposes `getQueryTradeInfoUrl()` for hitting the official QueryTradeInfo endpoint (`/Cashier/QueryTradeInfo/V5`) in either stage or production mode.
- Do not hardcode credentials in source control. Use `.env.local` for local testing and configure the same keys in production.

## Cloudflare Workers Deployment
1. Ensure `wrangler.toml` includes the `main = ".open-next/worker.js"` entry, the `ASSETS` binding, and the `WORKER_SELF_REFERENCE` service binding.
2. Build: `npm run cf:build` (generates `.open-next`).
3. Deploy: `npm run cf:deploy` (builds and deploys the Worker via OpenNext).

## Troubleshooting
- Missing D1 binding: API routes and server components return HTTP 500 with "D1 binding DB is missing". Ensure the Worker exposes the binding as `DB` (or temporarily keep `rudl-app` while migrating).
- CDN assets: downloads redirect to `https://cdn.mycowbay.com/<key>`. Confirm that key exists in R2 and the CDN exposes it publicly.
- Locales: middleware redirects to `/en` or `/zh-TW`. Add languages under `src/i18n/messages` and update `src/i18n/locales.ts` for extra locales.

## Useful scripts
- `npm run dev` - local Next.js dev server.
- `npm run build` - standard Next build (useful for linting/diagnostics).
- `npm run cf:build` - build for Cloudflare Workers using OpenNext.
- `npm run cf:deploy` - build + deploy to the configured Cloudflare Worker.

