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
            status: data.status === 'approved' ? 'Approved' : 
                    data.status === 'rejected' ? 'Rejected' : 
                    data.status === 'blocked' ? 'Blocked' : 'Pending',
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
        <span className="px-4 py-2 bg-[#08310b] text-white rounded text-sm">
          {agent.status}
        </span>
      </div>

        {/* Action Buttons */}
        <div className="flex gap-3">
          <button 
            className="flex items-center gap-2 px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={agent.status === 'Approved'}
          >
            <Check className="w-4 h-4" />
            <span className="text-sm">Approve Agent</span>
          </button>
          <button 
            className="flex items-center gap-2 px-4 py-2 bg-[#F44336] text-white rounded hover:bg-[#d32f2f] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={agent.status === 'Rejected'}
          >
            <X className="w-4 h-4" />
            <span className="text-sm">Reject Agent</span>
          </button>
          <button 
            className="flex items-center gap-2 px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={agent.status === 'Blocked'}
          >
            <Ban className="w-4 h-4" />
            <span className="text-sm">Block Agent</span>
          </button>
        </div>

      {/* Details Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Personal Details */}
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318]">
            Personal Details
          </h2>
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
          <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318]">
            KYC Documents
          </h2>
          <div className="space-y-4">
            <div className="border border-[#111318] rounded p-4 bg-[#071018]">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-100">Aadhaar Card</p>
                <span className={`px-2 py-1 rounded text-xs ${
                  agent.aadharUrl 
                    ? 'bg-[#08310b] text-white' 
                    : 'bg-[#0f1518] text-gray-400'
                }`}>
                  {agent.aadharUrl ? 'Verified' : 'Pending'}
                </span>
              </div>
              <p className="text-xs text-gray-400">{agent.aadhaar}</p>
              {agent.aadharUrl && (
                <a 
                  href={agent.aadharUrl} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="mt-2 inline-block text-xs text-[#243BFF] hover:underline"
                >
                  View Document
                </a>
              )}
            </div>
            <div className="border border-[#111318] rounded p-4 bg-[#071018]">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-100">PAN Card</p>
                <span className={`px-2 py-1 rounded text-xs ${
                  agent.panUrl 
                    ? 'bg-[#08310b] text-white' 
                    : 'bg-[#0f1518] text-gray-400'
                }`}>
                  {agent.panUrl ? 'Verified' : 'Pending'}
                </span>
              </div>
              <p className="text-xs text-gray-400">{agent.pan}</p>
              {agent.panUrl && (
                <a 
                  href={agent.panUrl} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="mt-2 inline-block text-xs text-[#243BFF] hover:underline"
                >
                  View Document
                </a>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Wallet & Referral Info */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Wallet Information */}
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
            <div className="text-center text-xs text-gray-400 py-4">
              Transaction history coming soon
            </div>
          </div>
        </div>

        {/* Referral Stats */}
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-lg text-gray-100 mb-4 pb-3 border-b border-[#111318] flex items-center gap-2">
            <UsersIcon className="w-5 h-5 text-gray-100" />
            Referral Statistics
          </h2>
          <div className="space-y-4">
            <div>
              <p className="text-sm text-gray-400 mb-2">Referral Code</p>
              <div className="flex items-center gap-2">
                <code className="px-3 py-2 bg-[#0f1518] rounded text-gray-100 text-sm">
                  {agent.referralCode}
                </code>
                <button className="px-3 py-2 border border-[#111318] rounded text-xs text-gray-400 hover:bg-[#0f1518] transition-colors">
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
