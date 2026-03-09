import { useState, useEffect } from 'react';
import { Check, X, Eye, FileText, AlertCircle, Loader, Download } from 'lucide-react';
import { downloadFile } from '@/utils/downloadFile';
import { pendingUsersService, userApprovalService, userDocumentsService, UserData, UserDocumentData, adminAuth } from '@/services/firebaseService';

export default function AgentApproval() {
  const [pendingUsers, setPendingUsers] = useState<UserData[]>([]);
  const [userDocuments, setUserDocuments] = useState<Record<string, UserDocumentData[]>>({});
  const [loading, setLoading] = useState(true);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [actionInProgress, setActionInProgress] = useState<string | null>(null);
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectUserId, setRejectUserId] = useState<string | null>(null);
  const [rejectionReason, setRejectionReason] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [docLoadingUserId, setDocLoadingUserId] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);
    
    // Subscribe to pending users
    const unsubscribe = pendingUsersService.subscribeToPendingUsers(
      (users) => {
        setPendingUsers(users);
        setLoading(false);
        setError(null);
      },
      (err) => {
        console.error('Failed to load pending users:', err);
        setError('Failed to load pending users. Please try again.');
        setLoading(false);
      }
    );

    // Cleanup subscription on unmount
    return () => unsubscribe();
  }, []);

  const handleApprove = async (uid: string) => {
    try {
      setActionInProgress(uid);
      const adminEmail = adminAuth.getCurrentUser()?.email || 'admin@system';
      
      await userApprovalService.approveUser(uid, adminEmail);
      
      // Remove from pending list (real-time listener will handle UI update)
      setPendingUsers(prev => prev.filter(u => u.uid !== uid));
      setSelectedUserId(null);
      
    } catch (err) {
      console.error('Error approving user:', err);
      setError(`Failed to approve user: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setActionInProgress(null);
    }
  };

  const loadUserDocuments = async (userId: string) => {
    if (userDocuments[userId]) return; // Already loaded
    
    try {
      setDocLoadingUserId(userId);
      const docs = await userDocumentsService.getUserDocuments(userId);
      setUserDocuments(prev => ({
        ...prev,
        [userId]: docs
      }));
    } catch (err) {
      console.error('Error loading user documents:', err);
      setError(`Failed to load documents: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setDocLoadingUserId(null);
    }
  };

  const handleViewClick = async (userId: string) => {
    if (selectedUserId === userId) {
      setSelectedUserId(null);
    } else {
      await loadUserDocuments(userId);
      setSelectedUserId(userId);
    }
  };

  const handleRejectClick = (uid: string) => {
    setRejectUserId(uid);
    setRejectionReason('');
    setShowRejectModal(true);
  };

  const handleRejectSubmit = async () => {
    if (!rejectUserId || !rejectionReason.trim()) {
      setError('Please provide a rejection reason');
      return;
    }

    try {
      setActionInProgress(rejectUserId);
      const adminEmail = adminAuth.getCurrentUser()?.email || 'admin@system';
      
      await userApprovalService.rejectUser(rejectUserId, adminEmail, rejectionReason);
      
      // Remove from pending list
      setPendingUsers(prev => prev.filter(u => u.uid !== rejectUserId));
      setSelectedUserId(null);
      setShowRejectModal(false);
      
    } catch (err) {
      console.error('Error rejecting user:', err);
      setError(`Failed to reject user: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setActionInProgress(null);
    }
  };

  const formatDate = (timestamp: any) => {
    if (!timestamp) return 'N/A';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString('en-IN', { 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <Loader className="w-8 h-8 text-[#5b47c7] mx-auto mb-4 animate-spin" />
          <p className="text-[#666666]">Loading pending users...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl text-[#1a1a1a] mb-2">Login Confirmation</h1>
        <p className="text-[#666666]">Review and approve new user registrations</p>
      </div>

      {/* Error Alert */}
      {error && (
        <div className="bg-red-50 border-2 border-red-200 rounded p-4">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
            <div>
              <h3 className="text-sm text-red-800 font-medium">Error</h3>
              <p className="text-sm text-red-700 mt-1">{error}</p>
              <button 
                onClick={() => setError(null)}
                className="text-xs text-red-600 hover:text-red-700 mt-2 underline"
              >
                Dismiss
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Verification Notice */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded p-4">
        <div className="flex items-start gap-3">
          <FileText className="w-5 h-5 text-[#4C4CFF] flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-sm text-[#1a1a1a] mb-1">Real-time Updates</h3>
            <p className="text-sm text-[#666666]">
              This page syncs in real-time with Firebase. Approved/rejected status updates are instantly reflected in the user app.
            </p>
          </div>
        </div>
      </div>

      {/* Pending Users List */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded">
        <div className="px-5 py-4 border-b-2 border-[#e5e5e5] flex items-center justify-between">
          <h2 className="text-lg text-[#1a1a1a]">Pending User Requests</h2>
          <span className="px-3 py-1 bg-[#FFF4E6] text-[#FF9800] rounded text-sm font-medium">
            {pendingUsers.length} Pending
          </span>
        </div>

        {pendingUsers.length === 0 ? (
          <div className="p-12 text-center">
            <Check className="w-12 h-12 text-[#4CAF50] mx-auto mb-4 opacity-50" />
            <p className="text-[#666666] text-base">No pending user requests</p>
            <p className="text-[#999999] text-sm mt-2">All users have been reviewed</p>
          </div>
        ) : (
          <div className="divide-y-2 divide-[#e5e5e5]">
            {pendingUsers.map((user) => (
              <div key={user.uid} className="p-5">
                  <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-4">
                    {/* Profile Photo + User Info */}
                    <div className="flex gap-4 flex-1">
                      {/* Profile Photo */}
                      <div className="flex-shrink-0">
                        {user.profilePhotoUrl ? (
                          <div className="relative group">
                            <img
                              src={user.profilePhotoUrl}
                              alt={user.fullName}
                              className="w-16 h-16 rounded-full object-cover border-2 border-[#e5e5e5]"
                            />
                            <button
                              onClick={() => downloadFile(user.profilePhotoUrl!, `profile_${user.fullName.replace(/\s+/g, '_')}`)}
                              title="Download profile photo"
                              className="absolute -bottom-1 -right-1 bg-[#243BFF] hover:bg-[#1e32e0] text-white rounded-full p-1 shadow transition-colors opacity-0 group-hover:opacity-100"
                            >
                              <Download className="w-3 h-3" />
                            </button>
                          </div>
                        ) : (
                          <div className="w-16 h-16 rounded-full bg-[#e5e5e5] flex items-center justify-center border-2 border-[#d0d0d0]">
                            <span className="text-[#999999] text-2xl font-semibold">
                              {user.fullName.charAt(0).toUpperCase()}
                            </span>
                          </div>
                        )}
                      </div>

                      {/* User Info */}
                      <div className="flex-1">
                        <h3 className="text-base text-[#1a1a1a] mb-2 font-semibold">{user.fullName}</h3>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm text-[#666666]">
                          <p>📱 Phone: {user.phone}</p>
                          <p>📧 Email: {user.email}</p>
                          <p>🏪 Shop: {user.shopName}</p>
                          <p>📍 Location: {user.address.city}, {user.address.state}</p>
                          <p>📅 Submitted: {formatDate(user.createdAt)}</p>
                        </div>
                        <div className="flex gap-2 mt-3">
                          <span className={`px-2 py-1 rounded text-xs font-medium ${
                            (user.documents.adhaar || user.documents.aadhar)
                              ? 'bg-[#E8F5E9] text-[#4CAF50]' 
                              : 'bg-[#F3F4F6] text-[#999999]'
                          }`}>
                            Aadhar: {(user.documents.adhaar || user.documents.aadhar) ? '✓ Provided' : '✗ Missing'}
                          </span>
                          <span className={`px-2 py-1 rounded text-xs font-medium ${
                            user.documents.pan 
                              ? 'bg-[#E8F5E9] text-[#4CAF50]' 
                              : 'bg-[#F3F4F6] text-[#999999]'
                          }`}>
                            PAN: {user.documents.pan ? '✓ Provided' : '✗ Missing'}
                          </span>
                          {user.profilePhotoUrl && (
                            <span className="px-2 py-1 rounded text-xs font-medium bg-[#E8F5E9] text-[#4CAF50]">
                              Photo: ✓ Provided
                            </span>
                          )}
                        </div>
                      </div>
                    </div>

                  {/* Actions */}
                  <div className="flex gap-2 flex-wrap lg:flex-nowrap">
                    <button
                      onClick={() => handleViewClick(user.uid)}
                      className="flex items-center gap-2 px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors text-sm"
                    >
                      {docLoadingUserId === user.uid ? (
                        <Loader className="w-4 h-4 animate-spin" />
                      ) : (
                        <Eye className="w-4 h-4" />
                      )}
                      <span>{selectedUserId === user.uid ? 'Hide' : 'View'}</span>
                    </button>
                    <button
                      onClick={() => handleApprove(user.uid)}
                      disabled={actionInProgress === user.uid}
                      className="flex items-center gap-2 px-4 py-2 bg-[#4CAF50] text-white rounded hover:bg-[#45a049] disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-sm"
                    >
                      {actionInProgress === user.uid ? (
                        <Loader className="w-4 h-4 animate-spin" />
                      ) : (
                        <Check className="w-4 h-4" />
                      )}
                      <span>Approve</span>
                    </button>
                    <button
                      onClick={() => handleRejectClick(user.uid)}
                      disabled={actionInProgress === user.uid}
                      className="flex items-center gap-2 px-4 py-2 bg-[#F44336] text-white rounded hover:bg-[#d32f2f] disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-sm"
                    >
                      {actionInProgress === user.uid ? (
                        <Loader className="w-4 h-4 animate-spin" />
                      ) : (
                        <X className="w-4 h-4" />
                      )}
                      <span>Reject</span>
                    </button>
                  </div>
                </div>

                {/* User Details (if selected) */}
                {selectedUserId === user.uid && (
                  <div className="mt-6 pt-4 border-t-2 border-[#e5e5e5]">
                    <h4 className="text-sm font-semibold text-[#1a1a1a] mb-4">Full Registration Details</h4>

                    {/* Profile Photo */}
                    {user.profilePhotoUrl && (
                      <div className="mb-4">
                        <h5 className="text-xs font-semibold text-[#666666] uppercase mb-2">Profile Photo</h5>
                        <div className="flex items-center gap-4">
                          <img
                            src={user.profilePhotoUrl}
                            alt={user.fullName}
                            className="w-24 h-24 rounded-full object-cover border-2 border-[#e5e5e5]"
                          />
                          <button
                            onClick={() => downloadFile(user.profilePhotoUrl!, `profile_${user.fullName.replace(/\s+/g, '_')}`)}
                            className="flex items-center gap-2 bg-[#243BFF] hover:bg-[#1e32e0] text-white text-sm font-medium px-3 py-2 rounded shadow transition-colors"
                          >
                            <Download className="w-4 h-4" />
                            Download Photo
                          </button>
                        </div>
                      </div>
                    )}
                    
                    {/* Address Details */}
                    <div className="mb-4">
                      <h5 className="text-xs font-semibold text-[#666666] uppercase mb-2">Address Information</h5>
                      <div className="bg-[#f5f5f5] rounded p-3 text-sm text-[#333333]">
                        <p>{user.address.line1}</p>
                        <p>{user.address.city}, {user.address.state} - {user.address.pincode}</p>
                      </div>
                    </div>

                    {/* Document Images */}
                    <h5 className="text-xs font-semibold text-[#666666] uppercase mb-3">Uploaded Documents</h5>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                      {/* Aadhaar Card */}
                      {(() => {
                        const adhaarDoc = user.documents.adhaar || user.documents.aadhar;
                        const adhaarUrl = typeof adhaarDoc === 'object' && adhaarDoc?.imageUrl 
                          ? adhaarDoc.imageUrl 
                          : typeof adhaarDoc === 'string' 
                          ? adhaarDoc 
                          : null;
                        
                        return (
                          <div className="border-2 border-[#e5e5e5] rounded p-4 bg-[#f9f9f9]">
                            <p className="text-sm text-[#1a1a1a] font-medium mb-2">Aadhaar Card</p>
                            {adhaarUrl ? (
                              <div className="relative mb-2">
                                <a href={adhaarUrl} target="_blank" rel="noopener noreferrer" className="block">
                                  <div
                                    className="w-full h-40 bg-cover bg-center rounded cursor-pointer hover:opacity-80 border border-[#e5e5e5]"
                                    style={{
                                      backgroundImage: `url('${adhaarUrl}')`,
                                      backgroundSize: 'contain',
                                      backgroundRepeat: 'no-repeat',
                                      backgroundPosition: 'center'
                                    }}
                                  />
                                </a>
                                <button
                                  onClick={() => downloadFile(adhaarUrl, 'aadhaar_card')}
                                  title="Download Aadhaar"
                                  className="absolute top-2 right-2 flex items-center gap-1 bg-[#243BFF] hover:bg-[#1e32e0] text-white text-xs font-medium px-2 py-1 rounded shadow transition-colors"
                                >
                                  <Download className="w-3 h-3" />
                                  Download
                                </button>
                              </div>
                            ) : (
                              <div className="w-full h-40 bg-[#e5e5e5] rounded flex items-center justify-center text-[#999999] mb-2">
                                <FileText className="w-8 h-8" />
                              </div>
                            )}
                            <p className="text-xs text-[#666666]">
                              {adhaarUrl ? '✓ Uploaded' : '✗ Not provided'}
                            </p>
                          </div>
                        );
                      })()}
                      
                      {/* PAN Card */}
                      {(() => {
                        const panDoc = user.documents.pan;
                        const panUrl = typeof panDoc === 'object' && panDoc?.imageUrl 
                          ? panDoc.imageUrl 
                          : typeof panDoc === 'string' 
                          ? panDoc 
                          : null;
                        
                        return (
                          <div className="border-2 border-[#e5e5e5] rounded p-4 bg-[#f9f9f9]">
                            <p className="text-sm text-[#1a1a1a] font-medium mb-2">PAN Card</p>
                            {panUrl ? (
                              <div className="relative mb-2">
                                <a href={panUrl} target="_blank" rel="noopener noreferrer" className="block">
                                  <div
                                    className="w-full h-40 bg-cover bg-center rounded cursor-pointer hover:opacity-80 border border-[#e5e5e5]"
                                    style={{
                                      backgroundImage: `url('${panUrl}')`,
                                      backgroundSize: 'contain',
                                      backgroundRepeat: 'no-repeat',
                                      backgroundPosition: 'center'
                                    }}
                                  />
                                </a>
                                <button
                                  onClick={() => downloadFile(panUrl, 'pan_card')}
                                  title="Download PAN"
                                  className="absolute top-2 right-2 flex items-center gap-1 bg-[#243BFF] hover:bg-[#1e32e0] text-white text-xs font-medium px-2 py-1 rounded shadow transition-colors"
                                >
                                  <Download className="w-3 h-3" />
                                  Download
                                </button>
                              </div>
                            ) : (
                              <div className="w-full h-40 bg-[#e5e5e5] rounded flex items-center justify-center text-[#999999] mb-2">
                                <FileText className="w-8 h-8" />
                              </div>
                            )}
                            <p className="text-xs text-[#666666]">
                              {panUrl ? '✓ Uploaded' : '✗ Not provided'}
                            </p>
                          </div>
                        );
                      })()}
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Rejection Modal */}
      {showRejectModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg max-w-md w-full p-6">
            <h2 className="text-lg font-semibold text-[#1a1a1a] mb-4">Reject User Request</h2>
            
            <p className="text-sm text-[#666666] mb-4">
              Please provide a reason for rejecting this user's request. The user will see this reason when they check their status.
            </p>

            <textarea
              value={rejectionReason}
              onChange={(e) => setRejectionReason(e.target.value)}
              placeholder="Enter rejection reason (e.g., Invalid documents, Incomplete information, etc.)"
              className="w-full p-3 border-2 border-[#e5e5e5] rounded mb-4 text-sm focus:outline-none focus:border-[#5b47c7] resize-none"
              rows={4}
            />

            <div className="flex gap-2">
              <button
                onClick={() => setShowRejectModal(false)}
                className="flex-1 px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors text-sm font-medium"
              >
                Cancel
              </button>
              <button
                onClick={handleRejectSubmit}
                disabled={!rejectionReason.trim()}
                className="flex-1 px-4 py-2 bg-[#F44336] text-white rounded hover:bg-[#d32f2f] disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-sm font-medium"
              >
                Confirm Rejection
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Approval Guidelines */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
        <h2 className="text-lg text-[#1a1a1a] mb-4 pb-3 border-b-2 border-[#e5e5e5] font-semibold">
          Approval Guidelines
        </h2>
        <div className="space-y-3 text-sm text-[#666666]">
          <div className="flex items-start gap-3">
            <span className="text-[#4C4CFF] font-bold">✓</span>
            <p>Verify user name matches on Aadhar and PAN documents</p>
          </div>
          <div className="flex items-start gap-3">
            <span className="text-[#4C4CFF] font-bold">✓</span>
            <p>Ensure shop name and location are legitimate and verifiable</p>
          </div>
          <div className="flex items-start gap-3">
            <span className="text-[#4C4CFF] font-bold">✓</span>
            <p>Check document validity and expiry dates if applicable</p>
          </div>
          <div className="flex items-start gap-3">
            <span className="text-[#4C4CFF] font-bold">✓</span>
            <p>Only approved users can access app services</p>
          </div>
          <div className="flex items-start gap-3">
            <span className="text-[#4C4CFF] font-bold">✓</span>
            <p>Rejected users receive notification with specific reason</p>
          </div>
        </div>
      </div>
    </div>
  );
}

