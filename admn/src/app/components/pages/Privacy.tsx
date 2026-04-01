import { useNavigate } from 'react-router-dom';

const privacyDetails = [
  {
    title: 'Data Collection',
    content:
      'We collect only the data required to operate the admin panel, including account identifiers, audit logs, and operational records used to support secure portal workflows.',
  },
  {
    title: 'Data Usage',
    content:
      'Collected data is used for authentication, access control, service delivery, fraud prevention, and operational monitoring. Data is not used for unrelated personal profiling.',
  },
  {
    title: 'Data Protection',
    content:
      'Administrative and operational data is protected through role-based access controls, secure storage, transport encryption, and periodic access reviews across connected systems.',
  },
  {
    title: 'User Rights',
    content:
      'Users may request access, correction, or review of their relevant account data through authorized support channels, subject to legal and compliance obligations.',
  },
];

export default function Privacy() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-4xl">
        <div className="space-y-8">
          <div className="bg-white border border-slate-200 shadow-lg rounded-3xl overflow-hidden">
            <div className="p-10 sm:p-14 text-center">
              <h1 className="text-3xl sm:text-4xl font-semibold text-slate-900 mb-4">
                Privacy Policy
              </h1>
              <p className="mx-auto max-w-2xl text-sm leading-7 text-slate-600">
                This Privacy Policy explains how portal data is collected, used, protected, and managed for authorized users and administrators.
              </p>
            </div>

            <div className="divide-y divide-slate-200">
              {privacyDetails.map((item) => (
                <div key={item.title} className="p-8 sm:p-10">
                  <h2 className="text-xl font-semibold text-slate-900 mb-3">{item.title}</h2>
                  <p className="text-sm leading-7 text-slate-600">{item.content}</p>
                </div>
              ))}
            </div>

            <div className="bg-slate-50 border-t border-slate-200 p-8 sm:p-10">
              <h2 className="text-lg font-semibold text-slate-900 mb-4">Privacy Highlights</h2>
              <ul className="grid gap-3 text-sm leading-7 text-slate-700 sm:grid-cols-2">
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Data is limited to operational requirements.</span>
                </li>
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Access is restricted by role permissions.</span>
                </li>
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Sensitive records are protected in transit and at rest.</span>
                </li>
                <li className="flex gap-3">
                  <span className="mt-1 inline-flex h-2.5 w-2.5 rounded-full bg-[#4C4CFF]" />
                  <span>Users can request data review through support channels.</span>
                </li>
              </ul>
            </div>
          </div>

          <div className="flex flex-col gap-4 rounded-3xl bg-white border border-slate-200 p-8 sm:flex-row sm:items-center sm:justify-between">
            <p className="text-sm text-slate-500">
              For privacy-related requests, contact the system administrator.
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
