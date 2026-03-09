import { useState, useEffect } from 'react';
import { Settings, Save, DollarSign, AlertCircle } from 'lucide-react';
import {
  getFirestore,
  doc,
  getDoc,
  setDoc,
  serverTimestamp,
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

interface SettingsData {
  registrationFee: number;
  commissionType?: 'fixed' | 'percentage';
  commissionValue?: number;
  updatedAt?: any;
  updatedBy?: string;
}

export default function RegistrationSettings() {
  const [registrationFee, setRegistrationFee] = useState<number>(0);
  const [commissionType, setCommissionType] = useState<'fixed' | 'percentage'>('fixed');
  const [commissionValue, setCommissionValue] = useState<number>(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Calculate commission values for preview
  const adminCommission = commissionType === 'fixed' 
    ? commissionValue 
    : registrationFee * (commissionValue / 100);
  const remainingAmount = registrationFee - adminCommission;

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      setLoading(true);
      setError(null);
      const settingsRef = doc(db, 'settings', 'registration');
      const settingsSnap = await getDoc(settingsRef);

      if (settingsSnap.exists()) {
        const data = settingsSnap.data() as SettingsData;
        setRegistrationFee(data.registrationFee || 0);
        setCommissionType(data.commissionType || 'fixed');
        setCommissionValue(data.commissionValue || 0);
      } else {
        // Initialize with default values
        setRegistrationFee(0);
        setCommissionType('fixed');
        setCommissionValue(0);
      }
    } catch (err) {
      console.error('Error loading settings:', err);
      setError('Failed to load settings. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      setError(null);
      setSuccess(null);

      // Validation
      if (registrationFee < 0) {
        setError('Registration fee cannot be negative');
        return;
      }

      if (commissionValue < 0) {
        setError('Commission value cannot be negative');
        return;
      }

      if (commissionType === 'percentage' && commissionValue > 100) {
        setError('Commission percentage cannot exceed 100%');
        return;
      }

      // Calculate commission to validate
      const calculatedCommission = commissionType === 'fixed' 
        ? commissionValue 
        : registrationFee * (commissionValue / 100);

      if (calculatedCommission > registrationFee) {
        setError('Commission cannot exceed registration fee');
        return;
      }

      const settingsRef = doc(db, 'settings', 'registration');
      await setDoc(
        settingsRef,
        {
          registrationFee: registrationFee,
          commissionType: commissionType,
          commissionValue: commissionValue,
          updatedAt: serverTimestamp(),
          updatedBy: 'Admin', // You can replace this with actual admin user ID
        },
        { merge: true }
      );

      setSuccess('Registration settings updated successfully!');
      console.log('Settings updated:', { registrationFee, commissionType, commissionValue });
    } catch (err) {
      console.error('Error saving settings:', err);
      setError('Failed to save settings. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl text-gray-100 mb-2">Registration Settings</h1>
        <p className="text-gray-400">Configure registration fee for new agents</p>
      </div>

      {/* Status Messages */}
      {error && (
        <div className="p-4 border border-[#7f1d1d] bg-[#3b0b0b] text-[#fca5a5] rounded flex items-center gap-3">
          <AlertCircle className="w-5 h-5" />
          <span>{error}</span>
        </div>
      )}

      {success && (
        <div className="p-4 border border-[#065f46] bg-[#064e3b] text-[#6ee7b7] rounded flex items-center gap-3">
          <AlertCircle className="w-5 h-5" />
          <span>{success}</span>
        </div>
      )}

      {/* Settings Card */}
      <div className="bg-[#071018] border border-[#111318] rounded">
        <div className="px-5 py-4 border-b border-[#111318] flex items-center gap-3">
          <Settings className="w-5 h-5 text-gray-400" />
          <h2 className="text-lg text-gray-100">Registration Fee Configuration</h2>
        </div>

        <div className="p-6 space-y-6">
          {loading ? (
            <div className="text-center py-8 text-gray-400">Loading settings...</div>
          ) : (
            <>
              <div className="space-y-3">
                <label className="block text-sm text-gray-300">
                  Agent Registration Fee (₹)
                </label>
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                    <DollarSign className="w-5 h-5 text-gray-500" />
                  </div>
                  <input
                    type="number"
                    min="0"
                    step="1"
                    value={registrationFee}
                    onChange={(e) => setRegistrationFee(Number(e.target.value))}
                    className="w-full pl-12 pr-4 py-3 bg-[#0f1518] border border-[#111318] rounded text-gray-100 focus:outline-none focus:border-[#243BFF] transition-colors"
                    placeholder="Enter registration fee"
                  />
                </div>
                <p className="text-xs text-gray-500">
                  This fee will be charged when an agent completes their registration.
                </p>
              </div>

              {/* Commission Configuration Section */}
              <div className="border-t border-[#111318] pt-6 space-y-4">
                <h3 className="text-base text-gray-100 font-medium">Commission Configuration</h3>
                
                <div className="space-y-3">
                  <label className="block text-sm text-gray-300">
                    Commission Type
                  </label>
                  <select
                    value={commissionType}
                    onChange={(e) => setCommissionType(e.target.value as 'fixed' | 'percentage')}
                    className="w-full px-4 py-3 bg-[#0f1518] border border-[#111318] rounded text-gray-100 focus:outline-none focus:border-[#243BFF] transition-colors"
                  >
                    <option value="fixed">Fixed Amount</option>
                    <option value="percentage">Percentage</option>
                  </select>
                  <p className="text-xs text-gray-500">
                    Choose how commission will be calculated
                  </p>
                </div>

                <div className="space-y-3">
                  <label className="block text-sm text-gray-300">
                    Commission Value {commissionType === 'percentage' ? '(%)' : '(₹)'}
                  </label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                      <DollarSign className="w-5 h-5 text-gray-500" />
                    </div>
                    <input
                      type="number"
                      min="0"
                      max={commissionType === 'percentage' ? 100 : undefined}
                      step={commissionType === 'percentage' ? '0.1' : '1'}
                      value={commissionValue}
                      onChange={(e) => setCommissionValue(Number(e.target.value))}
                      className="w-full pl-12 pr-4 py-3 bg-[#0f1518] border border-[#111318] rounded text-gray-100 focus:outline-none focus:border-[#243BFF] transition-colors"
                      placeholder={`Enter commission ${commissionType === 'percentage' ? 'percentage' : 'amount'}`}
                    />
                  </div>
                  <p className="text-xs text-gray-500">
                    {commissionType === 'fixed' 
                      ? 'Fixed amount deducted as admin commission'
                      : 'Percentage of registration fee as commission (max 100%)'}
                  </p>
                </div>
              </div>

              {/* Preview Section */}
              <div className="bg-[#0f1518] border border-[#1a1f26] rounded p-4">
                <h3 className="text-sm text-gray-100 mb-3 font-medium">Preview</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between text-gray-400">
                    <span>Registration Fee:</span>
                    <span className="text-gray-100 font-medium">₹{registrationFee.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between text-gray-400">
                    <span>Admin Commission:</span>
                    <span className="text-blue-400 font-medium">
                      ₹{adminCommission.toFixed(2)} 
                      {commissionType === 'percentage' && ` (${commissionValue}%)`}
                    </span>
                  </div>
                  <div className="border-t border-[#1a1f26] pt-2 mt-2"></div>
                  <div className="flex justify-between">
                    <span className="text-gray-400">Remaining Amount:</span>
                    <span className={`font-medium ${remainingAmount >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                      ₹{remainingAmount.toFixed(2)}
                    </span>
                  </div>
                  {remainingAmount < 0 && (
                    <div className="mt-2 p-2 bg-red-900/20 border border-red-800/30 rounded text-xs text-red-400">
                      ⚠️ Commission exceeds registration fee
                    </div>
                  )}
                </div>
              </div>

              <div className="flex gap-3">
                <button
                  onClick={handleSave}
                  disabled={saving}
                  className="flex items-center justify-center gap-2 px-6 py-3 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {saving ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                      Saving...
                    </>
                  ) : (
                    <>
                      <Save className="w-4 h-4" />
                      Save Settings
                    </>
                  )}
                </button>

                <button
                  onClick={loadSettings}
                  disabled={saving || loading}
                  className="px-6 py-3 bg-[#0f1518] border border-[#111318] text-gray-300 rounded hover:bg-[#13171a] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Reset
                </button>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Information Panel */}
      <div className="bg-[#071018] border border-[#111318] rounded p-5">
        <h3 className="text-sm text-gray-100 mb-3 font-medium flex items-center gap-2">
          <AlertCircle className="w-4 h-4 text-blue-500" />
          How it works
        </h3>
        <ul className="space-y-2 text-sm text-gray-400">
          <li className="flex gap-2">
            <span className="text-blue-500">•</span>
            <span>When set to 0, agent registration is completely free</span>
          </li>
          <li className="flex gap-2">
            <span className="text-blue-500">•</span>
            <span>When a fee is set, agents must pay via Razorpay during registration</span>
          </li>
          <li className="flex gap-2">
            <span className="text-blue-500">•</span>
            <span>Admin commission is automatically calculated and recorded in the transaction</span>
          </li>
          <li className="flex gap-2">
            <span className="text-blue-500">•</span>
            <span><strong>Fixed Commission:</strong> A fixed amount (e.g., ₹100) is deducted from each registration</span>
          </li>
          <li className="flex gap-2">
            <span className="text-blue-500">•</span>
            <span><strong>Percentage Commission:</strong> A percentage (e.g., 10%) of the registration fee is calculated</span>
          </li>
          <li className="flex gap-2">
            <span className="text-blue-500">•</span>
            <span>The payment is processed during the registration flow after address details</span>
          </li>
          <li className="flex gap-2">
            <span className="text-blue-500">•</span>
            <span>Commission validation ensures it never exceeds the registration fee</span>
          </li>
        </ul>
      </div>
    </div>
  );
}
