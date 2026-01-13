import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import { DEFAULT_LOCALE, type Locale, dictionaries } from '@/i18n/dictionary';
import DashboardClient from './DashboardClient';
import { fetchDashboardPage } from '@/lib/dashboard';


const PAGE_SIZE = 10;

type Env = {
  DB?: D1Database;
  ['rudl-app']?: D1Database;
};

export default async function Dashboard() {
  const cookieStore = await cookies();
  const localeCookie = cookieStore.get('locale')?.value as Locale | undefined;
  const resolvedLocale =
    localeCookie && dictionaries[localeCookie] ? localeCookie : DEFAULT_LOCALE;
  const localePrefix = `/${resolvedLocale}`;
  const loginParams = new URLSearchParams({ next: `${localePrefix}/dashboard`, reason: 'auth' });
  const loginUrl = `${localePrefix}/login?${loginParams.toString()}`;
  const uid = cookieStore.get('uid')?.value;
  if (!uid) {
    redirect(loginUrl);
  }

  const ctx = getCloudflareContext();
  const { env } = ctx;

  const bindings = env as Env;
  const DB = bindings.DB ?? bindings['rudl-app'];
  if (!DB) {
    throw new Error('D1 binding DB is missing');
  }

  const initialData = await fetchDashboardPage(DB, uid!, 1, PAGE_SIZE);

  return (
    <div className="space-y-4">
      <DashboardClient initialData={initialData} initialLocale={resolvedLocale} />
    </div>
  );
}
