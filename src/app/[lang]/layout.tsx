import type { ReactNode } from 'react';


type LayoutParams = { lang: string };

export default async function LangLayout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<LayoutParams>;
}) {
  await params;
  return <>{children}</>;
}
