import { useParams, Link } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { ArrowLeft, User, Phone, MapPin, Store, CreditCard, Users as UsersIcon, Wallet, Check, X, Ban } from 'lucide-react';
import {
  getFirestore,
  doc,
  getDoc,
  Timestamp,
} from 'firebase/firestore';
import { initializeApp, getApps } from 'firebase/app';
import { userApprovalService } from '@/services/firebaseService';
import { authService } from '@/services/authService';

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

interface AgentData {
  id: string;
  name: string;
  mobile: string;
  email: string;
  shopName: string;
  address: string;
  regDate: string;
  status: string;
  aadhaar: string;
  pan: string;
  walletBalance: number;
  referralCode: string;
  totalReferrals: number;
  referralEarnings: number;
  aadharUrl?: string;
  panUrl?: string;
}

const formatDate = (timestamp: Timestamp | null | undefined) => {
  if (!timestamp) return '—';
  return timestamp.toDate().toLocaleDateString('en-IN');
};

export default function AgentDetail() {
  const { id } = useParams();
  const [agent, setAgent] = useState<AgentData | null>(null);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<'approve' | 'reject' | 'block' | null>(null);
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [toast, setToast] = useState<{ message: string; type: 'success' | 'error' } | null>(null);

  const adminEmail = authService.getCurrentUser()?.email || 'admin';

  const showToast = (message: string, type: 'success' | 'error') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3000);
  };

  useEffect(() => {
    const fetchAgentData = async () => {
      if (!id) return;
      try {
        const userDoc = await getDoc(doc(db, 'users', id));
        if (userDoc.exists()) {
          const data = userDoc.data();
          const address = data.address || {};
          const documents = data.documents || {};
          setAgent({
            id: userDoc.id,
            name: data.fullName || data.name || 'N/A',
            mobile: data.phone || 'N/A',
            email: data.email || 'N/A',
            shopName: data.shopName || 'N/A',
            address: address.line1
              ? `${address.line1}, ${address.city || ''}, ${address.state || ''} - ${address.pincode || ''}`
              : 'N/A',
            regDate: formatDate(data.createdAt),
            status: data.status === 'approved' ? 'Approved'
                  : data.status === 'rejected' ? 'Rejected'
                  : data.status === 'blocked' ? 'Blocked'
                  : 'Pending',
            aadhaar: documents.aadhar ? 'XXXX-XXXX-' + documents.aadhar.slice(-4) : 'Not provided',
            pan: documents.pan || 'Not provided',
            aadharUrl: documents.aadhar,
            panUrl: documents.pan,
            walletBalance: typeof data.walletBalance === 'number' ? data.walletBalance : 0,
            referralCode: data.referralCode || 'N/A',
            totalReferrals: data.totalReferrals || 0,
            referralEarnings: data.referralEarnings || 0,
          });
        }
        setLoading(false);
      } catch (error) {
        console.error('Error fetching agent data:', error);
        setLoading(false);
      }
    };
    fetchAgentData();
  }, [id]);

  const handleApprove = async () => {
    if (!agent) return;
    setActionLoading('approve');
    try {
      await userApprovalService.approveUser(agent.id, adminEmail);
      setAgent((prev) => prev ? { ...prev, status: 'Approved' } : prev);
      showToast('Agent approved successfully', 'success');
    } catch {
      showToast('Failed to approve agent. Please try again.', 'error');
    } finally {
      setActionLoading(null);
    }
  };

  const handleReject = async () => {
    if (!agent || !rejectReason.trim()) return;
    setActionLoading('reject');
    try {
      await userApprovalService.rejectUser(agent.id, adminEmail, rejectReason.trim());
      setAgent((prev) => prev ? { ...prev, status: 'Rejected' } : prev);
      setShowRejectModal(false);
      setRejectReason('');
      showToast('Agent rejected', 'success');
    } catch {
      showToast('Failed to reject agent. Please try again.', 'error');
    } finally {
      setActionLoading(null);
    }
  };

  const handleBlock = async () => {
    if (!agent) return;
    setActionLoading('block');
    try {
      if (agent.status === 'Blocked') {
        await userApprovalService.unblockUser(agent.id, adminEmail);
        setAgent((prev) => prev ? { ...prev, status: 'Approved' } : prev);
        showToast('Agent unblocked successfully', 'success');
      } else {
        await userApprovalService.blockUser(agent.id, adminEmail);
        setAgent((prev) => prev ? { ...prev, status: 'Blocked' } : prev);
        showToast('Agent blocked', 'success');
      }
    } catch {
      showToast('Failed to update agent status. Please try again.', 'error');
    } finally {
      setActionLoading(null);
    }
  };

  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'Approved': return 'bg-[#08310b] text-green-300';
      case 'Rejected': return 'bg-[#2a0b0b] text-red-300';
      case 'Blocked':  return 'bg-[#1a1a1a] text-gray-400';
      default:         return 'bg-[#1a2a00] text-yellow-300';
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">Loading agent details...</div>
      </div>
    );
  }

  if (!agent) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-[#666666]">Agent not found</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Toast */}
      {toast && (
        <div className={`fixed top-20 right-6 z-50 px-5 py-3 rounded shadow-lg text-sm text-white transition-all ${
          toast.type === 'success' ? 'bg-green-600' : 'bg-red-600'
        }`}>
          {toast.message}
        </div>
      )}

      {/* Reject Reason Modal */}
      {showRejectModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
          <div className="bg-[#0d1320] border border-[#1a2030] rounded-xl p-6 w-full max-w-sm shadow-xl">
            <h3 className="text-base font-semibold text-gray-100 mb-2">Reject Agent</h3>
            <p className="text-xs text-gray-400 mb-4">Provide a reason for rejection. This will be visible to the agent.</p>
            <textarea
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              placeholder="e.g. Documents are unclear, please resubmit..."
              rows={3}
              className="w-full bg-[#071018] border border-[#1a2030] rounded px-3 py-2 text-sm text-gray-100 placeholder-gray-600 focus:outline-none focus:border-[#F44336] resize-none"
            />
            <div className="flex gap-3 mt-4">
              <button
                onClick={() => { setShowRejectModal(false); setRejectReason(''); }}
                disabled={actionLoading === 'reject'}
                className="flex-1 px-4 py-2 rounded border border-[#1a2030] text-gray-300 hover:bg-[#111827] transition-colors text-sm"
              >
                Cancel
              </button>
              <button
                onClick={handleReject}
                disabled={!rejectReason.trim() || actionLoading === 'reject'}
                className="flex-1 px-4 py-2 rounded bg-[#F44336] hover:bg-[#d32f2f] text-white text-sm font-medium transition-colors disabled:opacity-50"
              >
                {actionLoading === 'reject' ? 'Rejecting...' : 'Confirm Reject'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Back Button */}
      <Link
        to="/agents"
        className="inline-flex items-center gap-2 text-[#243BFF] hover:text-[#1f33d6] transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        <span className="text-sm">Back to Agent Management</span>
      </Link>

      {/* Page Header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl text-gray-100 mb-2">{agent.name}</h1>
          <p className="text-gray-400">Agent ID: #{agent.id}</p>
        </div>
        <span className={`px-4 py-2 rounded text-sm ${getStatusBadgeClass(agent.status)}`}>
          {agent.status}
        </span>
      </div>

      {/* Action Buttons */}
      <div className="flex gap-3 flex-wrap">
        <button
          onClick={handleApprove}
          disabled={agent.status === 'Approved' || actionLoading !== null}
          className="flex items-center gap-2 px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Check className="w-4 h-4" />
          <span className="text-sm">{actionLoading === 'approve' ? 'Approving...' : 'Approve Agent'}</span>
        </button>
        <button
          onClick={() => setShowRejectModal(true)}
          disabled={agent.status === 'Rejected' || actionLoading !== null}
          className="flex items-center gap-2 px-4 py-2 bg-[#F44336] text-white rounded hover:bg-[#d32f2f] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <X className="w-4 h-4" />
          <span className="text-sm">Reject Agent</span>
        </button>
        <button
          onClick={handleBlock}
          disabled={actionLoading !== null}
          className="flex items-center gap-2 px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <Ban className="w-4 h-4" />
          <span className="text-sm">
            {actionLoading === 'block' ? 'Updating...' : agent.status === 'Blocked' ? 'Unblock Agent' : 'Block Agent'}
          </span>
        </button>
      </div>

      {/* Details Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Personal Details */}
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318]">Personal Details</h2>
          <div className="space-y-4">
            <div className="flex items-start gap-3">
              <User className="w-5 h-5 text-gray-400 mt-0.5" />
              <div>
                <p className="text-xs text-gray-400 mb-1">Full Name</p>
                <p className="text-sm text-gray-100">{agent.name}</p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <Phone className="w-5 h-5 text-gray-400 mt-0.5" />
              <div>
                <p className="text-xs text-gray-400 mb-1">Mobile Number</p>
                <p className="text-sm text-gray-100">{agent.mobile}</p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <MapPin className="w-5 h-5 text-gray-400 mt-0.5" />
              <div>
                <p className="text-xs text-gray-400 mb-1">Address</p>
                <p className="text-sm text-gray-100">{agent.address}</p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <Store className="w-5 h-5 text-gray-400 mt-0.5" />
              <div>
                <p className="text-xs text-gray-400 mb-1">Shop Name</p>
                <p className="text-sm text-gray-100">{agent.shopName}</p>
              </div>
            </div>
          </div>
        </div>

        {/* KYC Documents */}
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318]">KYC Documents</h2>
          <div className="space-y-4">
            <div className="border border-[#111318] rounded p-4 bg-[#071018]">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-100">Aadhaar Card</p>
                <span className={`px-2 py-1 rounded text-xs ${agent.aadharUrl ? 'bg-[#08310b] text-white' : 'bg-[#0f1518] text-gray-400'}`}>
                  {agent.aadharUrl ? 'Verified' : 'Pending'}
                </span>
              </div>
              <p className="text-xs text-gray-400">{agent.aadhaar}</p>
              {agent.aadharUrl && (
                <a href={agent.aadharUrl} target="_blank" rel="noopener noreferrer" className="mt-2 inline-block text-xs text-[#243BFF] hover:underline">
                  View Document
                </a>
              )}
            </div>
            <div className="border border-[#111318] rounded p-4 bg-[#071018]">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-100">PAN Card</p>
                <span className={`px-2 py-1 rounded text-xs ${agent.panUrl ? 'bg-[#08310b] text-white' : 'bg-[#0f1518] text-gray-400'}`}>
                  {agent.panUrl ? 'Verified' : 'Pending'}
                </span>
              </div>
              <p className="text-xs text-gray-400">{agent.pan}</p>
              {agent.panUrl && (
                <a href={agent.panUrl} target="_blank" rel="noopener noreferrer" className="mt-2 inline-block text-xs text-[#243BFF] hover:underline">
                  View Document
                </a>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Wallet & Referral Info */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318] flex items-center gap-2">
            <Wallet className="w-5 h-5 text-gray-100" />
            Wallet Information
          </h2>
          <div className="mb-4">
            <p className="text-sm text-gray-400 mb-2">Current Balance</p>
            <p className="text-3xl text-gray-100">₹{agent.walletBalance.toLocaleString()}</p>
          </div>
          <button className="w-full px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors">
            Recharge Wallet
          </button>
          <div className="mt-4 pt-4 border-t border-[#111318]">
            <h3 className="text-sm text-gray-100 mb-3">Recent Transactions</h3>
            <div className="text-center text-xs text-gray-400 py-4">Transaction history coming soon</div>
          </div>
        </div>

        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318] flex items-center gap-2">
            <UsersIcon className="w-5 h-5 text-gray-100" />
            Referral Statistics
          </h2>
          <div className="space-y-4">
            <div>
              <p className="text-sm text-gray-400 mb-2">Referral Code</p>
              <div className="flex items-center gap-2">
                <code className="px-3 py-2 bg-[#0f1518] rounded text-gray-100 text-sm">{agent.referralCode}</code>
                <button
                  onClick={() => navigator.clipboard.writeText(agent.referralCode)}
                  className="px-3 py-2 border border-[#111318] rounded text-xs text-gray-400 hover:bg-[#0f1518] transition-colors"
                >
                  Copy
                </button>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="p-3 bg-[#0f1518] rounded">
                <p className="text-xs text-gray-400 mb-1">Total Referrals</p>
                <p className="text-2xl text-gray-100">{agent.totalReferrals}</p>
              </div>
              <div className="p-3 bg-[#0f1518] rounded">
                <p className="text-xs text-gray-400 mb-1">Earnings</p>
                <p className="text-2xl text-gray-100">₹{agent.referralEarnings}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
