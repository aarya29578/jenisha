import { User, Lock, Bell, Shield } from 'lucide-react';
import { useState } from 'react';

export default function AdminProfile() {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl text-[#1a1a1a] mb-2">Admin Account & Security</h1>
        <p className="text-[#666666]">Manage your admin account settings</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Profile Information */}
        <div className="lg:col-span-2 space-y-6">
          {/* Basic Info */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
            <div className="flex items-center gap-3 mb-5 pb-4 border-b-2 border-[#e5e5e5]">
              <User className="w-5 h-5 text-[#4C4CFF]" />
              <h2 className="text-lg text-[#1a1a1a]">Profile Information</h2>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-[#666666] mb-2">Full Name</label>
                <input
                  type="text"
                  value="Admin User"
                  readOnly
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded bg-[#f5f5f5] text-[#1a1a1a]"
                />
              </div>
              <div>
                <label className="block text-sm text-[#666666] mb-2">Username</label>
                <input
                  type="text"
                  value="admin"
                  readOnly
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded bg-[#f5f5f5] text-[#1a1a1a]"
                />
              </div>
              <div>
                <label className="block text-sm text-[#666666] mb-2">Email</label>
                <input
                  type="email"
                  value="admin@system.gov.in"
                  readOnly
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded bg-[#f5f5f5] text-[#1a1a1a]"
                />
              </div>
              <div>
                <label className="block text-sm text-[#666666] mb-2">Role</label>
                <input
                  type="text"
                  value="System Administrator"
                  readOnly
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded bg-[#f5f5f5] text-[#1a1a1a]"
                />
              </div>
            </div>
          </div>

          {/* Change Password */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
            <div className="flex items-center gap-3 mb-5 pb-4 border-b-2 border-[#e5e5e5]">
              <Lock className="w-5 h-5 text-[#4C4CFF]" />
              <h2 className="text-lg text-[#1a1a1a]">Change Password</h2>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm text-[#666666] mb-2">Current Password</label>
                <input
                  type="password"
                  value={currentPassword}
                  onChange={(e) => setCurrentPassword(e.target.value)}
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                  placeholder="Enter current password"
                />
              </div>
              <div>
                <label className="block text-sm text-[#666666] mb-2">New Password</label>
                <input
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                  placeholder="Enter new password"
                />
              </div>
              <div>
                <label className="block text-sm text-[#666666] mb-2">Confirm New Password</label>
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                  placeholder="Confirm new password"
                />
              </div>
              <button className="w-full px-4 py-3 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors">
                Update Password
              </button>
            </div>
          </div>
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* Notifications */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
            <div className="flex items-center gap-3 mb-4 pb-3 border-b-2 border-[#e5e5e5]">
              <Bell className="w-5 h-5 text-[#4C4CFF]" />
              <h3 className="text-base text-[#1a1a1a]">Notifications</h3>
            </div>
            <div className="space-y-3">
              <div className="p-3 bg-[#f5f5f5] rounded">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm text-[#1a1a1a]">New Agent Registration</span>
                  <span className="px-2 py-0.5 bg-[#FF9800] text-white text-xs rounded">2</span>
                </div>
                <p className="text-xs text-[#666666]">24 Jan 2026</p>
              </div>
              <div className="p-3 bg-[#f5f5f5] rounded">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm text-[#1a1a1a]">Document Upload</span>
                  <span className="px-2 py-0.5 bg-[#FF9800] text-white text-xs rounded">5</span>
                </div>
                <p className="text-xs text-[#666666]">24 Jan 2026</p>
              </div>
              <div className="p-3 bg-[#f5f5f5] rounded">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-sm text-[#1a1a1a]">Certificate Generated</span>
                  <span className="px-2 py-0.5 bg-[#4CAF50] text-white text-xs rounded">✓</span>
                </div>
                <p className="text-xs text-[#666666]">23 Jan 2026</p>
              </div>
            </div>
          </div>

          {/* Security Info */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
            <div className="flex items-center gap-3 mb-4 pb-3 border-b-2 border-[#e5e5e5]">
              <Shield className="w-5 h-5 text-[#4C4CFF]" />
              <h3 className="text-base text-[#1a1a1a]">Security</h3>
            </div>
            <div className="space-y-3 text-sm text-[#666666]">
              <div className="flex items-center justify-between">
                <span>Last Login</span>
                <span className="text-[#1a1a1a]">24 Jan 2026, 09:30 AM</span>
              </div>
              <div className="flex items-center justify-between">
                <span>Session Status</span>
                <span className="px-2 py-0.5 bg-[#E8F5E9] text-[#4CAF50] text-xs rounded">Active</span>
              </div>
              <div className="flex items-center justify-between">
                <span>IP Address</span>
                <span className="text-[#1a1a1a]">192.168.1.1</span>
              </div>
            </div>
            <button className="w-full mt-4 px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors text-sm">
              View Activity Log
            </button>
          </div>

          {/* Logout */}
          <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
            <h3 className="text-base text-[#1a1a1a] mb-3">Session Management</h3>
            <button
              onClick={() => window.location.reload()}
              className="w-full px-4 py-3 bg-[#F44336] text-white rounded hover:bg-[#d32f2f] transition-colors"
            >
              Logout from All Devices
            </button>
            <p className="text-xs text-[#666666] mt-2 text-center">
              This will end all active sessions
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
