import type { ReactNode } from 'react';
import MonitorLayout from '@/app/monitor/layout';


export default function LangMonitorLayout({ children }: { children: ReactNode }) {
  return <MonitorLayout>{children}</MonitorLayout>;
}

