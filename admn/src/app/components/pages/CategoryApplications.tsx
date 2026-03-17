import { useState, useEffect } from 'react';
import { ArrowLeft, FileText, Loader } from 'lucide-react';
import {
  getFirestore,
  collection,
  query,
  where,
  getDocs,
  onSnapshot,
} from 'firebase/firestore';
import { initializeApp, getApps } from 'firebase/app';
import ServiceApplications from './ServiceApplications';

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

interface ServiceRow {
  id: string;
  name: string;
  applicationCount: number;
  pendingCount: number;
}

interface Props {
  categoryId: string;
  categoryName: string;
  onBack: () => void;
}

export default function CategoryApplications({ categoryId, categoryName, onBack }: Props) {
  const [services, setServices] = useState<ServiceRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedService, setSelectedService] = useState<{ id: string; name: string } | null>(null);

  useEffect(() => {
    setLoading(true);

    // 1. Fetch services for this category once
    let serviceMap: Record<string, string> = {}; // id → name

    getDocs(query(collection(db, 'services'), where('categoryId', '==', categoryId)))
      .then((snap) => {
        snap.forEach((d) => {
          serviceMap[d.id] = (d.data().name as string) || d.id;
        });

        if (Object.keys(serviceMap).length === 0) {
          setServices([]);
          setLoading(false);
          return;
        }

        // 2. Live-listen to ALL applications, group by serviceId in memory
        const unsubscribe = onSnapshot(
          collection(db, 'serviceApplications'),
          (appSnap) => {
            const total: Record<string, number> = {};
            const pending: Record<string, number> = {};

            appSnap.forEach((d) => {
              const sid: string = d.data().serviceId || '';
              if (!serviceMap[sid]) return;
              total[sid] = (total[sid] ?? 0) + 1;
              if (d.data().status === 'pending') {
                pending[sid] = (pending[sid] ?? 0) + 1;
              }
            });

            const rows: ServiceRow[] = Object.keys(serviceMap).map((id) => ({
              id,
              name: serviceMap[id],
              applicationCount: total[id] ?? 0,
              pendingCount: pending[id] ?? 0,
            }));

            rows.sort((a, b) =>
              b.applicationCount !== a.applicationCount
                ? b.applicationCount - a.applicationCount
                : a.name.localeCompare(b.name)
            );

            setServices(rows);
            setLoading(false);
          },
          (err) => {
            console.error('Error subscribing to applications:', err);
            setLoading(false);
          }
        );

        return unsubscribe;
      })
      .catch((e) => {
        console.error('Error fetching services:', e);
        setLoading(false);
      });
  }, [categoryId]);

  // ── Navigate into service ─────────────────────────────────────────────────
  if (selectedService) {
    return (
      <ServiceApplications
        serviceId={selectedService.id}
        serviceName={selectedService.name}
        categoryName={categoryName}
        onBack={() => setSelectedService(null)}
      />
    );
  }

  // ── Service list ──────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button
          onClick={onBack}
          className="p-2 text-gray-400 hover:text-gray-100 hover:bg-[#0f1518] rounded transition-colors"
          title="Back to dashboard"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-2xl text-gray-100">{categoryName}</h1>
          <p className="text-sm text-gray-400">Select a service to view applications</p>
        </div>
      </div>

      {/* Content */}
      {loading ? (
        <div className="flex items-center justify-center py-16">
          <Loader className="w-6 h-6 text-[#4C4CFF] animate-spin" />
        </div>
      ) : services.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <FileText className="w-10 h-10 mx-auto mb-3 text-gray-600" />
          <p>No services found under this category.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {services.map((svc) => (
            <button
              key={svc.id}
              onClick={() => setSelectedService({ id: svc.id, name: svc.name })}
              className="bg-[#071018] border border-[#111318] rounded-lg p-5 text-left hover:border-[#243BFF] hover:bg-[#0a1525] transition-colors group"
            >
              <div className="flex items-start justify-between mb-3">
                <div className="w-10 h-10 rounded bg-[#E8E8FF] flex items-center justify-center flex-shrink-0">
                  <FileText className="w-5 h-5 text-[#4C4CFF]" />
                </div>
                {svc.pendingCount > 0 && (
                  <span className="px-2 py-0.5 text-xs rounded bg-[#FFF4E6] text-[#FF9800]">
                    {svc.pendingCount} pending
                  </span>
                )}
              </div>
              <p className="text-sm text-gray-100 font-medium mb-1 group-hover:text-white">
                {svc.name}
              </p>
              <p className="text-2xl font-semibold text-white">
                {svc.applicationCount.toLocaleString()}
              </p>
              <p className="text-xs text-gray-400 mt-1">total applications</p>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
