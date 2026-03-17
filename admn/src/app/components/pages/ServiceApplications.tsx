import { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, X, Filter, Search } from 'lucide-react';
import {
  getFirestore,
  collection,
  query,
  where,
  onSnapshot,
  Timestamp,
} from 'firebase/firestore';
import { initializeApp, getApps } from 'firebase/app';

const firebaseConfig = {
  apiKey: 'AIzaSyC72UmM3pMwRBh0pKjKy_jN9wmpE_MP_GM',
  authDomain: 'jenisha-46c62.firebaseapp.com',
  projectId: 'jenisha-46c62',
  storageBucket: 'jenisha-46c62.appspot.com',
  messagingSenderId: '245020879102',
  appId: '1:245020879102:web:05969fe2820677483c9daf',
};

const firebaseApp = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
const db = getFirestore(firebaseApp);

// ── Types ─────────────────────────────────────────────────────────────────────

interface ServiceApplication {
  id: string;
  userId: string;
  serviceId: string;
  status: string;
  userName?: string;
  serviceName?: string;
  fullName?: string;
  phone?: string;
  email?: string;
  documents?: Record<string, string>;
  fieldData?: Record<string, any>;
  filledFormUrl?: string;
  documentsMeta?: Record<
    string,
    {
      documentName?: string;
      status?: string;
      imageUrl?: string;
      rejectionReason?: string;
    }
  >;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
}


type FilterValue = 'pending' | 'approved' | 'rejected' | 'all';

// ── Helpers ───────────────────────────────────────────────────────────────────

const badgeClasses: Record<string, string> = {
  pending: 'bg-[#FFF4E6] text-[#FF9800]',
  submitted: 'bg-[#E3F2FD] text-[#1E88E5]',
  approved: 'bg-[#E8F5E9] text-[#4CAF50]',
  rejected: 'bg-[#FFEBEE] text-[#F44336]',
  draft: 'bg-[#F3F4F6] text-[#6B7280]',
};

const statusFilters: { label: string; value: FilterValue }[] = [
  { label: 'Pending', value: 'pending' },
  { label: 'Approved', value: 'approved' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'All', value: 'all' },
];

const formatDate = (ts?: Timestamp) => {
  if (!ts) return '—';
  return ts.toDate().toLocaleString();
};


// ── Component ─────────────────────────────────────────────────────────────────

interface Props {
  serviceId: string;
  serviceName: string;
  categoryName: string;
  onBack: () => void;
}

