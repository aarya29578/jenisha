import { useNavigate } from 'react-router-dom';

const termsDetails = [
  {
    title: 'Purpose and Scope',
    content:
      'These terms govern access to the admin panel and connected management tools. They apply to all internal users, administrators, and approved support personnel.',
  },
  {
    title: 'Authorized Access',
    content:
      'Only registered admins, super admins, and assigned support personnel may use this portal. Shared credentials, guest access, and unauthorized accounts are strictly forbidden.',
  },
  {
    title: 'Account Security',
    content:
      'Users must protect credentials, enable MFA if available, and avoid reusing passwords across systems. All logins are audited and suspicious sessions will be terminated immediately.',
  },
  {
    title: 'Role-Based Operations',
    content:
      'Each user role has defined permissions. Users must perform actions only within their assigned role context and avoid attempting privilege escalation or unauthorized workflows.',
  },
  {
    title: 'Usage Restrictions',
    content:
      'Users must not misuse system resources, alter records without authorization, bypass security controls, or run unapproved automation against portal services.',
  },
  {
    title: 'Change Control and Audit',
    content:
      'Any changes to agent records, service settings, or commission structures are logged. Modification history is retained to support compliance reviews and incident response.',
  },
  {
    title: 'Incident Reporting',
    content:
      'If you observe unusual activity, data exposure, or improper access, report it immediately to the security administrator. Delayed reporting may result in greater compliance penalties.',
  },
];

export default function Terms() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-4xl">
        <div className="space-y-8">
          <div className="bg-white border border-slate-200 shadow-lg rounded-3xl overflow-hidden">
            <div className="p-10 sm:p-14 text-center">
              <h1 className="text-3xl sm:text-4xl font-semibold text-slate-900 mb-4">
                Terms & Conditions
              </h1>
              <p className="mx-auto max-w-2xl text-sm leading-7 text-slate-600">
                These Terms define permitted platform usage, user responsibilities, restrictions, and enforcement rules for the admin and agent management ecosystem.
              </p>
            </div>

            <div className="divide-y divide-slate-200">
              {termsDetails.map((item) => (
                <div key={item.title} className="p-8 sm:p-10">
                  <h2 className="text-xl font-semibold text-slate-900 mb-3">{item.title}</h2>
                  <p className="text-sm leading-7 text-slate-600">{item.content}</p>
                </div>
              ))}
            </div>

            <div className="bg-slate-50 border-t border-slate-200 p-8 sm:p-10">
              <h2 className="text-lg font-semibold text-slate-900 mb-4">Core Compliance Requirements</h2>
              <ul className="grid gap-3 text-sm leading-7 text-slate-700 sm:grid-cols-2">
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Unauthorized access is strictly prohibited.</span>
                </li>
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>All actions are audited and may be reviewed.</span>
                </li>
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Only authorized credentials may be used.</span>
                </li>
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Privilege escalation attempts are forbidden.</span>
                </li>
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Misuse will result in suspension or disciplinary action.</span>
                </li>
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Report security incidents immediately.</span>
                </li>
              </ul>
            </div>
          </div>

          <div className="flex flex-col gap-4 rounded-3xl bg-white border border-slate-200 p-8 sm:flex-row sm:items-center sm:justify-between">
            <p className="text-sm text-slate-500">
              For any queries or compliance requests, contact the system administrator.
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
  );
}
