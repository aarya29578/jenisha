import { User, Lock, Shield, Camera, Save, Eye, EyeOff, CheckCircle, AlertCircle } from 'lucide-react';
import { useState, useEffect, useRef } from 'react';
import {
  getAuth,
  updatePassword,
  reauthenticateWithCredential,
  EmailAuthProvider,
} from 'firebase/auth';
import {
  getFirestore,
  doc,
  onSnapshot,
  updateDoc,
  serverTimestamp,
} from 'firebase/firestore';
import { getStorage, ref, uploadBytes, getDownloadURL } from 'firebase/storage';
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

const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
const db  = getFirestore(app);
const storage = getStorage(app);

type Toast = { type: 'success' | 'error'; message: string } | null;

export default function AdminProfile() {
  const currentUser = authService.getCurrentUser();
  const uid = getAuth(app).currentUser?.uid ?? currentUser?.uid ?? '';

  // ── Profile fields ──────────────────────────────────────────────────────
  const [name, setName]               = useState(currentUser?.name ?? '');
  const [photoURL, setPhotoURL]       = useState<string>('');
  const [role, setRole]               = useState(currentUser?.role ?? '');
  const [email]                       = useState(currentUser?.email ?? '');
  const [createdAt, setCreatedAt]     = useState<string>('—');
  const [savingProfile, setSavingProfile] = useState(false);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const photoInputRef = useRef<HTMLInputElement>(null);

  // ── Password fields ─────────────────────────────────────────────────────
  const [currentPassword, setCurrentPassword]   = useState('');
  const [newPassword, setNewPassword]           = useState('');
  const [confirmPassword, setConfirmPassword]   = useState('');
  const [showCurrentPw, setShowCurrentPw]       = useState(false);
  const [showNewPw, setShowNewPw]               = useState(false);
  const [showConfirmPw, setShowConfirmPw]       = useState(false);
  const [savingPassword, setSavingPassword]     = useState(false);

  // ── Toast notification ──────────────────────────────────────────────────
  const [toast, setToast] = useState<Toast>(null);

  const showToast = (type: 'success' | 'error', message: string) => {
    setToast({ type, message });
    setTimeout(() => setToast(null), 3500);
  };

  // ── Load live data from Firestore ───────────────────────────────────────
  useEffect(() => {
    if (!uid) return;
    const unsub = onSnapshot(doc(db, 'admin_users', uid), (snap) => {
      if (!snap.exists()) return;
      const data = snap.data();
      setName(data.name ?? '');
      setRole(data.role ?? '');
      setPhotoURL(data.photoURL ?? '');
      if (data.createdAt?.toDate) {
        setCreatedAt(
          data.createdAt.toDate().toLocaleString('en-IN', {
            day: '2-digit', month: 'short', year: 'numeric',
            hour: '2-digit', minute: '2-digit',
          })
        );
      }
    });
    return unsub;
  }, [uid]);

  // ── Avatar helpers ──────────────────────────────────────────────────────
  const initials = name
    .split(' ')
    .filter(Boolean)
    .map((w) => w[0].toUpperCase())
    .slice(0, 2)
    .join('');

  const roleLabel = (r: string) =>
    r === 'super_admin' ? 'Super Admin' : r === 'moderator' ? 'Moderator' : 'Admin';

  // ── Upload profile photo ────────────────────────────────────────────────
  const handlePhotoChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !uid) return;
    const allowed = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    if (!allowed.includes(file.type)) {
      showToast('error', 'Only PNG, JPG and WEBP images are allowed.');
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      showToast('error', 'Image must be under 2 MB.');
      return;
    }
    setUploadingPhoto(true);
    try {
      const storageRef = ref(storage, `admin_profiles/${uid}`);
      await uploadBytes(storageRef, file);
      const url = await getDownloadURL(storageRef);
      await updateDoc(doc(db, 'admin_users', uid), { photoURL: url, updatedAt: serverTimestamp() });
      setPhotoURL(url);
      showToast('success', 'Profile photo updated.');
    } catch (err: any) {
      showToast('error', err.message ?? 'Upload failed.');
    } finally {
      setUploadingPhoto(false);
      e.target.value = '';
    }
  };

  // ── Save name ───────────────────────────────────────────────────────────
  const handleSaveProfile = async () => {
    if (!name.trim()) { showToast('error', 'Name cannot be empty.'); return; }
    if (!uid) return;
    setSavingProfile(true);
    try {
      await updateDoc(doc(db, 'admin_users', uid), {
        name: name.trim(),
        updatedAt: serverTimestamp(),
      });
      showToast('success', 'Profile updated successfully.');
    } catch (err: any) {
      showToast('error', err.message ?? 'Failed to save profile.');
    } finally {
      setSavingProfile(false);
    }
  };

  // ── Change password ─────────────────────────────────────────────────────
  const handleChangePassword = async () => {
    if (!currentPassword) { showToast('error', 'Enter your current password.'); return; }
    if (newPassword.length < 6) { showToast('error', 'New password must be at least 6 characters.'); return; }
    if (newPassword !== confirmPassword) { showToast('error', 'Passwords do not match.'); return; }

    setSavingPassword(true);
    try {
      const auth = getAuth(app);
      const user = auth.currentUser;
      if (!user || !user.email) throw new Error('No authenticated user found. Please log in again.');
      const credential = EmailAuthProvider.credential(user.email, currentPassword);
      await reauthenticateWithCredential(user, credential);
      await updatePassword(user, newPassword);
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      showToast('success', 'Password changed successfully.');
    } catch (err: any) {
      if (err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
        showToast('error', 'Current password is incorrect.');
      } else if (err.code === 'auth/too-many-requests') {
        showToast('error', 'Too many attempts. Try again later.');
      } else {
        showToast('error', err.message ?? 'Failed to change password.');
      }
    } finally {
      setSavingPassword(false);
    }
  };

  const PwInput = ({
    label, value, onChange, show, toggle, placeholder,
  }: {
    label: string; value: string; onChange: (v: string) => void;
    show: boolean; toggle: () => void; placeholder: string;
  }) => (
    <div>
      <label className="block text-sm text-[#666666] mb-2">{label}</label>
      <div className="relative">
        <input
          type={show ? 'text' : 'password'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          className="w-full px-4 py-2 pr-10 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
        />
        <button
          type="button"
          onClick={toggle}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-[#999]"
        >
          {show ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
        </button>
      </div>
    </div>
  );

  return (
    <div className="space-y-6">
      {/* Toast */}
      {toast && (
        <div
          className={`fixed top-5 right-5 z-50 flex items-center gap-3 px-5 py-3 rounded-lg shadow-xl text-white text-sm transition-all
            ${toast.type === 'success' ? 'bg-[#4CAF50]' : 'bg-[#F44336]'}`}
        >
          {toast.type === 'success'
            ? <CheckCircle className="w-4 h-4 flex-shrink-0" />
            : <AlertCircle className="w-4 h-4 flex-shrink-0" />}
          {toast.message}
        </div>
      )}

      <div>
        <h1 className="text-2xl text-[#1a1a1a] mb-2">Admin Account & Security</h1>
        <p className="text-[#666666]">Manage your admin account settings</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* ── Left / main column ── */}
        <div className="lg:col-span-2 space-y-6">

          {/* Profile Photo + Info ──────────────────────────────────────── */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
            <div className="flex items-center gap-3 mb-5 pb-4 border-b-2 border-[#e5e5e5]">
              <User className="w-5 h-5 text-[#4C4CFF]" />
              <h2 className="text-lg text-[#1a1a1a]">Profile Information</h2>
            </div>

            {/* Avatar upload */}
            <div className="flex items-center gap-5 mb-6">
              <div className="relative">
                {photoURL ? (
                  <img
                    src={photoURL}
                    alt="Profile"
                    className="w-20 h-20 rounded-full object-cover border-2 border-[#e5e5e5]"
                  />
                ) : (
                  <div className="w-20 h-20 rounded-full bg-[#4C4CFF] flex items-center justify-center text-white text-2xl font-bold select-none">
                    {initials || <User className="w-8 h-8" />}
                  </div>
                )}
                <button
                  onClick={() => photoInputRef.current?.click()}
                  disabled={uploadingPhoto}
                  className="absolute -bottom-1 -right-1 w-7 h-7 bg-[#4C4CFF] rounded-full flex items-center justify-center text-white hover:bg-[#3d3dcc] transition-colors shadow-md"
                  title="Change photo"
                >
                  {uploadingPhoto
                    ? <div className="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                    : <Camera className="w-3.5 h-3.5" />}
                </button>
                <input
                  ref={photoInputRef}
                  type="file"
                  accept="image/png,image/jpeg,image/jpg,image/webp"
                  className="hidden"
                  onChange={handlePhotoChange}
                />
              </div>
              <div>
                <p className="text-sm font-medium text-[#1a1a1a]">{name || '—'}</p>
                <p className="text-xs text-[#666666]">{roleLabel(role)}</p>
                <p className="text-xs text-[#999] mt-1">Click the camera icon to change photo</p>
              </div>
            </div>

            {/* Editable fields */}
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-[#666666] mb-2">Full Name</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                  placeholder="Enter your name"
                />
              </div>
              <div>
                <label className="block text-sm text-[#666666] mb-2">Email</label>
                <input
                  type="email"
                  value={email}
                  readOnly
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded bg-[#f5f5f5] text-[#888] cursor-not-allowed"
                />
                <p className="text-xs text-[#999] mt-1">Email cannot be changed here.</p>
              </div>
              <div>
                <label className="block text-sm text-[#666666] mb-2">Role</label>
                <input
                  type="text"
                  value={roleLabel(role)}
                  readOnly
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded bg-[#f5f5f5] text-[#888] cursor-not-allowed"
                />
              </div>
              <button
                onClick={handleSaveProfile}
                disabled={savingProfile}
                className="flex items-center gap-2 px-5 py-2.5 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors disabled:opacity-50"
              >
                {savingProfile
                  ? <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  : <Save className="w-4 h-4" />}
                Save Changes
              </button>
            </div>
          </div>

          {/* Change Password ────────────────────────────────────────────── */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
            <div className="flex items-center gap-3 mb-5 pb-4 border-b-2 border-[#e5e5e5]">
              <Lock className="w-5 h-5 text-[#4C4CFF]" />
              <h2 className="text-lg text-[#1a1a1a]">Change Password</h2>
            </div>
            <div className="space-y-4">
              <PwInput
                label="Current Password"
                value={currentPassword}
                onChange={setCurrentPassword}
                show={showCurrentPw}
                toggle={() => setShowCurrentPw(!showCurrentPw)}
                placeholder="Enter current password"
              />
              <PwInput
                label="New Password"
                value={newPassword}
                onChange={setNewPassword}
                show={showNewPw}
                toggle={() => setShowNewPw(!showNewPw)}
                placeholder="Minimum 6 characters"
              />
              <PwInput
                label="Confirm New Password"
                value={confirmPassword}
                onChange={setConfirmPassword}
                show={showConfirmPw}
                toggle={() => setShowConfirmPw(!showConfirmPw)}
                placeholder="Repeat new password"
              />
              {/* Strength hint */}
              {newPassword.length > 0 && (
                <div className="flex items-center gap-2 mt-1">
                  {[4, 6, 8, 10].map((min) => (
                    <div
                      key={min}
                      className={`h-1 flex-1 rounded ${newPassword.length >= min ? 'bg-[#4CAF50]' : 'bg-[#e5e5e5]'}`}
                    />
                  ))}
                  <span className="text-xs text-[#666]">
                    {newPassword.length < 6 ? 'Weak' : newPassword.length < 8 ? 'Fair' : newPassword.length < 10 ? 'Good' : 'Strong'}
                  </span>
                </div>
              )}
              <button
                onClick={handleChangePassword}
                disabled={savingPassword}
                className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors disabled:opacity-50"
              >
                {savingPassword
                  ? <><div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />Updating...</>
                  : 'Update Password'}
              </button>
            </div>
          </div>
        </div>

        {/* ── Right sidebar ── */}
        <div className="space-y-6">
          {/* Account Summary */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
            <div className="flex items-center gap-3 mb-4 pb-3 border-b-2 border-[#e5e5e5]">
              <Shield className="w-5 h-5 text-[#4C4CFF]" />
              <h3 className="text-base text-[#1a1a1a]">Account Info</h3>
            </div>
            <div className="space-y-3 text-sm">
              <div className="flex flex-col gap-0.5">
                <span className="text-[#999] text-xs">Account created</span>
                <span className="text-[#1a1a1a]">{createdAt}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-[#666]">Session</span>
                <span className="px-2 py-0.5 bg-[#E8F5E9] text-[#4CAF50] text-xs rounded">Active</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-[#666]">Role</span>
                <span className={`px-2 py-0.5 text-xs rounded font-medium
                  ${role === 'super_admin' ? 'bg-purple-100 text-purple-700' :
                    role === 'moderator' ? 'bg-green-100 text-green-700' :
                    'bg-blue-100 text-blue-700'}`}>
                  {roleLabel(role)}
                </span>
              </div>
            </div>
          </div>

          {/* Tips */}
          <div className="bg-[#f0f4ff] border-2 border-[#c7d2fe] rounded p-5">
            <h3 className="text-sm font-medium text-[#1a1a1a] mb-3">Security Tips</h3>
            <ul className="space-y-2 text-xs text-[#555]">
              <li className="flex items-start gap-2"><span className="text-[#4C4CFF] mt-0.5">•</span>Use a strong password with letters, numbers & symbols.</li>
              <li className="flex items-start gap-2"><span className="text-[#4C4CFF] mt-0.5">•</span>Never share your password with anyone.</li>
              <li className="flex items-start gap-2"><span className="text-[#4C4CFF] mt-0.5">•</span>Change your password regularly.</li>
              <li className="flex items-start gap-2"><span className="text-[#4C4CFF] mt-0.5">•</span>Log out from shared devices after use.</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
