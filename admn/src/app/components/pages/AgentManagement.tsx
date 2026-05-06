import { useState, useEffect } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { Search, Eye, UserCheck, UserX, Ban, Trash2, Copy, Check } from 'lucide-react';
import { pendingUsersService, UserData, userApprovalService } from '@/services/firebaseService';

export default function AgentManagement() {
  const [allUsers, setAllUsers] = useState<UserData[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchParams, setSearchParams] = useSearchParams();
  const [filterStatus, setFilterStatus] = useState(() => searchParams.get('status') ?? 'All');
  const [loading, setLoading] = useState(true);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [deleteConfirmName, setDeleteConfirmName] = useState('');
  const [deleting, setDeleting] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const copyUid = (uid: string) => {
    navigator.clipboard.writeText(uid);
    setCopiedId(uid);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleDeleteAgent = async () => {
    if (!deleteConfirmId) return;
    setDeleting(true);
    try {
      await userApprovalService.deleteAgent(deleteConfirmId);
      setDeleteConfirmId(null);
    } catch (err) {
      console.error('Delete failed:', err);
    } finally {
      setDeleting(false);
    }
  };

  useEffect(() => {
    setLoading(true);
    // Subscribe to all users in real-time
    const unsubscribe = pendingUsersService.subscribeToAllUsers(
      (users) => {
        setAllUsers(users);
        setLoading(false);
      },
      (err) => {
        console.error('Failed to load agents:', err);
        setLoading(false);
      }
    );

    // Cleanup subscription on unmount
    return () => unsubscribe();
  }, []);

  // Convert Firestore status to display status
  const getDisplayStatus = (status: string): string => {
    const statusMap: { [key: string]: string } = {
      'approved': 'Approved',
      'pending': 'Pending',
      'rejected': 'Rejected',
      'blocked': 'Blocked',
      'incomplete': 'Incomplete',
    };
    return statusMap[status] || status;
  };

  // Short readable UID: first 8 chars uppercase, e.g. "USR-FQJ3XA1M"
  const shortUid = (uid: string) => `USR-${uid.slice(0, 8).toUpperCase()}`;

  const filteredAgents = allUsers
    .map((user) => ({
      id: user.uid,
      name: user.fullName || '',
      mobile: user.phone || '',
      regDate: user.createdAt ? user.createdAt.toDate().toLocaleDateString('en-IN') : 'N/A',
      status: getDisplayStatus(user.status),
      wallet: 0,
      uid: user.uid,
      firestoreStatus: user.status,
      customId: user.customId || null,
      authMethod: user.authMethod || null,
      email: user.email || '',
    }))
    .filter(agent => {
      const matchesSearch = agent.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                           agent.mobile.includes(searchTerm);
      const matchesStatus = filterStatus === 'All' || agent.status === filterStatus;
      return matchesSearch && matchesStatus;
    });

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Approved':
        return 'bg-[#E8F5E9] text-[#4CAF50]';
      case 'Pending':
        return 'bg-[#FFF4E6] text-[#FF9800]';
      case 'Rejected':
        return 'bg-[#FFEBEE] text-[#F44336]';
      case 'Blocked':
        return 'bg-[#F5F5F5] text-[#666666]';
      case 'Incomplete':
        return 'bg-[#EEF0FF] text-[#6B7AFF]';
      default:
        return 'bg-[#F5F5F5] text-[#888888]';
    }
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
          <h1 className="text-2xl text-gray-100 mb-2">Agent Management</h1>
          <p className="text-gray-400">Manage all registered agents</p>
      </div>

      {loading ? (
          <div className="bg-[#071018] border border-[#111318] rounded p-8 text-center text-gray-400">
          Loading agents...
        </div>
      ) : (
        <>
          {/* Filters and Search */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-4">
        <div className="flex flex-col md:flex-row gap-4">
          {/* Search */}
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-[#666666]" />
            <input
              type="text"
              placeholder="Search by name or mobile number..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-11 pr-4 py-2 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
            />
          </div>

          {/* Status Filter */}
          <div className="flex gap-2">
            {['All', 'Approved', 'Pending', 'Rejected', 'Blocked'].map((status) => (
              <button
                key={status}
                onClick={() => {
                  setFilterStatus(status);
                  if (status === 'All') {
                    setSearchParams({});
                  } else {
                    setSearchParams({ status });
                  }
                }}
                className={`
                  px-4 py-2 rounded text-sm transition-colors
                  ${filterStatus === status
                    ? 'bg-[#4C4CFF] text-white'
                    : 'bg-[#f5f5f5] text-[#666666] hover:bg-[#e5e5e5]'
                  }
                `}
              >
                {status}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Agents Table */}
        <div className="bg-[#071018] border border-[#111318] rounded overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
              <thead className="bg-[#0f1518] border-b border-[#111318]">
              <tr>
                  <th className="px-5 py-3 text-left text-sm text-gray-100">Agent Name</th>
                  <th className="px-5 py-3 text-left text-sm text-gray-100">User ID</th>
                  <th className="px-5 py-3 text-left text-sm text-gray-100">Login Credential</th>
                  <th className="px-5 py-3 text-left text-sm text-gray-100">Registration Date</th>
                  <th className="px-5 py-3 text-left text-sm text-gray-100">Status</th>
                  <th className="px-5 py-3 text-left text-sm text-gray-100">Wallet Balance</th>
                  <th className="px-5 py-3 text-left text-sm text-gray-100">Actions</th>
              </tr>
            </thead>
              <tbody className="divide-y divide-[#0f1518]">
              {filteredAgents.map((agent) => (
                  <tr key={agent.id} className="hover:bg-[#071318] transition-colors">
                    <td className="px-5 py-4 text-sm text-gray-100">
                      {agent.name || <span className="text-gray-500 italic">Not registered</span>}
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-[#6B7AFF] font-mono bg-[#0d1230] px-2 py-0.5 rounded" title={agent.uid}>
                          {shortUid(agent.uid)}
                        </span>
                        <button
                          onClick={() => copyUid(agent.uid)}
                          className="p-1 text-gray-500 hover:text-[#243BFF] rounded transition-colors flex-shrink-0"
                          title="Copy full User ID"
                        >
                          {copiedId === agent.uid ? <Check className="w-3.5 h-3.5 text-green-400" /> : <Copy className="w-3.5 h-3.5" />}
                        </button>
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      {agent.authMethod === 'id_password' ? (
                        <div className="space-y-1">
                          <div className="flex items-center gap-1.5">
                            <span className="text-xs bg-[#1E3A5F] text-[#60A5FA] px-1.5 py-0.5 rounded font-medium">ID</span>
                            <span className="text-sm text-gray-100 font-mono">{agent.customId || '—'}</span>
                          </div>
                          <div className="flex items-center gap-1.5">
                            <span className="text-xs bg-[#3B1F1F] text-[#F87171] px-1.5 py-0.5 rounded font-medium">PWD</span>
                            <span className="text-xs text-gray-500 italic">Hidden (Firebase Auth)</span>
                          </div>
                        </div>
                      ) : agent.authMethod === 'google' ? (
                        <div className="flex items-center gap-1.5">
                          <span className="text-xs bg-[#1F3320] text-[#4ADE80] px-1.5 py-0.5 rounded font-medium">Google</span>
                          <span className="text-sm text-gray-400">{agent.email || '—'}</span>
                        </div>
                      ) : (
                        <div className="flex items-center gap-1.5">
                          <span className="text-xs bg-[#2A1F3D] text-[#C084FC] px-1.5 py-0.5 rounded font-medium">OTP</span>
                          <span className="text-sm text-gray-400">{agent.mobile || <span className="text-gray-600">—</span>}</span>
                        </div>
                      )}
                    </td>
                    <td className="px-5 py-4 text-sm text-gray-400">{agent.regDate}</td>
                  <td className="px-5 py-4">
                    <span className={`inline-block px-3 py-1 text-xs rounded ${getStatusColor(agent.status)}`}>
                      {agent.status}
                    </span>
                  </td>
                    <td className="px-5 py-4 text-sm text-gray-100">₹{agent.wallet.toLocaleString()}</td>
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-2">
                        <Link
                          to={`/agents/${agent.id}`}
                          className="p-2 text-[#243BFF] hover:bg-[#0f243b] rounded transition-colors"
                          title="View Details"
                        >
                          <Eye className="w-4 h-4" />
                        </Link>
                      {agent.status === 'Approved' && (
                        <button
                            className="p-2 text-gray-300 hover:bg-[#0f1518] rounded transition-colors"
                          title="Block Agent"
                        >
                          <Ban className="w-4 h-4" />
                        </button>
                      )}
                      {agent.status === 'Blocked' && (
                        <button
                            className="p-2 text-[#4CAF50] hover:bg-[#08310b] rounded transition-colors"
                          title="Unblock Agent"
                        >
                          <UserCheck className="w-4 h-4" />
                        </button>
                      )}
                      {agent.status === 'Pending' && (
                        <button
                            className="p-2 text-[#F44336] hover:bg-[#2a0b0b] rounded transition-colors"
                          title="Reject Agent"
                        >
                          <UserX className="w-4 h-4" />
                        </button>
                      )}
                      <button
                          onClick={() => { setDeleteConfirmId(agent.id); setDeleteConfirmName(agent.name); }}
                          className="p-2 text-red-400 hover:bg-red-900/30 rounded transition-colors"
                          title="Delete Agent"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {filteredAgents.length === 0 && (
            <div className="p-8 text-center text-gray-400">
              No agents found matching your criteria
            </div>
        )}
      </div>
        </>
      )}
      {/* Delete Confirmation Modal */}
      {deleteConfirmId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
          <div className="bg-[#0d1320] border border-[#1a2030] rounded-xl p-6 w-full max-w-sm shadow-xl">
            <div className="flex items-center gap-3 mb-4">
              <div className="w-10 h-10 rounded-full bg-red-500/15 flex items-center justify-center flex-shrink-0">
                <Trash2 className="w-5 h-5 text-red-400" />
              </div>
              <div>
                <h3 className="text-base font-semibold text-gray-100">Delete Agent</h3>
                <p className="text-xs text-gray-400">This action cannot be undone</p>
              </div>
            </div>
            <p className="text-sm text-gray-300 mb-6">
              Are you sure you want to delete <span className="font-semibold text-white">{deleteConfirmName}</span>? Their account and all associated data will be permanently removed.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setDeleteConfirmId(null)}
                disabled={deleting}
                className="flex-1 px-4 py-2 rounded border border-[#1a2030] text-gray-300 hover:bg-[#111827] transition-colors text-sm"
              >
                Cancel
              </button>
              <button
                onClick={handleDeleteAgent}
                disabled={deleting}
                className="flex-1 px-4 py-2 rounded bg-red-600 hover:bg-red-700 text-white text-sm font-medium transition-colors disabled:opacity-60"
              >
                {deleting ? 'Deleting...' : 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
