import { FileSignature, Save } from 'lucide-react';
import { useState } from 'react';

export default function TermsManagement() {
  const [termsContent, setTermsContent] = useState(`
AGENT TERMS & CONDITIONS

1. REGISTRATION POLICY
• All agents must complete KYC verification with valid Aadhaar and PAN documents
• Submitted documents will be verified within 24-48 hours
• Only approved agents can access services in the mobile app

2. NON-REFUNDABLE FEE NOTICE
• Registration fee is non-refundable under any circumstances
• Initial wallet recharge is mandatory for account activation
• Service fees are deducted from wallet balance per transaction

3. VERIFICATION TIMELINE
• Document verification: 24-48 hours from submission
• Agent approval notification sent via SMS and app
• Rejected applications will include reason for rejection

4. INACTIVITY RULE (6 MONTHS)
• Accounts with no activity for 6 consecutive months will be suspended
• Suspended accounts require reactivation process
• Wallet balance retained during suspension period
• After 12 months of inactivity, account may be permanently closed

5. SERVICE DELIVERY
• Agents must process customer applications accurately
• All required documents must be collected from customers
• False information submission leads to immediate account termination

6. WALLET & PAYMENTS
• Minimum balance required for service processing
• Service fees deducted automatically per transaction
• Wallet recharge via authorized payment methods only

7. REFERRAL PROGRAM
• Referral bonus credited after referred agent completes first transaction
• Double-sided rewards for both referrer and referee
• Fraudulent referrals will result in account suspension

8. CODE OF CONDUCT
• Professional behavior required at all times
• Customer data must be kept confidential
• Misuse of system or customer information prohibited

9. TERMINATION
• Admin reserves right to suspend/terminate accounts for policy violation
• No refunds provided upon termination
• Appeal process available for wrongful termination

10. AMENDMENTS
• Terms may be updated with prior notice to agents
• Continued use implies acceptance of updated terms
  `.trim());

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl text-[#1a1a1a] mb-2">Terms, Policies & System Rules</h1>
        <p className="text-[#666666]">Manage agent terms and conditions</p>
      </div>

      {/* Info Box */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded p-4">
        <div className="flex items-start gap-3">
          <FileSignature className="w-5 h-5 text-[#4C4CFF] flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-sm text-[#1a1a1a] mb-1">Connection to Agent App</h3>
            <p className="text-sm text-[#666666]">
              Terms and conditions edited here are immediately visible in the agent mobile app. Agents must accept updated terms to continue using services.
            </p>
          </div>
        </div>
      </div>

      {/* Terms Editor */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded">
        <div className="px-5 py-4 border-b-2 border-[#e5e5e5] flex items-center justify-between">
          <h2 className="text-lg text-[#1a1a1a]">Edit Terms & Conditions</h2>
          <button className="flex items-center gap-2 px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors">
            <Save className="w-4 h-4" />
            <span className="text-sm">Save Changes</span>
          </button>
        </div>
        <div className="p-5">
          <textarea
            value={termsContent}
            onChange={(e) => setTermsContent(e.target.value)}
            className="w-full h-[600px] px-4 py-3 border-2 border-[#e5e5e5] rounded text-sm text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF] font-mono"
            placeholder="Enter terms and conditions..."
          />
        </div>
      </div>

      {/* Key Policy Highlights */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <h3 className="text-base text-[#1a1a1a] mb-3 pb-3 border-b-2 border-[#e5e5e5]">
            Registration Policy
          </h3>
          <ul className="space-y-2 text-sm text-[#666666]">
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>KYC verification mandatory</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>24-48 hour verification timeline</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Non-refundable registration fee</span>
            </li>
          </ul>
        </div>

        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <h3 className="text-base text-[#1a1a1a] mb-3 pb-3 border-b-2 border-[#e5e5e5]">
            Inactivity Rule
          </h3>
          <ul className="space-y-2 text-sm text-[#666666]">
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>6 months inactivity leads to suspension</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Wallet balance retained during suspension</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Reactivation process available</span>
            </li>
          </ul>
        </div>

        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <h3 className="text-base text-[#1a1a1a] mb-3 pb-3 border-b-2 border-[#e5e5e5]">
            Wallet Policy
          </h3>
          <ul className="space-y-2 text-sm text-[#666666]">
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Minimum balance required</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Auto-deduction per transaction</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Authorized recharge methods only</span>
            </li>
          </ul>
        </div>

        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <h3 className="text-base text-[#1a1a1a] mb-3 pb-3 border-b-2 border-[#e5e5e5]">
            Referral Program
          </h3>
          <ul className="space-y-2 text-sm text-[#666666]">
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Double-sided rewards</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Bonus after first transaction</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-[#4C4CFF]">•</span>
              <span>Fraud prevention measures</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
