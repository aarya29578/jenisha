export default function Privacy() {
  return (
    <div className="min-h-screen bg-slate-50 px-4 py-12">
      <div className="mx-auto w-full max-w-3xl space-y-6">

        {/* Header */}
        <div className="rounded-3xl bg-white border border-slate-200 shadow-sm p-10 text-center">
          <p className="text-xs font-semibold uppercase tracking-widest text-[#4C4CFF] mb-3">Jenisha Online Service</p>
          <h1 className="text-3xl font-bold text-slate-900 mb-3">Privacy Policy &amp; Account Deletion</h1>
          <p className="text-sm leading-7 text-slate-500 max-w-xl mx-auto">
            This policy applies to the <strong>Jenisha Services</strong> mobile application
            (<code>com.company.jenisha</code>). It explains how we collect, use, and protect your
            data, and how you can request deletion of your account and data.
          </p>
        </div>

        {/* Account Deletion — primary section, shown first for Google Play compliance */}
        <div className="rounded-3xl bg-white border-2 border-[#4C4CFF] shadow-sm overflow-hidden">
          <div className="bg-[#4C4CFF] px-8 py-5">
            <h2 className="text-lg font-bold text-white">Account &amp; Data Deletion</h2>
            <p className="text-sm text-indigo-200 mt-1">How to request deletion of your Jenisha Services account</p>
          </div>
          <div className="p-8 space-y-6">

            <div>
              <h3 className="font-semibold text-slate-900 mb-2">Steps to delete your account</h3>
              <ol className="space-y-3 text-sm text-slate-700">
                <li className="flex gap-3">
                  <span className="flex-shrink-0 w-6 h-6 rounded-full bg-[#4C4CFF] text-white text-xs font-bold flex items-center justify-center">1</span>
                  <span>Open the <strong>Jenisha Services</strong> app on your device.</span>
                </li>
                <li className="flex gap-3">
                  <span className="flex-shrink-0 w-6 h-6 rounded-full bg-[#4C4CFF] text-white text-xs font-bold flex items-center justify-center">2</span>
                  <span>Go to <strong>Profile → Settings → Delete Account</strong>, or contact us directly using the details below.</span>
                </li>
                <li className="flex gap-3">
                  <span className="flex-shrink-0 w-6 h-6 rounded-full bg-[#4C4CFF] text-white text-xs font-bold flex items-center justify-center">3</span>
                  <span>Send your deletion request with your <strong>registered phone number or User ID</strong> so we can verify your identity.</span>
                </li>
                <li className="flex gap-3">
                  <span className="flex-shrink-0 w-6 h-6 rounded-full bg-[#4C4CFF] text-white text-xs font-bold flex items-center justify-center">4</span>
                  <span>We will confirm and process your request within <strong>7 business days</strong>.</span>
                </li>
              </ol>
            </div>

            <div className="rounded-xl bg-slate-50 border border-slate-200 p-5 space-y-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-400 mb-3">Contact us to delete your account</p>
              <div className="flex items-center gap-3 text-sm text-slate-700">
                <span className="text-base">✉️</span>
                <a href="mailto:jenishaonlineservice@gmail.com" className="text-[#4C4CFF] underline">jenishaonlineservice@gmail.com</a>
              </div>
              <div className="flex items-center gap-3 text-sm text-slate-700">
                <span className="text-base">📞</span>
                <a href="tel:+918097774408" className="text-[#4C4CFF] underline">+91 80977 74408</a>
              </div>
            </div>

            <div>
              <h3 className="font-semibold text-slate-900 mb-3">What data is deleted</h3>
              <ul className="space-y-2 text-sm text-slate-700">
                {[
                  'Your account profile (name, phone number, email, shop name)',
                  'Uploaded identity documents (Aadhaar, PAN)',
                  'Profile photo and shop logo',
                  'Application history and service requests',
                  'Wallet transaction records associated with your account',
                ].map((item) => (
                  <li key={item} className="flex gap-2">
                    <span className="text-green-500 font-bold mt-0.5">✓</span>
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <h3 className="font-semibold text-slate-900 mb-3">What data is retained and why</h3>
              <ul className="space-y-2 text-sm text-slate-700">
                {[
                  { item: 'Financial transaction records', reason: 'Retained for 5 years as required by Indian financial regulations' },
                  { item: 'Fraud prevention logs', reason: 'Retained for up to 90 days to protect against misuse' },
                  { item: 'Legal compliance records', reason: 'Retained only as required by applicable law' },
                ].map(({ item, reason }) => (
                  <li key={item} className="flex gap-2">
                    <span className="text-amber-500 font-bold mt-0.5">!</span>
                    <span><strong>{item}</strong> — {reason}.</span>
                  </li>
                ))}
              </ul>
            </div>

          </div>
        </div>

        {/* Data Collection */}
        <div className="rounded-3xl bg-white border border-slate-200 shadow-sm divide-y divide-slate-100">
          {[
            {
              title: 'Data We Collect',
              content: 'We collect your name, phone number, email address, shop name, address, identity documents (Aadhaar, PAN), profile photo, and device information required to verify and operate your Jenisha Services account.',
            },
            {
              title: 'How We Use Your Data',
              content: 'Your data is used to verify your identity, process service applications, manage wallet transactions, send important notifications, prevent fraud, and comply with applicable laws. We do not sell your data to third parties.',
            },
            {
              title: 'Data Security',
              content: 'All data is encrypted in transit using TLS. Identity documents are stored securely with access restricted to authorized personnel only. We conduct periodic security reviews.',
            },
            {
              title: 'Your Rights',
              content: 'You have the right to access, correct, or delete your personal data at any time. To exercise any of these rights, contact us at jenishaonlineservice@gmail.com or call +91 80977 74408.',
            },
          ].map((item) => (
            <div key={item.title} className="p-8">
              <h2 className="text-base font-semibold text-slate-900 mb-2">{item.title}</h2>
              <p className="text-sm leading-7 text-slate-600">{item.content}</p>
            </div>
          ))}
        </div>

        {/* Footer */}
        <div className="rounded-3xl bg-white border border-slate-200 p-8 text-center space-y-2">
          <p className="text-sm text-slate-500">
            <strong>Jenisha Online Service</strong> · jenishaonlineservice@gmail.com · +91 80977 74408
          </p>
          <p className="text-xs text-slate-400">Last updated: May 2026</p>
        </div>

      </div>
    </div>
  );
}
