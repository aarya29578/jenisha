import { useState, useEffect } from 'react';
import { Percent, Save, Info } from 'lucide-react';
import {
  getFirestore,
  doc,
  getDoc,
  setDoc,
  serverTimestamp,
  onSnapshot,
  collection,
  query,
  where,
  orderBy,
  limit,
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

interface CommissionTransaction {
  id: string;
  agentName: string;
  userName: string;
  serviceName: string;
  serviceFee: number;
  amount: number;
  commissionPercentage: number;
  createdAt: Timestamp | null;
}

const formatDate = (ts: Timestamp | null | undefined) => {
  if (!ts) return '—';
  return ts.toDate().toLocaleString('en-IN');
};

export default function CommissionSettings() {
  const [commissionPercentage, setCommissionPercentage] = useState<number>(20);
  const [inputValue, setInputValue] = useState<string>('20');
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState('');
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [loading, setLoading] = useState(true);

  const [recentCommissions, setRecentCommissions] = useState<CommissionTransaction[]>([]);
  const [txnLoading, setTxnLoading] = useState(true);

  // Total commission stats
  const [totalCommissionPaid, setTotalCommissionPaid] = useState(0);

  // ── Load current setting ──────────────────────────────────────────────────
  useEffect(() => {
    getDoc(doc(db, 'settings', 'commission')).then((snap) => {
      if (snap.exists()) {
        const pct = snap.data().commissionPercentage;
        if (typeof pct === 'number') {
          setCommissionPercentage(pct);
          setInputValue(String(pct));
        }
      }
      setLoading(false);
    });
  }, []);

  // ── Subscribe to recent commission transactions ───────────────────────────
  useEffect(() => {
    const q = query(
      collection(db, 'wallet_transactions'),
      where('type', '==', 'commission'),
      orderBy('createdAt', 'desc'),
      limit(50)
    );
    const unsub = onSnapshot(q, (snap) => {
      const rows: CommissionTransaction[] = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          agentName: data.agentName || '—',
          userName: data.userName || '—',
          serviceName: data.serviceName || '—',
          serviceFee: data.serviceFee ?? 0,
          amount: data.amount ?? 0,
          commissionPercentage: data.commissionPercentage ?? commissionPercentage,
          createdAt: data.createdAt ?? null,
        };
      });
      setRecentCommissions(rows);
      setTotalCommissionPaid(rows.reduce((sum, r) => sum + r.amount, 0));
      setTxnLoading(false);
    });
    return unsub;
  }, [commissionPercentage]);

  // ── Save handler ─────────────────────────────────────────────────────────
  const handleSave = async () => {
    const parsed = parseFloat(inputValue);
    if (isNaN(parsed) || parsed < 0 || parsed > 100) {
      setSaveError('Please enter a valid percentage between 0 and 100.');
      return;
    }
    setSaving(true);
    setSaveError('');
    setSaveSuccess(false);
    try {
      await setDoc(
        doc(db, 'settings', 'commission'),
        {
          commissionPercentage: parsed,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
      setCommissionPercentage(parsed);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch {
      setSaveError('Failed to save. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl text-gray-100 mb-2">Commission Settings</h1>
        <p className="text-gray-400">
          Configure the percentage of service fees paid as commission to referring agents.
        </p>
      </div>

      {/* Settings Card */}
      <div className="bg-[#071018] border border-[#111318] rounded p-6 max-w-lg">
        <div className="flex items-center gap-2 mb-5">
          <Percent className="w-5 h-5 text-[#243BFF]" />
          <h2 className="text-base text-gray-100">Commission Percentage</h2>
        </div>

        {loading ? (
          <p className="text-sm text-gray-400">Loading…</p>
        ) : (
          <div className="space-y-4">
            {/* Info Box */}
            <div className="flex gap-3 p-4 bg-[#0f1720] border border-[#1a2130] rounded text-sm text-gray-400">
              <Info className="w-4 h-4 text-[#243BFF] flex-shrink-0 mt-0.5" />
              <div>
                When a user referred by an agent submits a <strong className="text-gray-300">paid</strong> service
                application, the agent automatically receives this percentage of the service fee in their
                wallet — <strong className="text-gray-300">for every future application</strong> by that user (lifetime).
              </div>
            </div>

            {/* Input */}
            <div>
              <label className="block text-xs text-gray-500 mb-1.5">
                Commission Percentage (%)
              </label>
              <div className="flex gap-3">
                <div className="relative flex-1">
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="0.5"
                    value={inputValue}
                    onChange={(e) => {
                      setInputValue(e.target.value);
                      setSaveError('');
                    }}
                    className="w-full bg-[#0f1518] border border-[#1a2130] focus:border-[#243BFF] text-gray-100 text-sm rounded px-3 py-2 outline-none pr-8"
                    placeholder="e.g. 20"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">%</span>
                </div>
                <button
                  onClick={handleSave}
                  disabled={saving}
                  className="flex items-center gap-2 px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors text-sm disabled:opacity-50"
                >
                  <Save className="w-4 h-4" />
                  {saving ? 'Saving…' : 'Save'}
                </button>
              </div>
              {saveError && <p className="mt-1.5 text-xs text-[#fca5a5]">{saveError}</p>}
              {saveSuccess && (
                <p className="mt-1.5 text-xs text-green-400">
                  ✓ Commission percentage updated to {commissionPercentage}%
                </p>
              )}
            </div>

            {/* Example */}
            <div className="p-4 bg-[#0f1720] border border-[#1a2130] rounded text-sm">
              <p className="text-gray-400 mb-2 font-medium">Example</p>
              <div className="space-y-1 text-gray-400">
                <p>Service Fee: <span className="text-gray-200">₹200</span></p>
                <p>Commission ({commissionPercentage}%): <span className="text-green-400 font-semibold">₹{(200 * commissionPercentage / 100).toFixed(2)}</span></p>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 max-w-lg">
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <p className="text-xs text-gray-500 mb-1">Total Commission Paid</p>
          <p className="text-2xl text-green-400 font-semibold">
            ₹{totalCommissionPaid.toLocaleString('en-IN', { maximumFractionDigits: 2 })}
          </p>
        </div>
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <p className="text-xs text-gray-500 mb-1">Commission Transactions</p>
          <p className="text-2xl text-[#243BFF] font-semibold">{recentCommissions.length}</p>
        </div>
      </div>

      {/* Commission Transaction History */}
      <div className="bg-[#071018] border border-[#111318] rounded">
        <div className="px-5 py-4 border-b border-[#111318]">
          <h2 className="text-base text-gray-100">Commission Transaction History</h2>
          <p className="text-xs text-gray-500 mt-1">All auto-generated commission credits</p>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-[#0f1518] border-b border-[#111318]">
              <tr>
                <th className="px-5 py-3 text-left text-xs text-gray-400">Date</th>
                <th className="px-5 py-3 text-left text-xs text-gray-400">Agent</th>
                <th className="px-5 py-3 text-left text-xs text-gray-400">Customer</th>
                <th className="px-5 py-3 text-left text-xs text-gray-400">Service</th>
                <th className="px-5 py-3 text-left text-xs text-gray-400">Service Fee</th>
                <th className="px-5 py-3 text-left text-xs text-gray-400">Rate</th>
                <th className="px-5 py-3 text-left text-xs text-gray-400">Commission</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#0f1518]">
              {txnLoading ? (
                <tr>
                  <td colSpan={7} className="px-5 py-8 text-center text-sm text-gray-400">
                    Loading transactions…
                  </td>
                </tr>
              ) : recentCommissions.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-5 py-8 text-center text-sm text-gray-400">
                    No commission transactions yet.
                  </td>
                </tr>
              ) : (
                recentCommissions.map((txn) => (
                  <tr key={txn.id} className="hover:bg-[#071318] transition-colors">
                    <td className="px-5 py-3 text-xs text-gray-400 whitespace-nowrap">
                      {formatDate(txn.createdAt)}
                    </td>
                    <td className="px-5 py-3 text-sm text-gray-100">{txn.agentName}</td>
                    <td className="px-5 py-3 text-sm text-gray-400">{txn.userName}</td>
                    <td className="px-5 py-3 text-sm text-gray-400">{txn.serviceName}</td>
                    <td className="px-5 py-3 text-sm text-gray-400">₹{txn.serviceFee}</td>
                    <td className="px-5 py-3 text-sm text-gray-400">{txn.commissionPercentage}%</td>
                    <td className="px-5 py-3 text-sm font-semibold text-green-400">
                      +₹{txn.amount.toLocaleString('en-IN', { maximumFractionDigits: 2 })}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
