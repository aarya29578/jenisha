import { useState, useEffect } from 'react';
import { Users, TrendingUp, Gift } from 'lucide-react';
import {
  getFirestore,
  collection,
  query,
  onSnapshot,
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

interface ReferralData {
  id: string;
  agent: string;
  referralCode: string;
  totalReferrals: number;
  earnings: number;
}

export default function ReferEarn() {
  const [referralData, setReferralData] = useState<ReferralData[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'users'));
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const data: ReferralData[] = snapshot.docs
        .map((doc) => {
          const d = doc.data();
          return {
            id: doc.id,
            agent: d.fullName || d.name || 'Unknown',
            referralCode: d.referralCode || 'N/A',
            totalReferrals: d.totalReferrals || 0,
            earnings: d.referralEarnings || 0,
          };
        })
        .filter(agent => agent.totalReferrals > 0); // Only show agents with referrals
      
      setReferralData(data);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const totalReferrals = referralData.reduce((sum, agent) => sum + agent.totalReferrals, 0);
  const totalEarnings = referralData.reduce((sum, agent) => sum + agent.earnings, 0);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl text-[#1a1a1a] mb-2">Refer & Earn Management</h1>
        <p className="text-[#666666]">Track agent referrals and reward earnings</p>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <div className="flex items-center gap-3 mb-3">
            <Users className="w-5 h-5 text-[#4C4CFF]" />
            <h3 className="text-sm text-[#666666]">Total Referrals</h3>
          </div>
          <p className="text-3xl text-[#1a1a1a]">{totalReferrals}</p>
        </div>
        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <div className="flex items-center gap-3 mb-3">
            <TrendingUp className="w-5 h-5 text-[#4CAF50]" />
            <h3 className="text-sm text-[#666666]">Total Earnings Distributed</h3>
          </div>
          <p className="text-3xl text-[#1a1a1a]">₹{totalEarnings.toLocaleString()}</p>
        </div>
        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <div className="flex items-center gap-3 mb-3">
            <Gift className="w-5 h-5 text-[#FF9800]" />
            <h3 className="text-sm text-[#666666]">Active Referrers</h3>
          </div>
          <p className="text-3xl text-[#1a1a1a]">{referralData.length}</p>
        </div>
      </div>

      {/* Referral Tracking Table */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded">
        <div className="px-5 py-4 border-b-2 border-[#e5e5e5]">
          <h2 className="text-lg text-[#1a1a1a]">Referral Tracking Dashboard</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-[#f5f5f5] border-b-2 border-[#e5e5e5]">
              <tr>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Agent Name</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Referral Code</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Total Referrals</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Earnings Generated</th>
              </tr>
            </thead>
            <tbody className="divide-y-2 divide-[#e5e5e5]">
              {loading ? (
                <tr>
                  <td colSpan={4} className="px-5 py-8 text-center text-sm text-[#666666]">
                    Loading referral data...
                  </td>
                </tr>
              ) : referralData.length === 0 ? (
                <tr>
                  <td colSpan={4} className="px-5 py-8 text-center text-sm text-[#666666]">
                    No referral data available
                  </td>
                </tr>
              ) : (
                referralData.map((agent) => (
                  <tr key={agent.id} className="hover:bg-[#fafafa]">
                    <td className="px-5 py-4 text-sm text-[#1a1a1a]">{agent.agent}</td>
                    <td className="px-5 py-4">
                      <code className="px-2 py-1 bg-[#f5f5f5] rounded text-xs text-[#1a1a1a]">
                        {agent.referralCode}
                      </code>
                    </td>
                    <td className="px-5 py-4 text-sm text-[#1a1a1a]">{agent.totalReferrals}</td>
                    <td className="px-5 py-4 text-sm text-[#4CAF50]">₹{agent.earnings.toLocaleString()}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Reward Rules */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
        <h2 className="text-lg text-[#1a1a1a] mb-4 pb-3 border-b-2 border-[#e5e5e5]">
          Reward Rules & Policy
        </h2>
        <div className="space-y-4">
          <div className="p-4 bg-[#f5f5f5] rounded">
            <h3 className="text-sm text-[#1a1a1a] mb-2">Double-Sided Reward System</h3>
            <p className="text-sm text-[#666666]">
              Both the referrer and the new agent receive rewards when the referral is successful. This encourages organic growth of the agent network.
            </p>
          </div>
          <div className="p-4 bg-[#f5f5f5] rounded">
            <h3 className="text-sm text-[#1a1a1a] mb-2">First-Form Reward Logic</h3>
            <p className="text-sm text-[#666666]">
              Referral bonus is credited after the referred agent successfully completes their first form submission and receives payment.
            </p>
          </div>
          <div className="p-4 bg-[#f5f5f5] rounded">
            <h3 className="text-sm text-[#1a1a1a] mb-2">Connection to Agent App</h3>
            <p className="text-sm text-[#666666]">
              Referral statistics and earnings are visible in real-time in the agent mobile app, motivating agents to refer more users.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
