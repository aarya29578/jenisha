import { useNavigate } from 'react-router-dom';

const termsSections = [
  {
    title: 'Introduction',
    content:
      'This admin portal is intended for authorized personnel only. The system is secured for official operations and must be used responsibly.',
  },
  {
    title: 'User Responsibilities',
    content:
      'Users must access the system only with authorized credentials, follow approved workflows, and report any suspicious activity immediately.',
  },
  {
    title: 'Security & Monitoring',
    content:
      'All system activity may be monitored and logged to maintain security, protect data, and ensure policy compliance.',
  },
  {
    title: 'Data Usage Policy',
    content:
      'Data accessed through this portal is confidential. Only use information for official purposes and do not share credentials or sensitive records.',
  },
  {
    title: 'Consequences of Misuse',
    content:
      'Unauthorized access, data misuse, or policy violations will result in strict action in accordance with organizational rules.',
  },
];

export default function Terms() {
  const navigate = useNavigate();
  const termsVersion = 'v1';

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-3xl">
        <div className="bg-white border border-slate-200 shadow-lg rounded-2xl overflow-hidden">
          <div className="p-8 sm:p-12">
            <div className="text-center mb-8">
              <p className="text-sm font-semibold uppercase tracking-[0.28em] text-[#4C4CFF] mb-3">
                Admin Portal Usage Policy
              </p>
              <h1 className="text-3xl sm:text-4xl font-semibold text-slate-900">
                Terms & Conditions
              </h1>
              <p className="mt-4 text-sm text-slate-500">
                Version {termsVersion} · Public access page for secure admin portal usage.
              </p>
            </div>

            <div className="space-y-8">
              {termsSections.map((section) => (
                <div key={section.title} className="space-y-3">
                  <h2 className="text-lg font-semibold text-slate-900">{section.title}</h2>
                  <p className="text-sm leading-7 text-slate-600">{section.content}</p>
                </div>
              ))}

              <div className="bg-slate-50 border border-slate-200 rounded-2xl p-6">
                <h3 className="text-base font-semibold text-slate-900 mb-4">Key Compliance Points</h3>
                <ul className="space-y-3 text-sm leading-7 text-slate-700">
                  <li className="flex gap-3">
                    <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                    <span>Unauthorized access is strictly prohibited.</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                    <span>All activities may be monitored and logged.</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                    <span>Only authorized credentials must be used.</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                    <span>Data misuse will result in strict action.</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                    <span>System is intended for official use only.</span>
                  </li>
                </ul>
              </div>
            </div>

            <div className="mt-10 border-t border-slate-200 pt-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <p className="text-sm text-slate-500">
                For any queries, contact the system administrator.
              </p>
              <button
                type="button"
                onClick={() => navigate('/login')}
                className="inline-flex items-center justify-center rounded-xl bg-[#4C4CFF] px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-[#3b48e1]"
              >
                Back to Login
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
