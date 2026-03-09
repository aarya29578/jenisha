import { useState, useEffect } from 'react';
import { Users, UserCheck, UserX, AlertCircle, FileText, Wallet } from 'lucide-react';
import { dashboardService, DashboardStats } from '@/services/firebaseService';
import {
  getFirestore,
  collection,
  query,
  orderBy,
  limit,
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

interface RecentAgent {
  id: string;
  name: string;
  mobile: string;
  date: string;
  status: string;
}

interface RecentDocument {
  id: string;
  agent: string;
  service: string;
  customer: string;
  date: string;
}

const initialStats: DashboardStats = {
  totalAgents: 0,
  pendingApprovals: 0,
  activeAgents: 0,
  blockedAgents: 0,
  documentsPending: 0,
  totalWalletBalance: 0,
};

const formatDate = (timestamp: Timestamp | null | undefined) => {
  if (!timestamp) return '—';
  const date = timestamp.toDate();
  return date.toLocaleDateString('en-IN', { 
    year: 'numeric', 
    month: '2-digit', 
    day: '2-digit' 
  });
};

const formatDateTime = (timestamp: Timestamp | null | undefined) => {
  if (!timestamp) return '—';
  const date = timestamp.toDate();
  return date.toLocaleString('en-IN', { 
    year: 'numeric', 
    month: '2-digit', 
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
};

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats>(initialStats);
  const [recentAgents, setRecentAgents] = useState<RecentAgent[]>([]);
  const [recentDocuments, setRecentDocuments] = useState<RecentDocument[]>([]);

  useEffect(() => {
    // Subscribe to dashboard stats
    const unsubscribe = dashboardService.subscribeToDashboard(
      (s) => setStats(s),
      (err) => console.error('Dashboard subscription error', err)
    );

    // Subscribe to recent agent registrations (last 5)
    const agentsQuery = query(
      collection(db, 'users'),
      orderBy('createdAt', 'desc'),
      limit(5)
    );
    
    const unsubscribeAgents = onSnapshot(agentsQuery, (snapshot) => {
      const agents: RecentAgent[] = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.fullName || data.name || 'Unknown',
          mobile: data.phone || 'N/A',
          date: formatDate(data.createdAt),
          status: data.status === 'approved' ? 'Approved' : 
                  data.status === 'rejected' ? 'Rejected' : 'Pending',
        };
      });
      setRecentAgents(agents);
    });

    // Subscribe to recent service applications (last 4)
    const docsQuery = query(
      collection(db, 'serviceApplications'),
      orderBy('createdAt', 'desc'),
      limit(4)
    );
    
    const unsubscribeDocs = onSnapshot(docsQuery, (snapshot) => {
      const docs: RecentDocument[] = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          agent: data.userName || 'Unknown Agent',
          service: data.serviceName || data.serviceId || 'Unknown Service',
          customer: data.fullName || 'Unknown Customer',
          date: formatDateTime(data.createdAt),
        };
      });
      setRecentDocuments(docs);
    });

    return () => {
      unsubscribe();
      unsubscribeAgents();
      unsubscribeDocs();
    };
  }, []);

  const displayStats = [
    { icon: Users, label: 'Total Agents', value: stats.totalAgents.toLocaleString(), color: '#4C4CFF', bgColor: '#E8E8FF' },
    { icon: AlertCircle, label: 'Pending Approvals', value: stats.pendingApprovals.toLocaleString(), color: '#FF9800', bgColor: '#FFF4E6' },
    { icon: UserCheck, label: 'Active Agents', value: stats.activeAgents.toLocaleString(), color: '#4CAF50', bgColor: '#E8F5E9' },
    { icon: UserX, label: 'Blocked Agents', value: stats.blockedAgents.toLocaleString(), color: '#F44336', bgColor: '#FFEBEE' },
    { icon: FileText, label: 'Documents Pending', value: stats.documentsPending.toLocaleString(), color: '#9C27B0', bgColor: '#F3E5F5' },
    { icon: Wallet, label: 'Total Wallet Balance', value: `₹${stats.totalWalletBalance.toLocaleString()}`, color: '#00BCD4', bgColor: '#E0F7FA' },
  ];

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl text-gray-100 mb-2">Dashboard</h1>
        <p className="text-gray-400">Overview of agent management system</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {displayStats.map((stat) => {
          const Icon = stat.icon;
          return (
            <div
              key={stat.label}
              className="rounded-lg p-5 shadow-md text-white flex items-start justify-between"
              style={{ backgroundColor: stat.color }}
            >
              <div className="flex-1 pr-4">
                <p className="text-sm text-white/90 mb-2">{stat.label}</p>
                <p className="text-2xl font-semibold">{stat.value}</p>
              </div>
              <div className="w-12 h-12 rounded flex items-center justify-center bg-white/10">
                <Icon className="w-6 h-6 text-white" />
              </div>
            </div>
          );
        })}
      </div>

      {/* Recent Activity Section */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Agent Registrations */}
        <div className="bg-[#071018] border border-[#111318] rounded">
          <div className="px-5 py-4 border-b border-[#111318]">
            <h2 className="text-lg text-gray-100">Recent Agent Registrations</h2>
          </div>
          <div className="divide-y divide-[#0f1518]">
            {recentAgents.length === 0 ? (
              <div className="px-5 py-8 text-center text-sm text-gray-400">
                No recent agent registrations
              </div>
            ) : (
              recentAgents.map((agent) => (
                <div key={agent.id} className="px-5 py-4 hover:bg-[#071318] transition-colors">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-sm text-gray-100">{agent.name}</h3>
                    <span 
                      className={`
                        px-2 py-1 text-xs rounded font-medium
                        ${agent.status === 'Pending' 
                          ? 'bg-[#FF9800] text-white' 
                          : agent.status === 'Approved'
                          ? 'bg-[#4CAF50] text-white'
                          : 'bg-[#F44336] text-white'
                        }
                      `}
                    >
                      {agent.status}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-xs text-gray-400">
                    <span>{agent.mobile}</span>
                    <span>{agent.date}</span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Recent Document Submissions */}
        <div className="bg-[#071018] border border-[#111318] rounded">
          <div className="px-5 py-4 border-b border-[#111318]">
            <h2 className="text-lg text-gray-100">Recent Document Submissions</h2>
          </div>
          <div className="divide-y divide-[#0f1518]">
            {recentDocuments.length === 0 ? (
              <div className="px-5 py-8 text-center text-sm text-gray-400">
                No recent document submissions
              </div>
            ) : (
              recentDocuments.map((doc) => (
                <div key={doc.id} className="px-5 py-4 hover:bg-[#071318] transition-colors">
                  <div className="mb-2">
                    <h3 className="text-sm text-gray-100 mb-1">{doc.service}</h3>
                    <p className="text-xs text-gray-400">
                      Agent: {doc.agent} • Customer: {doc.customer}
                    </p>
                  </div>
                  <p className="text-xs text-gray-500">{doc.date}</p>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* System Notice */}
      <div className="bg-[#071018] border border-[#111318] rounded p-5">
        <div className="flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-[#243BFF] flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-sm text-gray-100 mb-1">System Notice</h3>
            <p className="text-sm text-gray-400">
              Agent verification timeline: 24-48 hours. All new registrations require KYC document verification before approval.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
