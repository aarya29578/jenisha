import { useState, useEffect } from 'react';
import { Wallet, Plus, History, AlertCircle } from 'lucide-react';
import {
  getFirestore,
  collection,
  query,
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

interface AgentWallet {
  id: string;
  name: string;
  balance: number;
  lastRecharge: string;
}

const formatDate = (timestamp: Timestamp | null | undefined) => {
  if (!timestamp) return '-';
  return timestamp.toDate().toLocaleDateString('en-IN');
};

export default function WalletManagement() {
  const [agents, setAgents] = useState<AgentWallet[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'users'));
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const agentList: AgentWallet[] = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.fullName || data.name || 'Unknown',
          balance: typeof data.walletBalance === 'number' ? data.walletBalance : 0,
          lastRecharge: formatDate(data.lastRecharge || data.createdAt),
        };
      });
      setAgents(agentList);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const totalBalance = agents.reduce((sum, agent) => sum + agent.balance, 0);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl text-gray-100 mb-2">Wallet & Payment Management</h1>
        <p className="text-gray-400">Manage agent wallet balances and transactions</p>
      </div>

      {/* Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
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
          <p className="text-3xl font-semibold">₹15,000</p>
        </div>
        <div className="rounded-lg p-5 shadow-md text-white flex flex-col bg-[#ff9800]">
          <div className="flex items-center gap-3 mb-3">
            <History className="w-5 h-5 text-white" />
            <h3 className="text-sm text-white/90">Total Transactions (Today)</h3>
          </div>
          <p className="text-3xl font-semibold">24</p>
        </div>
      </div>

      {/* Agent Wallets */}
      <div className="bg-[#071018] border border-[#111318] rounded">
        <div className="px-5 py-4 border-b border-[#111318]">
          <h2 className="text-lg text-gray-100">Agent Wallet Balances</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-[#0f1518] border-b border-[#111318]">
              <tr>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Agent Name</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Current Balance</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Last Recharge</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#0f1518]">
              {loading ? (
                <tr>
                  <td colSpan={4} className="px-5 py-8 text-center text-sm text-gray-400">
                    Loading agents...
                  </td>
                </tr>
              ) : agents.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-5 py-8 text-center text-sm text-gray-400">
                    No agents found
                  </td>
                </tr>
              ) : (
                agents.map((agent) => (
                  <tr key={agent.id} className="hover:bg-[#071318]">
                    <td className="px-5 py-4 text-sm text-gray-100">{agent.name}</td>
                    <td className="px-5 py-4 text-sm text-gray-100">₹{agent.balance.toLocaleString()}</td>
                    <td className="px-5 py-4 text-sm text-gray-400">{agent.lastRecharge}</td>
                    <td className="px-5 py-4">
                      <button className="flex items-center gap-2 px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors text-sm">
                        <Plus className="w-4 h-4" />
                        Recharge
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Recent Transactions */}
      <div className="bg-[#071018] border border-[#111318] rounded">
        <div className="px-5 py-4 border-b border-[#111318]">
          <h2 className="text-lg text-gray-100">Recent Transactions</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-[#0f1518] border-b border-[#111318]">
              <tr>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Agent</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Type</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Amount</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Date & Time</th>
                <th className="px-5 py-3 text-left text-sm text-gray-100">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#0f1518]">
              <tr>
                <td colSpan={5} className="px-5 py-8 text-center text-sm text-gray-400">
                  Transaction history coming soon
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      {/* Fee Policy */}
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
