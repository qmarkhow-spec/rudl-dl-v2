import { getCloudflareContext } from '@opennextjs/cloudflare';
import RechargeClient from './RechargeClient';


export default function RechargePage() {
  let enableEcpay = true;
  try {
    const context = getCloudflareContext();
    const country = context?.cf?.country;
    enableEcpay = country ? country === 'TW' : true;
  } catch {
    enableEcpay = true;
  }

  return <RechargeClient enableEcpay={enableEcpay} />;
}
