import { useState, useEffect, useMemo } from 'react';
import { Wallet, Plus, Minus, History, AlertCircle, Search, X, TrendingUp } from 'lucide-react';
import {
  getFirestore,
  collection,
  query,
  orderBy,
  limit,
  onSnapshot,
  doc,
  updateDoc,
  addDoc,
  increment,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { initializeApp, getApps } from 'firebase/app';
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

interface AgentWallet {
  id: string;
  name: string;
  phone: string;
  balance: number;
  lastRecharge: Timestamp | null;
}

interface WalletTransaction {
  id: string;
  agentName: string;
  userName?: string;
  serviceName?: string;
  amount: number;
  type: string;
  serviceFee?: number;
  commissionPercentage?: number;
  createdAt: Timestamp | null;
}

const formatDate = (timestamp: Timestamp | null | undefined) => {
  if (!timestamp) return '—';
  return timestamp.toDate().toLocaleString('en-IN');
};

// ── Adjust Modal (Add / Subtract) ─────────────────────────────────────────────

interface AdjustModalProps {
  agent: AgentWallet;
  onClose: () => void;
  onConfirm: (agentId: string, amount: number, mode: 'add' | 'subtract') => Promise<void>;
}

function AdjustModal({ agent, onClose, onConfirm }: AdjustModalProps) {
  const [mode, setMode] = useState<'add' | 'subtract'>('add');
  const [amount, setAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleConfirm = async () => {
    const parsed = parseFloat(amount);
    if (!amount || isNaN(parsed) || parsed <= 0) {
      setError('Please enter a valid amount greater than 0.');
      return;
    }
    if (mode === 'subtract' && parsed > agent.balance) {
      setError(`Cannot deduct more than current balance (₹${agent.balance.toLocaleString()}).`);
      return;
    }
    setLoading(true);
    setError('');
    try {
      await onConfirm(agent.id, parsed, mode);
      onClose();
    } catch {
      setError('Operation failed. Please try again.');
      setLoading(false);
    }
  };

  const newBalance =
    amount && !isNaN(parseFloat(amount))
      ? mode === 'add'
        ? agent.balance + parseFloat(amount)
        : agent.balance - parseFloat(amount)
      : null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60">
      <div className="bg-[#0a0f1a] border border-[#1a2130] rounded-lg w-full max-w-md p-6 shadow-xl">
        <div className="flex items-center justify-between mb-5">
          <h2 className="text-lg text-gray-100">Adjust Wallet Balance</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-gray-300 transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Add / Subtract toggle */}
        <div className="flex rounded overflow-hidden border border-[#1a2130] mb-5">
          <button
            onClick={() => { setMode('add'); setError(''); }}
            className={`flex-1 flex items-center justify-center gap-2 py-2.5 text-sm font-medium transition-colors ${
              mode === 'add'
                ? 'bg-[#0f9d58] text-white'
                : 'bg-[#0f1518] text-gray-400 hover:text-gray-200'
            }`}
          >
            <Plus className="w-4 h-4" /> Add
          </button>
          <button
            onClick={() => { setMode('subtract'); setError(''); }}
            className={`flex-1 flex items-center justify-center gap-2 py-2.5 text-sm font-medium transition-colors ${
              mode === 'subtract'
                ? 'bg-[#e53935] text-white'
                : 'bg-[#0f1518] text-gray-400 hover:text-gray-200'
            }`}
          >
            <Minus className="w-4 h-4" /> Subtract
          </button>
        </div>

        <div className="space-y-4 mb-5">
          <div>
            <label className="block text-xs text-gray-500 mb-1">Agent Name</label>
            <div className="w-full bg-[#0f1518] border border-[#1a2130] text-gray-400 text-sm rounded px-3 py-2">
              {agent.name}
            </div>
          </div>
          <div>
            <label className="block text-xs text-gray-500 mb-1">Current Balance</label>
            <div className="w-full bg-[#0f1518] border border-[#1a2130] text-gray-400 text-sm rounded px-3 py-2">
              ₹{agent.balance.toLocaleString()}
            </div>
          </div>
          <div>
            <label className="block text-xs text-gray-500 mb-1">
              {mode === 'add' ? 'Amount to Add' : 'Amount to Subtract'}
            </label>
            <input
              type="number"
              min="1"
              value={amount}
              onChange={(e) => { setAmount(e.target.value); setError(''); }}
              placeholder="Enter amount"
              className="w-full bg-[#0f1518] border border-[#1a2130] focus:border-[#243BFF] text-gray-100 text-sm rounded px-3 py-2 outline-none"
              autoFocus
            />
            {error && <p className="mt-1 text-xs text-[#fca5a5]">{error}</p>}
          </div>
          {newBalance !== null && (
            <div className="flex items-center gap-2 bg-[#0f1518] border border-[#1a2130] rounded px-3 py-2">
              <span className="text-xs text-gray-500">New balance:</span>
              <span className={`text-sm font-semibold ${
                newBalance < 0 ? 'text-red-400' : 'text-[#4ade80]'
              }`}>
                ₹{newBalance.toLocaleString()}
              </span>
            </div>
          )}
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
            className={`flex-1 px-4 py-2.5 text-white rounded transition-colors text-sm disabled:opacity-50 ${
              mode === 'add' ? 'bg-[#0f9d58] hover:bg-[#0b8a4c]' : 'bg-[#e53935] hover:bg-[#c62828]'
            }`}
          >
            {loading ? 'Processing…' : mode === 'add' ? 'Add Amount' : 'Subtract Amount'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Main Component ─────────────────────────────────────────────────────────────

export default function WalletManagement() {
  const [agents, setAgents] = useState<AgentWallet[]>([]);
  const [transactions, setTransactions] = useState<WalletTransaction[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [rechargeTarget, setRechargeTarget] = useState<AgentWallet | null>(null);
  const [txnTab, setTxnTab] = useState<'all' | 'recharge' | 'commission'>('all');

  // ── Subscribe to agents ──────────────────────────────────────────────────────
  useEffect(() => {
    const unsubscribe = onSnapshot(collection(db, 'users'), (snapshot) => {
      const list: AgentWallet[] = snapshot.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          name: data.fullName || data.name || 'Unknown',
          phone: data.phone || '',
          balance: typeof data.walletBalance === 'number' ? data.walletBalance : 0,
          lastRecharge: data.lastRecharge ?? null,
        };
      });
      setAgents(list);
      setLoading(false);
    });
    return unsubscribe;
  }, []);

  // ── Subscribe to recent transactions ────────────────────────────────────────
  useEffect(() => {
    const q = query(
      collection(db, 'wallet_transactions'),
      orderBy('createdAt', 'desc'),
      limit(100)
    );
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        setTransactions(
          snapshot.docs.map((d) => {
            const data = d.data();
            return {
              id: d.id,
              agentName: data.agentName || '—',
              userName: data.userName,
              serviceName: data.serviceName,
              amount: data.amount ?? 0,
              type: data.type || 'recharge',
              serviceFee: data.serviceFee,
              commissionPercentage: data.commissionPercentage,
              createdAt: data.createdAt ?? null,
            };
          })
        );
      },
      (err) => {
        // Firestore rules not yet deployed — transactions will appear after rules are deployed.
        console.warn('wallet_transactions read blocked (deploy Firestore rules):', err.code);
      }
    );
    return unsubscribe;
  }, []);

  // ── Filtered agents ──────────────────────────────────────────────────────────
  const filteredAgents = useMemo(() => {
    const q = searchTerm.trim().toLowerCase();
    if (!q) return agents;
    return agents.filter(
      (a) =>
        a.name.toLowerCase().includes(q) ||
        a.phone.includes(searchTerm.trim()) ||
        a.id.toLowerCase().includes(q)
    );
  }, [agents, searchTerm]);

  // ── Adjust handler (add or subtract) ───────────────────────────────────────
  const handleRecharge = async (agentId: string, amount: number, mode: 'add' | 'subtract' = 'add') => {
    const agent = agents.find((a) => a.id === agentId)!;
    const currentAdmin = authService.getCurrentUser();
    const delta = mode === 'subtract' ? -amount : amount;

    await updateDoc(doc(db, 'users', agentId), {
      walletBalance: increment(delta),
      lastRecharge: serverTimestamp(),
    });

    try {
      await addDoc(collection(db, 'wallet_transactions'), {
        agentId,
        agentName: agent.name,
        amount,
        type: mode === 'subtract' ? 'deduction' : 'recharge',
        createdAt: serverTimestamp(),
        adminId: currentAdmin?.uid ?? 'unknown',
      });
    } catch (logErr) {
      console.warn('wallet_transactions write failed (non-fatal):', logErr);
    }
  };

  const totalBalance = agents.reduce((sum, a) => sum + a.balance, 0);
  const todayRecharges = transactions
    .filter((t) => {
      if (!t.createdAt) return false;
      const d = t.createdAt.toDate();
      const now = new Date();
      return (
        t.type === 'recharge' &&
        d.getFullYear() === now.getFullYear() &&
        d.getMonth() === now.getMonth() &&
        d.getDate() === now.getDate()
      );
    })
    .reduce((sum, t) => sum + t.amount, 0);

  const totalCommissionPaid = transactions
    .filter((t) => t.type === 'commission')
    .reduce((sum, t) => sum + t.amount, 0);

  const filteredTransactions = useMemo(() => {
    if (txnTab === 'recharge') return transactions.filter((t) => t.type === 'recharge');
    if (txnTab === 'commission') return transactions.filter((t) => t.type === 'commission');
    return transactions;
  }, [transactions, txnTab]);

  return (
    <div className="space-y-6">
      {rechargeTarget && (
        <AdjustModal
          agent={rechargeTarget}
          onClose={() => setRechargeTarget(null)}
          onConfirm={handleRecharge}
        />
      )}

      <div>
        <h1 className="text-2xl text-gray-100 mb-2">Wallet & Payment Management</h1>
        <p className="text-gray-400">Manage agent wallet balances and transactions</p>
      </div>

      {/* Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#243BFF]">
          <div className="flex items-center gap-3 mb-3">
            <Wallet className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Total System Balance</h3>
          </div>
          <p className="text-3xl font-semibold">₹{totalBalance.toLocaleString()}</p>
        </div>
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#0f9d58]">
          <div className="flex items-center gap-3 mb-3">
            <Plus className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Total Recharges (Today)</h3>
          </div>
          <p className="text-3xl font-semibold">₹{todayRecharges.toLocaleString()}</p>
        </div>
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#ff9800]">
          <div className="flex items-center gap-3 mb-3">
            <History className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Total Transactions</h3>
          </div>
          <p className="text-3xl font-semibold">{transactions.length}</p>
        </div>
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#7b1fa2]">
          <div className="flex items-center gap-3 mb-3">
            <TrendingUp className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Total Commission Paid</h3>
          </div>
          <p className="text-3xl font-semibold">₹{totalCommissionPaid.toLocaleString()}</p>
        </div>
      </div>

      {/* Agent Wallets */}
      <div className="bg-[#071018] border border-[#111318] rounded">
        <div className="px-5 py-4 border-b border-[#111318] flex flex-col sm:flex-row sm:items-center gap-3">
          <h2 className="text-lg text-gray-100 flex-shrink-0">Agent Wallet Balances</h2>
          {/* Search */}
          <div className="relative flex-1 sm:max-w-sm sm:ml-auto">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search agent by name, phone, or ID..."
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
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-[#0f1518] border-b border-[#111318]">
              <tr>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Agent Name</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Phone</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Current Balance</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Last Recharge</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#0f1518]">
              {loading ? (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-sm text-gray-400">
                    Loading agents…
                  </td>
                </tr>
              ) : filteredAgents.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-5 py-8 text-center text-sm text-gray-400">
                    {searchTerm ? 'No agents match your search.' : 'No agents found.'}
                  </td>
                </tr>
              ) : (
                filteredAgents.map((agent) => (
                  <tr key={agent.id} className="hover:bg-[#071318]">
                    <td className="px-5 py-4 text-sm text-gray-100">{agent.name}</td>
                    <td className="px-5 py-4 text-sm text-gray-400">{agent.phone || '—'}</td>
                    <td className="px-5 py-4 text-sm font-medium text-gray-100">
                      ₹{agent.balance.toLocaleString()}
                    </td>
                    <td className="px-5 py-4 text-sm text-gray-400">
                      {formatDate(agent.lastRecharge)}
                    </td>
                    <td className="px-5 py-4">
                      <button
                        onClick={() => setRechargeTarget(agent)}
                        className="flex items-center gap-2 px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors text-sm"
                      >
                        <Wallet className="w-4 h-4" />
                        Adjust
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Transactions */}
      <div className="bg-[#071018] border border-[#111318] rounded">
        <div className="px-5 py-4 border-b border-[#111318] flex flex-col sm:flex-row sm:items-center gap-3">
          <h2 className="text-lg text-gray-100 flex-shrink-0">Transactions</h2>
          <div className="flex gap-2 sm:ml-auto">
            {(['all', 'recharge', 'commission'] as const).map((tab) => (
              <button
                key={tab}
                onClick={() => setTxnTab(tab)}
                className={`px-3 py-1 rounded text-xs capitalize transition-colors ${
                  txnTab === tab
                    ? 'bg-[#243BFF] text-white'
                    : 'bg-[#0f1518] text-gray-400 hover:text-gray-200'
                }`}
              >
                {tab === 'all' ? 'All' : tab === 'recharge' ? 'Recharges' : 'Commissions'}
              </button>
            ))}
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-[#0f1518] border-b border-[#111318]">
              <tr>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Agent</th>
                {txnTab !== 'recharge' && (
                  <>
                    <th className="px-5 py-3 text-left text-sm text-gray-100">Customer</th>
                    <th className="px-5 py-3 text-left text-sm text-gray-100">Service</th>
                  </>
                )}
                <th className="px-5 py-3 text-left text-sm text-gray-100">Type</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Amount</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Date & Time</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#0f1518]">
              {filteredTransactions.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-sm text-gray-400">
                    No transactions yet.
                  </td>
                </tr>
              ) : (
                filteredTransactions.map((tx) => (
                  <tr key={tx.id} className="hover:bg-[#071318]">
                    <td className="px-5 py-4 text-sm text-gray-100">{tx.agentName}</td>
                    {txnTab !== 'recharge' && (
                      <>
                        <td className="px-5 py-4 text-sm text-gray-400">{tx.userName || '—'}</td>
                        <td className="px-5 py-4 text-sm text-gray-400">{tx.serviceName || '—'}</td>
                      </>
                    )}
                    <td className="px-5 py-4">
                      <span
                        className={`px-2 py-0.5 rounded text-xs capitalize ${
                          tx.type === 'commission'
                            ? 'bg-[#ede7f6] text-[#7b1fa2]'
                            : tx.type === 'deduction'
                            ? 'bg-[#ffebee] text-[#e53935]'
                            : 'bg-[#E8F5E9] text-[#4CAF50]'
                        }`}
                      >
                        {tx.type}
                      </span>
                    </td>
                    <td className="px-5 py-4 text-sm font-medium">
                      <span className={tx.type === 'commission' ? 'text-[#ce93d8]' : tx.type === 'deduction' ? 'text-red-400' : 'text-gray-100'}>
                        {tx.type === 'deduction' ? '-' : '+'}₹{tx.amount.toLocaleString()}
                      </span>
                      {tx.type === 'commission' && tx.commissionPercentage !== undefined && (
                        <span className="ml-1 text-xs text-gray-500">({tx.commissionPercentage}%)</span>
                      )}
                    </td>
                    <td className="px-5 py-4 text-sm text-gray-400">{formatDate(tx.createdAt)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Wallet Policy */}
      <div className="bg-[#071018] border border-[#111318] rounded p-5">
        <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318]">
          Wallet Policy & Rules
        </h2>
        <div className="space-y-3 text-sm text-gray-400">
          <div className="flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-[#243BFF] flex-shrink-0 mt-0.5" />
            <p><strong>Registration Fee:</strong> Non-refundable initial deposit required for agent activation</p>
          </div>
          <div className="flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-[#243BFF] flex-shrink-0 mt-0.5" />
            <p><strong>Working Balance:</strong> Agents must maintain minimum balance to process services</p>
          </div>
          <div className="flex items-start gap-2">
            <AlertCircle className="w-4 h-4 text-[#243BFF] flex-shrink-0 mt-0.5" />
            <p><strong>Inactivity Rule:</strong> Accounts inactive for 6 months will be automatically suspended</p>
          </div>
        </div>
      </div>
    </div>
  );
}
