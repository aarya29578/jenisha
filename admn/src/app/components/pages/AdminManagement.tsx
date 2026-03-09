import { useState, useEffect } from 'react';
import { UserPlus, Users, Shield, Trash2, CheckCircle, XCircle, Key } from 'lucide-react';
import {
  getFirestore,
  collection,
  query,
  orderBy,
  onSnapshot,
  doc,
  deleteDoc,
  setDoc,
  updateDoc,
  getDocs,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { getFunctions, httpsCallable } from 'firebase/functions';
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
// Explicitly set region to match Firebase Functions deployment (default: us-central1)
const functions = getFunctions(firebaseApp, 'us-central1');

interface AdminUser {
  id: string;
  name: string;
  email: string;
  role: 'super_admin' | 'admin' | 'moderator';
  createdAt: Timestamp;
  createdBy: string;
  allowedServices?: string[];
}

export default function AdminManagement() {
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [firestoreError, setFirestoreError] = useState<string | null>(null);

  // Form state
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    confirmPassword: '',
    role: 'admin' as 'admin' | 'super_admin' | 'moderator',
  });

  const [errors, setErrors] = useState<Record<string, string>>({});

  const currentUser = authService.getCurrentUser();

  // Give Access modal state
  const [showAccessModal, setShowAccessModal] = useState(false);
  const [accessTargetAdmin, setAccessTargetAdmin] = useState<AdminUser | null>(null);
  const [allServices, setAllServices] = useState<{ id: string; name: string }[]>([]);
  const [selectedServices, setSelectedServices] = useState<string[]>([]);
  const [loadingServices, setLoadingServices] = useState(false);
  const [savingAccess, setSavingAccess] = useState(false);

  const openAccessModal = async (admin: AdminUser) => {
    setAccessTargetAdmin(admin);
    setShowAccessModal(true);
    setLoadingServices(true);
    try {
      const snap = await getDocs(collection(db, 'services'));
      const items = snap.docs
        .map((d) => ({ id: d.id, name: (d.data().name as string) || d.id }))
        .sort((a, b) => a.name.localeCompare(b.name));
      setAllServices(items);
      setSelectedServices(Array.isArray(admin.allowedServices) ? admin.allowedServices : []);
    } catch (e) {
      console.error('Error fetching services:', e);
    } finally {
      setLoadingServices(false);
    }
  };

  const handleSaveAccess = async () => {
    if (!accessTargetAdmin) return;
    setSavingAccess(true);
    try {
      await updateDoc(doc(db, 'admin_users', accessTargetAdmin.id), {
        allowedServices: selectedServices,
      });
      alert(`Service access updated for ${accessTargetAdmin.name}`);
      setShowAccessModal(false);
    } catch (e) {
      console.error('Error saving access:', e);
      alert('Failed to save access. Please try again.');
    } finally {
      setSavingAccess(false);
    }
  };

  useEffect(() => {
    console.log('🔵 AdminManagement: Setting up Firestore listener...');
    
    // Real-time listener for admin users
    const q = query(collection(db, 'admin_users'), orderBy('createdAt', 'desc'));
    
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        console.log('✅ Firestore snapshot received:', snapshot.size, 'admins');
        const adminList: AdminUser[] = [];
        snapshot.forEach((doc) => {
          const data = doc.data();
          console.log('  Admin doc:', doc.id, data);
          adminList.push({
            id: doc.id,
            name: data.name || 'Unknown',
            email: data.email || '',
            role: data.role || 'admin',
            createdAt: data.createdAt,
            createdBy: data.createdBy || '',
            allowedServices: Array.isArray(data.allowedServices) ? data.allowedServices : [],
          });
        });
        setAdmins(adminList);
        setLoading(false);
        setFirestoreError(null);
      },
      (error) => {
        console.error('❌ Firestore error:', error);
        setFirestoreError(error.message);
        setLoading(false);
      }
    );

    return () => {
      console.log('🔵 AdminManagement: Cleaning up Firestore listener');
      unsubscribe();
    };
  }, []);

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {};

    // Name validation
    if (!formData.name.trim()) {
      newErrors.name = 'Name is required';
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!emailRegex.test(formData.email)) {
      newErrors.email = 'Invalid email format';
    }

    // Check for duplicate email
    if (admins.some(admin => admin.email.toLowerCase() === formData.email.toLowerCase())) {
      newErrors.email = 'Email already exists';
    }

    // Password validation
    if (!formData.password) {
      newErrors.password = 'Password is required';
    } else if (formData.password.length < 6) {
      newErrors.password = 'Password must be at least 6 characters';
    }

    // Confirm password validation
    if (formData.password !== formData.confirmPassword) {
      newErrors.confirmPassword = 'Passwords do not match';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  /**
   * Fallback: create a Firebase Auth user via the Identity Toolkit REST API.
   * This does NOT affect the current admin's auth session because it bypasses
   * the Firebase client SDK auth state manager.
   */
  const createAuthUserViaRest = async (email: string, password: string): Promise<string> => {
    const apiKey = firebaseConfig.apiKey;
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      }
    );
    const json = await response.json();
    if (!response.ok) {
      const msg = json?.error?.message || 'Failed to create auth account';
      if (msg === 'EMAIL_EXISTS') throw new Error('This email is already registered.');
      if (msg === 'WEAK_PASSWORD') throw new Error('Password is too weak. Use at least 6 characters.');
      throw new Error(msg);
    }
    return json.localId as string; // The new user's UID
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    setSubmitting(true);

    let createdViaFunction = false;

    try {
      // ── Attempt 1: Firebase callable cloud function ──────────────────────
      console.log('🔵 Attempting Cloud Function: createAdminUser');
      try {
        const createAdminUser = httpsCallable(functions, 'createAdminUser');
        const result = await createAdminUser({
          name: formData.name,
          email: formData.email,
          password: formData.password,
          role: formData.role,
        });
        const data = result.data as { success: boolean; uid: string; email: string; role: string; message: string };
        console.log('✅ Cloud Function success:', data);
        createdViaFunction = true;
        alert(data.message || `Admin "${formData.name}" created successfully!`);
      } catch (fnError: any) {
        // If it's a CORS / network / internal error → fall through to REST fallback
        const isCorsOrInternal =
          fnError?.code === 'functions/internal' ||
          fnError?.code === 'functions/unavailable' ||
          fnError?.message?.toLowerCase().includes('cors') ||
          fnError?.message?.toLowerCase().includes('network') ||
          fnError?.message?.toLowerCase().includes('failed to fetch');

        // Surface real permission errors immediately (don't fallback)
        if (!isCorsOrInternal) {
          throw fnError;
        }

        console.warn('⚠️ Cloud Function failed, using REST fallback:', fnError.message);
      }

      // ── Attempt 2: REST API fallback (no session impact) ─────────────────
      if (!createdViaFunction) {
        console.log('🔵 Creating auth user via REST API...');
        const newUid = await createAuthUserViaRest(formData.email, formData.password);
        console.log('✅ Auth user created, UID:', newUid);

        // Write admin_users document using the super-admin's Firestore session
        await setDoc(doc(db, 'admin_users', newUid), {
          name: formData.name,
          email: formData.email,
          role: formData.role,
          createdAt: serverTimestamp(),
          createdBy: currentUser?.uid || '',
          updatedAt: serverTimestamp(),
        });
        console.log('✅ Firestore admin_users doc created');
        alert(`Admin "${formData.name}" created successfully!`);
      }

      // Clear form and close
      setFormData({
        name: '',
        email: '',
        password: '',
        confirmPassword: '',
        role: 'admin',
      });
      setShowForm(false);
      setErrors({});

      // Note: No need to reload the page!
      // The Firestore listener will automatically update the admin list
      // Super Admin stays logged in

    } catch (error: any) {
      console.error('❌ Error creating admin:', error);
      console.error('❌ Error code:', error.code);
      console.error('❌ Error message:', error.message);
      console.error('❌ Error details:', error.details);
      
      let errorMessage = 'Failed to create admin. Please try again.';
      
      // Handle Firebase Functions errors
      if (error.code === 'functions/unauthenticated') {
        errorMessage = '🔒 You must be logged in to create admin users.';
      } else if (error.code === 'functions/permission-denied') {
        errorMessage = '🚫 Only Super Admins can create new admin users.';
      } else if (error.code === 'functions/invalid-argument') {
        errorMessage = '⚠️ ' + (error.message || 'Invalid input data. Please check all fields.');
      } else if (error.code === 'functions/already-exists') {
        errorMessage = '⚠️ This email is already registered in Firebase Authentication.';
      } else if (error.code === 'functions/internal') {
        errorMessage = '❌ ' + (error.message || 'Internal server error. Please try again.');
      } else if (error.code === 'functions/not-found') {
        errorMessage = '❌ Cloud Function not found. Please ensure the function is deployed:\n\nRun: firebase deploy --only functions';
      } else if (error.code === 'functions/unavailable') {
        errorMessage = '❌ Cloud Function is unavailable. Check your internet connection or try again later.';
      } else if (error.message) {
        errorMessage = error.message;
      }
      
      alert(errorMessage);
      
      // Additional help for deployment issues
      if (error.code === 'functions/not-found') {
        console.error('🔧 DEPLOYMENT REQUIRED:');
        console.error('   cd d:\\jenisha\\admn');
        console.error('   firebase deploy --only functions');
      }
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (adminId: string, adminName: string) => {
    if (!confirm(`Are you sure you want to delete admin "${adminName}"?\n\nNote: This will only remove from admin_users collection. Firebase Auth account will remain.`)) {
      return;
    }

    try {
      await deleteDoc(doc(db, 'admin_users', adminId));
      alert(`Admin "${adminName}" removed successfully.`);
    } catch (error) {
      console.error('Error deleting admin:', error);
      alert('Failed to delete admin.');
    }
  };

  const formatDate = (timestamp: Timestamp | null | undefined) => {
    if (!timestamp) return '—';
    return timestamp.toDate().toLocaleDateString('en-IN', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getRoleBadge = (role: string) => {
    const styles = {
      super_admin: 'bg-purple-100 text-purple-800 border-purple-300',
      admin: 'bg-blue-100 text-blue-800 border-blue-300',
      moderator: 'bg-green-100 text-green-800 border-green-300',
    };

    const icons = {
      super_admin: <Shield className="w-3 h-3" />,
      admin: <Users className="w-3 h-3" />,
      moderator: <CheckCircle className="w-3 h-3" />,
    };

    return (
      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border ${styles[role as keyof typeof styles] || styles.admin}`}>
        {icons[role as keyof typeof icons]}
        {role.replace('_', ' ').toUpperCase()}
      </span>
    );
  };

  console.log('🔵 AdminManagement render:', { loading, adminsCount: admins.length, showForm, firestoreError });

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-[#243BFF]/30 border-t-[#243BFF] rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-gray-400">Loading admins...</p>
        </div>
      </div>
    );
  }

  if (firestoreError) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center max-w-md">
          <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <XCircle className="w-8 h-8 text-red-600" />
          </div>
          <h2 className="text-xl font-bold text-gray-100 mb-2">Firestore Error</h2>
          <p className="text-gray-400 mb-4">{firestoreError}</p>
          <button
            onClick={() => window.location.reload()}
            className="px-4 py-2 bg-[#243BFF] text-white rounded-lg hover:bg-[#1e32cc] transition-colors"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  const isSuperAdmin = currentUser?.role === 'super_admin';

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-100">Admin Management</h1>
          <p className="text-gray-400 mt-1">Manage admin users and their roles</p>
        </div>
        {isSuperAdmin && (
          <button
            onClick={() => setShowForm(!showForm)}
            className="flex items-center gap-2 px-4 py-2 bg-[#243BFF] text-white rounded-lg hover:bg-[#1e32cc] transition-colors"
          >
            <UserPlus className="w-5 h-5" />
            Create New Admin
          </button>
        )}
      </div>

      {/* Role notice for non-super-admins */}
      {!isSuperAdmin && (
        <div className="bg-yellow-50 border border-yellow-300 rounded-lg p-4 flex items-center gap-3">
          <Shield className="w-5 h-5 text-yellow-600 flex-shrink-0" />
          <p className="text-sm text-yellow-800">
            Only <strong>Super Admins</strong> can create new admin users. You can view the list below.
          </p>
        </div>
      )}

      {/* Create Admin Form — only for super admins */}
      {showForm && isSuperAdmin && (
        <div className="bg-[#0f1720] border border-[#1f2937] rounded-lg p-6">
          <h2 className="text-xl font-semibold text-gray-100 mb-4">Create New Admin</h2>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Name */}
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Name <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  className="w-full px-4 py-2 bg-[#1a2332] border border-[#2a3441] rounded-lg text-gray-100 focus:outline-none focus:ring-2 focus:ring-[#243BFF]"
                  placeholder="Enter admin name"
                />
                {errors.name && <p className="text-red-500 text-sm mt-1">{errors.name}</p>}
              </div>

              {/* Email */}
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Email <span className="text-red-500">*</span>
                </label>
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  className="w-full px-4 py-2 bg-[#1a2332] border border-[#2a3441] rounded-lg text-gray-100 focus:outline-none focus:ring-2 focus:ring-[#243BFF]"
                  placeholder="admin@example.com"
                />
                {errors.email && <p className="text-red-500 text-sm mt-1">{errors.email}</p>}
              </div>

              {/* Password */}
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Password <span className="text-red-500">*</span>
                </label>
                <input
                  type="password"
                  value={formData.password}
                  onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                  className="w-full px-4 py-2 bg-[#1a2332] border border-[#2a3441] rounded-lg text-gray-100 focus:outline-none focus:ring-2 focus:ring-[#243BFF]"
                  placeholder="Minimum 6 characters"
                />
                {errors.password && <p className="text-red-500 text-sm mt-1">{errors.password}</p>}
              </div>

              {/* Confirm Password */}
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Confirm Password <span className="text-red-500">*</span>
                </label>
                <input
                  type="password"
                  value={formData.confirmPassword}
                  onChange={(e) => setFormData({ ...formData, confirmPassword: e.target.value })}
                  className="w-full px-4 py-2 bg-[#1a2332] border border-[#2a3441] rounded-lg text-gray-100 focus:outline-none focus:ring-2 focus:ring-[#243BFF]"
                  placeholder="Re-enter password"
                />
                {errors.confirmPassword && <p className="text-red-500 text-sm mt-1">{errors.confirmPassword}</p>}
              </div>

              {/* Role */}
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-300 mb-2">
                  Role <span className="text-red-500">*</span>
                </label>
                <select
                  value={formData.role}
                  onChange={(e) => setFormData({ ...formData, role: e.target.value as 'admin' | 'super_admin' | 'moderator' })}
                  className="w-full px-4 py-2 bg-[#1a2332] border border-[#2a3441] rounded-lg text-gray-100 focus:outline-none focus:ring-2 focus:ring-[#243BFF]"
                >
                  <option value="admin">Admin (Limited Access)</option>
                  <option value="super_admin">Super Admin (Full Access)</option>
                  <option value="moderator">Moderator (Read Only)</option>
                </select>
                <p className="text-gray-400 text-xs mt-1">
                  Admin: Dashboard, Agent Approval, Certificate Generation | Super Admin: All Features
                </p>
              </div>
            </div>

            {/* Buttons */}
            <div className="flex gap-3 pt-4">
              <button
                type="submit"
                disabled={submitting}
                className="flex items-center gap-2 px-6 py-2 bg-[#243BFF] text-white rounded-lg hover:bg-[#1e32cc] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {submitting ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Creating...
                  </>
                ) : (
                  <>
                    <UserPlus className="w-4 h-4" />
                    Create Admin
                  </>
                )}
              </button>
              <button
                type="button"
                onClick={() => {
                  setShowForm(false);
                  setFormData({ name: '', email: '', password: '', confirmPassword: '', role: 'admin' });
                  setErrors({});
                }}
                className="px-6 py-2 bg-gray-700 text-gray-200 rounded-lg hover:bg-gray-600 transition-colors"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Admin List */}
      <div className="bg-[#0f1720] border border-[#1f2937] rounded-lg overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-[#1a2332] border-b border-[#2a3441]">
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Name</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Email</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Role</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Created</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#2a3441]">
              {admins.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center text-gray-400">
                    No admins found. Create your first admin above.
                  </td>
                </tr>
              ) : (
                admins.map((admin) => (
                  <tr key={admin.id} className="hover:bg-[#1a2332] transition-colors">
                    <td className="px-6 py-4 text-sm text-gray-200">{admin.name}</td>
                    <td className="px-6 py-4 text-sm text-gray-300">{admin.email}</td>
                    <td className="px-6 py-4 text-sm">{getRoleBadge(admin.role)}</td>
                    <td className="px-6 py-4 text-sm text-gray-400">{formatDate(admin.createdAt)}</td>
                    <td className="px-6 py-4 text-sm">
                      <div className="flex items-center gap-2">
                        {currentUser?.role === 'super_admin' && admin.role === 'admin' && (
                          <button
                            onClick={() => openAccessModal(admin)}
                            className="flex items-center gap-1 px-3 py-1 text-blue-400 hover:bg-blue-400/10 rounded transition-colors"
                          >
                            <Key className="w-4 h-4" />
                            Give Access
                          </button>
                        )}
                        {admin.id !== currentUser?.uid ? (
                          <button
                            onClick={() => handleDelete(admin.id, admin.name)}
                            className="flex items-center gap-1 px-3 py-1 text-red-400 hover:bg-red-400/10 rounded transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
                            Delete
                          </button>
                        ) : (
                          <span className="text-gray-500 text-xs">(Current User)</span>
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

      {/* Give Access Modal */}
      {showAccessModal && accessTargetAdmin && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50">
          <div className="bg-[#0f1720] border border-[#1f2937] rounded-lg w-full max-w-md p-6 shadow-xl">
            <h2 className="text-lg font-semibold text-gray-100 mb-1">Give Service Access</h2>
            <p className="text-sm text-gray-400 mb-4">
              Select services for <strong className="text-gray-200">{accessTargetAdmin.name}</strong>
            </p>

            {loadingServices ? (
              <div className="flex items-center justify-center py-8">
                <div className="w-8 h-8 border-4 border-[#243BFF]/30 border-t-[#243BFF] rounded-full animate-spin"></div>
              </div>
            ) : (
              <>
                {/* Select All */}
                <div className="mb-3 pb-3 border-b border-[#2a3441]">
                  <label className="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={allServices.length > 0 && selectedServices.length === allServices.length}
                      onChange={(e) =>
                        setSelectedServices(e.target.checked ? allServices.map((s) => s.id) : [])
                      }
                      className="w-4 h-4 accent-[#243BFF]"
                    />
                    <span className="text-sm font-medium text-gray-200">Select All</span>
                  </label>
                </div>

                {/* Service list */}
                <div className="space-y-2 max-h-64 overflow-y-auto">
                  {allServices.length === 0 ? (
                    <p className="text-gray-400 text-sm">No services found.</p>
                  ) : (
                    allServices.map((service) => (
                      <label
                        key={service.id}
                        className="flex items-center gap-2 cursor-pointer hover:bg-[#1a2332] px-2 py-1 rounded"
                      >
                        <input
                          type="checkbox"
                          checked={selectedServices.includes(service.id)}
                          onChange={(e) =>
                            setSelectedServices((prev) =>
                              e.target.checked
                                ? [...prev, service.id]
                                : prev.filter((id) => id !== service.id)
                            )
                          }
                          className="w-4 h-4 accent-[#243BFF]"
                        />
                        <span className="text-sm text-gray-200">{service.name}</span>
                      </label>
                    ))
                  )}
                </div>
              </>
            )}

            <div className="flex gap-3 mt-6">
              <button
                onClick={handleSaveAccess}
                disabled={savingAccess || loadingServices}
                className="flex items-center gap-2 px-5 py-2 bg-[#243BFF] text-white rounded-lg hover:bg-[#1e32cc] transition-colors disabled:opacity-50"
              >
                {savingAccess ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                    Saving...
                  </>
                ) : (
                  'Save'
                )}
              </button>
              <button
                onClick={() => setShowAccessModal(false)}
                className="px-5 py-2 bg-gray-700 text-gray-200 rounded-lg hover:bg-gray-600 transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Info Box */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div className="flex gap-3">
          <Shield className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-sm font-semibold text-blue-900 mb-1">Cloud Function Architecture</h3>
            <p className="text-sm text-blue-800">
              Admin creation uses Firebase Cloud Functions with Admin SDK. This ensures Super Admins stay logged in 
              without session interruption. Only Super Admins can access this page and create new admins.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