export default function ServiceApplications({ serviceId, serviceName, categoryName, onBack }: Props) {
  const navigate = useNavigate();

  const [allApplications, setAllApplications] = useState<ServiceApplication[]>([]);
  const [loadingApps, setLoadingApps] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [filterStatus, setFilterStatus] = useState<FilterValue>('all');
  const [searchTerm, setSearchTerm] = useState('');

  // ── Subscribe to applications for this service ─────────────────────────────
  useEffect(() => {
    setLoadingApps(true);
    setError(null);

    const unsubscribe = onSnapshot(
      query(
        collection(db, 'serviceApplications'),
        where('serviceId', '==', serviceId)
      ),
      (snapshot) => {
        const records: ServiceApplication[] = snapshot.docs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            userId: data.userId,
            serviceId: data.serviceId,
            status: data.status ?? 'pending',
            userName: data.userName ?? data.fullName,
            fullName: data.fullName,
            phone: data.phone,
            email: data.email,
            serviceName: data.serviceName,
            documents: data.documents ?? {},
            fieldData: data.fieldData ?? {},
            filledFormUrl: data.filledFormUrl ?? '',
            documentsMeta: data.documentsMeta ?? {},
            createdAt: data.createdAt,
            updatedAt: data.updatedAt,
          } as ServiceApplication;
        });
        setAllApplications(
          records.sort((a, b) => {
            const ta = a.createdAt?.toMillis() ?? 0;
            const tb = b.createdAt?.toMillis() ?? 0;
            return tb - ta; // newest first
          })
        );
        setLoadingApps(false);
      },
      (err) => {
        console.error('Error loading applications:', err);
        setError('Unable to load applications. Please try again.');
        setLoadingApps(false);
      }
    );

    return unsubscribe;
  }, [serviceId]);

  // ── Filtered list ──────────────────────────────────────────────────────────
  const applications = useMemo(() => {
    let result = allApplications;
    if (filterStatus !== 'all') result = result.filter((a) => a.status === filterStatus);
    const q = searchTerm.trim().toLowerCase();
    if (q) {
      result = result.filter(
        (a) =>
          a.fullName?.toLowerCase().includes(q) ||
          a.userName?.toLowerCase().includes(q) ||
          a.phone?.includes(searchTerm.trim()) ||
          a.id.toLowerCase().includes(q)
      );
    }
    return result;
  }, [allApplications, filterStatus, searchTerm]);

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      {/* Header / breadcrumb */}
      <div className="flex items-center gap-3">
        <button
          onClick={onBack}
          className="p-2 text-gray-400 hover:text-gray-100 hover:bg-[#0f1518] rounded transition-colors"
          title="Back to services"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div>
          <p className="text-xs text-gray-500">{categoryName}</p>
          <h1 className="text-2xl text-gray-100">{serviceName}</h1>
          <p className="text-sm text-gray-400">
            {allApplications.length} application{allApplications.length !== 1 ? 's' : ''}
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2">
          <Filter className="w-5 h-5 text-gray-400 flex-shrink-0" />
          <div className="flex gap-2">
            {statusFilters.map((f) => (
              <button
                key={f.value}
                onClick={() => setFilterStatus(f.value)}
                className={`px-4 py-2 rounded text-sm transition-colors ${
                  filterStatus === f.value
                    ? 'bg-[#243BFF] text-white shadow-md'
                    : 'bg-[#0f1518] text-gray-400 hover:bg-[#13171a]'
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>
        </div>
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by name, phone, or ID..."
            className="w-full bg-[#0f1518] text-gray-300 text-sm pl-9 pr-8 py-2 rounded border border-[#1a2130] focus:outline-none focus:border-[#243BFF] placeholder-gray-600"
          />
          {searchTerm && (
            <button
              onClick={() => setSearchTerm('')}
              className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>

      {error && (
        <div className="p-4 border border-[#7f1d1d] bg-[#3b0b0b] text-[#fca5a5] rounded">{error}</div>
      )}

      {/* Application list */}
      <div className="bg-[#071018] border border-[#111318] rounded">
        <div className="px-5 py-4 border-b border-[#111318] flex items-center justify-between">
          <h2 className="text-base text-gray-100">Applications</h2>
          {loadingApps && <span className="text-xs text-gray-400">Loading…</span>}
        </div>
        <div className="divide-y divide-[#0f1518]">
          {!loadingApps && applications.length === 0 && (
            <div className="p-6 text-center text-sm text-gray-400">
              No applications found.
            </div>
          )}
          {applications.map((app) => {
            const chipClass = badgeClasses[app.status] ?? badgeClasses.pending;
            const docCount =
              Object.keys(app.documents || {}).length +
              Object.entries(app.fieldData || {}).filter(
                ([, v]) =>
                  typeof v === 'string' &&
                  (v.startsWith('http://') || v.startsWith('https://'))
              ).length;
            return (
              <div
                key={app.id}
                onClick={() => navigate(`/application/${app.id}`)}
                className="p-5 cursor-pointer hover:bg-[#071318] transition-colors flex items-center gap-4"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-3 mb-1">
                    <h3 className="text-sm text-gray-100 truncate">
                      {app.fullName || app.userName || app.userId}
                    </h3>
                    <span className={`px-2 py-0.5 text-xs rounded flex-shrink-0 ${chipClass}`}>
                      {app.status.charAt(0).toUpperCase() + app.status.slice(1)}
                    </span>
                  </div>
                  <div className="flex items-center gap-4 text-xs text-gray-400">
                    {app.phone && <span>{app.phone}</span>}
                    <span>Submitted: {formatDate(app.createdAt)}</span>
                    <span>Docs: {docCount}</span>
                  </div>
                </div>
                <ArrowLeft className="w-4 h-4 text-gray-500 rotate-180 flex-shrink-0" />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
