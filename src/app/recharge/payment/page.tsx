import { getCloudflareContext } from '@opennextjs/cloudflare';
import PaymentClient from './PaymentClient';


export default function RechargePaymentPage() {
  let enableEcpay = true;
  try {
    const context = getCloudflareContext();
    const country = context?.cf?.country;
    enableEcpay = country ? country === 'TW' : true;
  } catch {
    enableEcpay = true;
  }

  return <PaymentClient enableEcpay={enableEcpay} />;
}
