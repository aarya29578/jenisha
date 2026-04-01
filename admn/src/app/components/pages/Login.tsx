import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock, User, AlertCircle, Shield } from 'lucide-react';
import { authService } from '@/services/authService';

interface LoginProps {
  onLogin: () => void;
}

export default function Login({ onLogin }: LoginProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [selectedRole, setSelectedRole] = useState<'admin' | 'super_admin'>('admin');
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!acceptedTerms) {
      setError('Please agree to the Terms & Conditions to continue.');
      return;
    }

    setLoading(true);

    try {
      // STEP 1: Authenticate with Firebase
      await authService.login(email, password);
      
      // STEP 2: Fetch role from Firestore (handled by authService)
      const currentUser = authService.getCurrentUser();
      
      // STEP 3: Validate selected role against Firestore role
      if (!currentUser) {
        throw new Error('Failed to fetch user data.');
      }

      const firestoreRole = currentUser.role;

      // STEP 4: Check if selected role matches Firestore role
      if (selectedRole !== firestoreRole) {
        // Role mismatch - logout and show error
        await authService.logout();
        throw new Error(`Incorrect role selected. You are logged in as "${firestoreRole.replace('_', ' ').toUpperCase()}".`);
      }

      // STEP 5: Role matches - allow login
      console.log('✅ Role validated:', firestoreRole);
      onLogin();
    } catch (err: any) {
      console.error('Login error:', err);
      setError(err.message || 'Login failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo/Header */}
        <div className="text-center mb-8">
          <div className="inline-block p-4 bg-[#4C4CFF] rounded mb-4">
            <Lock className="w-12 h-12 text-white" />
          </div>
          <h1 className="text-2xl text-[#1a1a1a] mb-2">Admin Portal</h1>
          <p className="text-[#666666]">Agent Management System</p>
        </div>

        {/* Login Card */}
        <div className="bg-white border-2 border-[#e5e5e5] rounded p-8">
          <h2 className="text-xl text-[#1a1a1a] mb-6">Secure Admin Login</h2>
          
          {/* Error Message */}
          {error && (
            <div className="mb-5 p-4 bg-red-50 border border-red-200 rounded flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
              <p className="text-sm text-red-800">{error}</p>
            </div>
          )}
          
          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Role Selection */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">
                Login As
              </label>
              <div className="relative">
                <Shield className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-[#666666]" />
                <select
                  value={selectedRole}
                  onChange={(e) => setSelectedRole(e.target.value as 'admin' | 'super_admin')}
                  className="w-full pl-11 pr-4 py-3 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF] appearance-none bg-white"
                  disabled={loading}
                >
                  <option value="admin">Admin (Limited Access)</option>
                  <option value="super_admin">Super Admin (Full Access)</option>
                </select>
                <div className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
                  <svg className="w-5 h-5 text-[#666666]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
              </div>
              <p className="text-xs text-[#666666] mt-1">
                Select the role that matches your account
              </p>
            </div>

            {/* Email Field */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">
                Email
              </label>
              <div className="relative">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-[#666666]" />
                <input
                  type="text"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full pl-11 pr-4 py-3 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                  placeholder="Enter email"
                  required
                  disabled={loading}
                />
              </div>
            </div>

            {/* Password Field */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-[#666666]" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-11 pr-4 py-3 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                  placeholder="Enter password"
                  required
                  disabled={loading}
                />
              </div>
            </div>

            {/* Terms Agreement */}
            <div className="flex items-start gap-3">
              <input
                id="acceptTerms"
                type="checkbox"
                checked={acceptedTerms}
                onChange={(e) => setAcceptedTerms(e.target.checked)}
                className="mt-1 h-4 w-4 rounded border-[#d1d5db] text-[#4C4CFF] focus:ring-[#4C4CFF]"
                disabled={loading}
              />
              <label htmlFor="acceptTerms" className="text-sm text-[#666666]">
                I agree to the{' '}
                <button
                  type="button"
                  onClick={() => navigate('/terms')}
                  className="font-semibold text-[#4C4CFF] hover:text-[#3737d3]"
                >
                  Terms & Conditions
                </button>
              </label>
            </div>

            {/* Submit Button */}
            <button
              type="submit"
              disabled={loading || !acceptedTerms}
              className="w-full bg-[#4C4CFF] text-white py-3 rounded hover:bg-[#3d3dcc] transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading ? (
                <>
                  <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  Signing in...
                </>
              ) : (
                'Login to Admin Panel'
              )}
            </button>

            <div className="mt-4 text-center text-sm text-[#666666]">
              By continuing, you agree to our{' '}
              <button
                type="button"
                onClick={() => navigate('/terms')}
                className="font-semibold text-[#4C4CFF] hover:text-[#3737d3]"
              >
                Terms & Conditions
              </button>
            </div>
          </form>

          {/* Info Notice */}
          <div className="mt-6 p-3 bg-[#f5f5f5] border-l-4 border-[#4C4CFF] rounded">
            <p className="text-xs text-[#666666]">
              This is a secure government portal. Unauthorized access is prohibited and will be logged.
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center mt-6">
          <p className="text-xs text-[#999999]">
            Government of India • Agent Management System
          </p>
        </div>
      </div>
    </div>
  );
}
