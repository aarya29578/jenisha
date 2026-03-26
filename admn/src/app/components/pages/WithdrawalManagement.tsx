import { useState, useEffect, useMemo } from 'react';
import {
  ArrowDownUp,
  Search,
  X,
  Check,
  Clock,
  AlertCircle,
  XCircle,
  Loader2,
} from 'lucide-react';
import {
  getFirestore,
  collection,
  query,
  orderBy,
  onSnapshot,
  doc,
  updateDoc,
  addDoc,
  increment,
  serverTimestamp,
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

// ── Types ──────────────────────────────────────────────────────────────────────

interface PaymentDetails {
  method: 'upi' | 'bank';
  upiId?: string;
  accountNumber?: string;
  ifscCode?: string;
  holderName?: string;
}

interface WithdrawalRequest {
  id: string;
  userId: string;
  userName: string;
  userPhone: string;
  amount: number;
  paymentMethod: 'upi' | 'bank';
  paymentDetails: PaymentDetails;
  withdrawalStatus: 'pending' | 'processing' | 'approved' | 'rejected';
  createdAt: Timestamp | null;
  updatedAt: Timestamp | null;
  rejectionReason?: string;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

function formatDate(ts: Timestamp | null): string {
  if (!ts) return '—';
  return ts.toDate().toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function StatusBadge({ status }: { status: WithdrawalRequest['withdrawalStatus'] }) {
  const map: Record<string, { bg: string; text: string; label: string }> = {
    pending: { bg: 'bg-[#fff8e1] text-[#ff9800]', text: '', label: 'Pending' },
    processing: { bg: 'bg-[#e3f2fd] text-[#1e88e5]', text: '', label: 'Processing' },
    approved: { bg: 'bg-[#e8f5e9] text-[#4caf50]', text: '', label: 'Approved' },
    rejected: { bg: 'bg-[#ffebee] text-[#f44336]', text: '', label: 'Rejected' },
  };
  const s = map[status] ?? map.pending;
  return (
    <span className={`px-2 py-0.5 rounded text-xs font-medium capitalize ${s.bg}`}>
      {s.label}
    </span>
  );
}

// ── Reject Modal ───────────────────────────────────────────────────────────────

function RejectModal({
  request,
  onClose,
  onConfirm,
}: {
  request: WithdrawalRequest;
  onClose: () => void;
  onConfirm: (reason: string) => Promise<void>;
}) {
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleConfirm = async () => {
    if (!reason.trim()) {
      setError('Please provide a rejection reason.');
      return;
    }
    setLoading(true);
    try {
      await onConfirm(reason.trim());
      onClose();
    } catch {
      setError('Operation failed. Please try again.');
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="bg-[#0a0f1a] border border-[#1a2130] rounded-lg w-full max-w-md p-6 shadow-xl">
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg text-gray-100">Reject Withdrawal</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-gray-300 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="space-y-4 mb-5">
          <div className="bg-[#0f1518] border border-[#1a2130] rounded p-3 text-sm text-gray-400 space-y-1">
            <p><span className="text-gray-500">Agent:</span> {request.userName}</p>
            <p><span className="text-gray-500">Amount:</span> ₹{request.amount.toLocaleString()}</p>
          </div>
          <div>
            <label className="block text-xs text-gray-500 mb-1">Rejection Reason</label>
            <textarea
              rows={3}
              value={reason}
              onChange={(e) => { setReason(e.target.value); setError(''); }}
              placeholder="Enter reason for rejection..."
              className="w-full bg-[#0f1518] border border-[#1a2130] focus:border-[#243BFF] text-gray-100 text-sm rounded px-3 py-2 outline-none resize-none"
              autoFocus
            />
            {error && <p className="mt-1 text-xs text-[#fca5a5]">{error}</p>}
          </div>
          <p className="text-xs text-[#ff9800]">
            ⚠️ Rejecting will refund ₹{request.amount.toLocaleString()} back to the agent's wallet.
          </p>
        </div>

        <div className="flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2.5 bg-[#0f1518] text-gray-300 rounded hover:bg-[#13171a] transition-colors text-sm"
          >
            Cancel
          </button>
          <button
            onClick={handleConfirm}
            disabled={loading}
            className="flex-1 px-4 py-2.5 bg-[#e53935] text-white rounded hover:bg-[#c62828] transition-colors text-sm disabled:opacity-50"
          >
            {loading ? 'Processing…' : 'Reject & Refund'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Main Component ─────────────────────────────────────────────────────────────

export default function WithdrawalManagement() {
  const [requests, setRequests] = useState<WithdrawalRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | WithdrawalRequest['withdrawalStatus']>('all');
  const [rejectTarget, setRejectTarget] = useState<WithdrawalRequest | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  // ── Subscribe to withdrawals (stored in wallet_transactions with type='withdrawal') ──
  useEffect(() => {
    const q = query(collection(db, 'wallet_transactions'), orderBy('createdAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const withdrawalDocs = snapshot.docs.filter((d) => d.data().type === 'withdrawal');
      setRequests(
        withdrawalDocs.map((d) => {
          const data = d.data();
          return {
            id: d.id,
            userId: data.userId ?? data.agentId ?? '',
            userName: data.userName ?? data.agentName ?? '—',
            userPhone: data.userPhone ?? '',
            amount: data.amount ?? 0,
            paymentMethod: data.paymentMethod ?? 'upi',
            paymentDetails: data.paymentDetails ?? {},
            withdrawalStatus: data.withdrawalStatus ?? 'pending',
            createdAt: data.createdAt ?? null,
            updatedAt: data.updatedAt ?? null,
            rejectionReason: data.rejectionReason,
          } as WithdrawalRequest;
        })
      );
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  // ── Filtered list ─────────────────────────────────────────────────────────────
  const filtered = useMemo(() => {
    let list = requests;
    if (statusFilter !== 'all') list = list.filter((r) => r.withdrawalStatus === statusFilter);
    const q = searchTerm.trim().toLowerCase();
    if (q) {
      list = list.filter(
        (r) =>
          r.userName.toLowerCase().includes(q) ||
          r.userPhone.includes(searchTerm.trim()) ||
          r.userId.toLowerCase().includes(q)
      );
    }
    return list;
  }, [requests, statusFilter, searchTerm]);

  // ── Stats ─────────────────────────────────────────────────────────────────────
  const pendingCount = requests.filter((r) => r.withdrawalStatus === 'pending').length;
  const processingCount = requests.filter((r) => r.withdrawalStatus === 'processing').length;
  const totalApproved = requests
    .filter((r) => r.withdrawalStatus === 'approved')
    .reduce((s, r) => s + r.amount, 0);
  const totalPending = requests
    .filter((r) => r.withdrawalStatus === 'pending' || r.withdrawalStatus === 'processing')
    .reduce((s, r) => s + r.amount, 0);

  // ── Actions ───────────────────────────────────────────────────────────────────
  const updateStatus = async (
    requestId: string,
    newStatus: 'processing' | 'approved',
    request: WithdrawalRequest
  ) => {
    setActionLoading(requestId + newStatus);
    try {
      await updateDoc(doc(db, 'wallet_transactions', requestId), {
        withdrawalStatus: newStatus,
        updatedAt: serverTimestamp(),
      });
    } finally {
      setActionLoading(null);
    }
  };

  const rejectRequest = async (request: WithdrawalRequest, reason: string) => {
    await updateDoc(doc(db, 'wallet_transactions', request.id), {
      withdrawalStatus: 'rejected',
      rejectionReason: reason,
      updatedAt: serverTimestamp(),
    });
    // Refund wallet
    await updateDoc(doc(db, 'users', request.userId), {
      walletBalance: increment(request.amount),
    });
    // Log refund
    await addDoc(collection(db, 'wallet_transactions'), {
      agentId: request.userId,
      agentName: request.userName,
      amount: request.amount,
      type: 'credit',
      note: `Withdrawal refund: ${reason}`,
      createdAt: serverTimestamp(),
    });
  };

  return (
    <div className="space-y-6">
      {rejectTarget && (
        <RejectModal
          request={rejectTarget}
          onClose={() => setRejectTarget(null)}
          onConfirm={(reason) => rejectRequest(rejectTarget, reason)}
        />
      )}

      <div>
        <h1 className="text-2xl text-gray-100 mb-2">Withdrawal Requests</h1>
        <p className="text-gray-400">Review and process agent withdrawal requests</p>
      </div>

      {/* Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#ff9800]">
          <div className="flex items-center gap-3 mb-3">
            <Clock className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Pending Requests</h3>
          </div>
          <p className="text-3xl font-semibold">{pendingCount}</p>
        </div>
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#1e88e5]">
          <div className="flex items-center gap-3 mb-3">
            <Loader2 className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Processing</h3>
          </div>
          <p className="text-3xl font-semibold">{processingCount}</p>
        </div>
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#4caf50]">
          <div className="flex items-center gap-3 mb-3">
            <Check className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Total Approved</h3>
          </div>
          <p className="text-3xl font-semibold">₹{totalApproved.toLocaleString()}</p>
        </div>
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#7b1fa2]">
          <div className="flex items-center gap-3 mb-3">
            <ArrowDownUp className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Pending Amount</h3>
          </div>
          <p className="text-3xl font-semibold">₹{totalPending.toLocaleString()}</p>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-[#071018] border border-[#111318] rounded">
        <div className="px-5 py-4 border-b border-[#111318] flex flex-col sm:flex-row sm:items-center gap-3">
          <h2 className="text-lg text-gray-100 flex-shrink-0">Withdrawal Requests</h2>
          <div className="flex flex-wrap gap-2 sm:ml-auto items-center">
            {/* Status tabs */}
            {(['all', 'pending', 'processing', 'approved', 'rejected'] as const).map((s) => (
              <button
                key={s}
                onClick={() => setStatusFilter(s)}
                className={`px-3 py-1 rounded text-xs capitalize transition-colors ${
                  statusFilter === s
                    ? 'bg-[#243BFF] text-white'
                    : 'bg-[#0f1518] text-gray-400 hover:text-gray-200'
                }`}
              >
                {s === 'all' ? 'All' : s.charAt(0).toUpperCase() + s.slice(1)}
              </button>
            ))}
            {/* Search */}
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Search by name or phone..."
                className="bg-[#0f1518] text-gray-300 text-sm pl-9 pr-8 py-1.5 rounded border border-[#1a2130] focus:outline-none focus:border-[#243BFF] placeholder-gray-600 w-52"
              />
              {searchTerm && (
                <button
                  onClick={() => setSearchTerm('')}
                  className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-[#0f1518] border-b border-[#111318]">
              <tr>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Agent</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Amount</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Payment Details</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Status</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Date</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#0f1518]">
              {loading ? (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-sm text-gray-400">
                    Loading…
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-sm text-gray-400">
                    {searchTerm || statusFilter !== 'all'
                      ? 'No requests match your filters.'
                      : 'No withdrawal requests yet.'}
                  </td>
                </tr>
              ) : (
                filtered.map((req) => (
                  <tr key={req.id} className="hover:bg-[#071318]">
                    <td className="px-5 py-4">
                      <p className="text-sm text-gray-100">{req.userName}</p>
                      <p className="text-xs text-gray-500 mt-0.5">{req.userPhone || '—'}</p>
                    </td>
                    <td className="px-5 py-4 text-sm font-medium text-gray-100">
                      ₹{req.amount.toLocaleString()}
                    </td>
                    <td className="px-5 py-4">
                      <p className="text-xs text-gray-500 capitalize">
                        {req.paymentMethod === 'upi' ? 'UPI' : 'Bank Transfer'}
                      </p>
                      <p className="text-sm text-gray-300 mt-0.5">
                        {req.paymentMethod === 'upi'
                          ? req.paymentDetails?.upiId || '—'
                          : `${req.paymentDetails?.holderName || ''} · ${req.paymentDetails?.accountNumber || ''}`}
                      </p>
                      {req.paymentMethod === 'bank' && req.paymentDetails?.ifscCode && (
                        <p className="text-xs text-gray-500">IFSC: {req.paymentDetails.ifscCode}</p>
                      )}
                      {req.withdrawalStatus === 'rejected' && req.rejectionReason && (
                        <p className="text-xs text-[#f44336] mt-1 flex items-start gap-1">
                          <AlertCircle className="w-3 h-3 flex-shrink-0 mt-0.5" />
                          {req.rejectionReason}
                        </p>
                      )}
                    </td>
                    <td className="px-5 py-4">
                      <StatusBadge status={req.withdrawalStatus} />
                    </td>
                    <td className="px-5 py-4 text-sm text-gray-400">
                      {formatDate(req.createdAt)}
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex items-center gap-2">
                      {req.withdrawalStatus === 'pending' && (
                          <>
                            <button
                              onClick={() => updateStatus(req.id, 'processing', req)}
                              disabled={actionLoading === req.id + 'processing'}
                              className="flex items-center gap-1.5 px-3 py-1.5 bg-[#1e88e5] text-white rounded hover:bg-[#1565c0] transition-colors text-xs disabled:opacity-50"
                              title="Mark as Processing"
                            >
                              {actionLoading === req.id + 'processing' ? (
                                <Loader2 className="w-3.5 h-3.5 animate-spin" />
                              ) : (
                                <Clock className="w-3.5 h-3.5" />
                              )}
                              Processing
                            </button>
                            <button
                              onClick={() => setRejectTarget(req)}
                              className="flex items-center gap-1.5 px-3 py-1.5 bg-[#e53935] text-white rounded hover:bg-[#c62828] transition-colors text-xs"
                              title="Reject"
                            >
                              <XCircle className="w-3.5 h-3.5" />
                              Reject
                            </button>
                          </>
                        )}
                        {req.withdrawalStatus === 'processing' && (
                          <>
                            <button
                              onClick={() => updateStatus(req.id, 'approved', req)}
                              disabled={actionLoading === req.id + 'approved'}
                              className="flex items-center gap-1.5 px-3 py-1.5 bg-[#4caf50] text-white rounded hover:bg-[#388e3c] transition-colors text-xs disabled:opacity-50"
                              title="Approve"
                            >
                              {actionLoading === req.id + 'approved' ? (
                                <Loader2 className="w-3.5 h-3.5 animate-spin" />
                              ) : (
                                <Check className="w-3.5 h-3.5" />
                              )}
                              Approve
                            </button>
                            <button
                              onClick={() => setRejectTarget(req)}
                              className="flex items-center gap-1.5 px-3 py-1.5 bg-[#e53935] text-white rounded hover:bg-[#c62828] transition-colors text-xs"
                              title="Reject"
                            >
                              <XCircle className="w-3.5 h-3.5" />
                              Reject
                            </button>
                          </>
                        )}
                        {(req.withdrawalStatus === 'approved' || req.withdrawalStatus === 'rejected') && (
                          <span className="text-xs text-gray-600 italic">—</span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Policy Note */}
      <div className="bg-[#071018] border border-[#111318] rounded p-5">
        <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318]">
          Withdrawal Policy
        </h2>
        <div className="space-y-3 text-sm text-gray-400">
          <div className="flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-[#243BFF] flex-shrink-0 mt-0.5" />
            <p><strong>Minimum Withdrawal:</strong> ₹100 minimum per withdrawal request</p>
          </div>
          <div className="flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-[#243BFF] flex-shrink-0 mt-0.5" />
            <p><strong>Processing:</strong> Mark as Processing once you've initiated the transfer, then Approve once completed</p>
          </div>
          <div className="flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-[#243BFF] flex-shrink-0 mt-0.5" />
            <p><strong>Rejection & Refund:</strong> Rejecting a request automatically refunds the amount to the agent's wallet</p>
          </div>
        </div>
      </div>
    </div>
  );
}
