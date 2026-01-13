import type { ReactNode } from 'react';
import MemberLayout from '@/app/member/layout';


export default function LangMemberLayout({ children }: { children: ReactNode }) {
  return <MemberLayout>{children}</MemberLayout>;
}

