import { useState, useEffect, useMemo } from 'react';
import { Check, X, Eye, FileText, Filter, Download, Search, ChevronDown } from 'lucide-react';
import { downloadFile } from '@/utils/downloadFile';
import { authService } from '@/services/authService';
import {
  getFirestore,
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  getDocs,
  doc,
  updateDoc,
  serverTimestamp,
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

interface ServiceApplication {
  id: string;
  userId: string;
  serviceId: string;
  status: string;
  userName?: string;
  serviceName?: string;
  fullName?: string;
  phone?: string;
  email?: string;
  documents?: Record<string, string>; // documentName -> imageUrl from Flutter
  fieldData?: Record<string, any>; // Dynamic fields from admin panel
  filledFormUrl?: string; // Filled form uploaded by the Flutter user
  documentsMeta?: Record<
    string,
    {
      documentName?: string;
      status?: string;
      imageUrl?: string;
      rejectionReason?: string;
    }
  >;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
}

interface DocumentData {
  id: string;
  documentName: string;
  status: string;
  imageUrl?: string;
  rejectionReason?: string | null;
  uploadedAt?: Timestamp;
  reviewedAt?: Timestamp;
}

type FilterValue = 'pending' | 'approved' | 'rejected' | 'all';

const statusFilters: { label: string; value: FilterValue }[] = [
  { label: 'Pending', value: 'pending' },
  { label: 'Approved', value: 'approved' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'All', value: 'all' },
];

const badgeClasses: Record<string, string> = {
  pending: 'bg-[#FFF4E6] text-[#FF9800]',
  submitted: 'bg-[#E3F2FD] text-[#1E88E5]',
  approved: 'bg-[#E8F5E9] text-[#4CAF50]',
  rejected: 'bg-[#FFEBEE] text-[#F44336]',
  draft: 'bg-[#F3F4F6] text-[#6B7280]',
};

const documentStatusLabel = (status: string) => {
  switch (status) {
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'uploaded':
      return 'Uploaded';
    case 'pending':
    default:
      return 'Pending Review';
  }
};

const formatDate = (timestamp?: Timestamp) => {
  if (!timestamp) return '—';
  return timestamp.toDate().toLocaleString();
};

export default function CustomerVerification() {
  // Raw data — never filtered directly
  const [allApplications, setAllApplications] = useState<ServiceApplication[]>([]);
  const [services, setServices] = useState<{ id: string; name: string }[]>([]);

  const currentUser = authService.getCurrentUser();

  // Filter states
  const [filterStatus, setFilterStatus] = useState<FilterValue>('all');
  const [selectedService, setSelectedService] = useState('all');
  const [searchTerm, setSearchTerm] = useState('');

  // UI states
  const [selectedAppId, setSelectedAppId] = useState<string | null>(null);
  const [userDocuments, setUserDocuments] = useState<DocumentData[]>([]);
  const [textFields, setTextFields] = useState<Record<string, string>>({});
  const [loadingApps, setLoadingApps] = useState(true);
  const [loadingDocs, setLoadingDocs] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Always find selected app from ALL applications so the details panel stays stable
  const selectedApplication = useMemo(
    () => allApplications.find((app) => app.id === selectedAppId) ?? null,
    [allApplications, selectedAppId]
  );

  // Derived filtered list — pure client-side, no extra Firestore reads
  const applications = useMemo(() => {
    let result = allApplications;

    // 0. Role-based service access filter
    if (currentUser?.role === 'admin') {
      const allowed = Array.isArray(currentUser.allowedServices) ? currentUser.allowedServices : [];
      result = result.filter((app) => allowed.includes(app.serviceId));
    }
    // super_admin sees all — no filter applied

    // 1. Status filter
    if (filterStatus !== 'all') {
      result = result.filter((app) => app.status === filterStatus);
    }

    // 2. Service filter
    if (selectedService !== 'all') {
      result = result.filter((app) => app.serviceId === selectedService);
    }

    // 3. Search filter (name, phone, application ID)
    const q = searchTerm.trim().toLowerCase();
    if (q !== '') {
      result = result.filter(
        (app) =>
          app.fullName?.toLowerCase().includes(q) ||
          app.userName?.toLowerCase().includes(q) ||
          app.phone?.includes(searchTerm.trim()) ||
          app.id.toLowerCase().includes(q)
      );
    }

    return result;
  }, [allApplications, filterStatus, selectedService, searchTerm, currentUser]);

  // One-time subscription — fetch ALL, filter client-side via useMemo
  useEffect(() => {
    setLoadingApps(true);
    setError(null);

    const appsRef = collection(db, 'serviceApplications');
    const appsQuery = query(appsRef, orderBy('createdAt', 'desc'));

    const unsubscribe = onSnapshot(
      appsQuery,
      (snapshot) => {
        const allRecords: ServiceApplication[] = snapshot.docs.map((docSnap) => {
          const data = docSnap.data();
          return {
            id: docSnap.id,
            userId: data.userId,
            serviceId: data.serviceId,
            status: data.status ?? 'pending',
            userName: data.userName ?? data.fullName,
            fullName: data.fullName,
            phone: data.phone,
            email: data.email,
            serviceName: data.serviceName,
            documents: data.documents ?? {},
            fieldData: data.fieldData ?? {},
            filledFormUrl: data.filledFormUrl ?? '',
            documentsMeta: data.documentsMeta ?? {},
            createdAt: data.createdAt,
            updatedAt: data.updatedAt,
          } as ServiceApplication;
        });
        setAllApplications(allRecords);
        setLoadingApps(false);
      },
      (err) => {
        console.error('Error loading applications:', err);
        setAllApplications([]);
        setSelectedAppId(null);
        setError('Unable to load applications. Please try again.');
        setLoadingApps(false);
      }
    );

    return unsubscribe;
  }, []); // no filter deps — real-time stream, filter via useMemo

  // Keep selected app in sync when the filtered list changes
  useEffect(() => {
    if (applications.length === 0) {
      setSelectedAppId(null);
    } else {
      setSelectedAppId((prev) =>
        prev && applications.some((a) => a.id === prev) ? prev : applications[0].id
      );
    }
  }, [applications]);

  // Fetch services once for the dropdown
  useEffect(() => {
    const fetchServices = async () => {
      try {
        const snap = await getDocs(collection(db, 'services'));
        const items = snap.docs
          .map((d) => ({ id: d.id, name: (d.data().name as string) || d.id }))
          .sort((a, b) => a.name.localeCompare(b.name));
        setServices(items);
      } catch (e) {
        console.error('Error fetching services for filter:', e);
      }
    };
    fetchServices();
  }, []);

  useEffect(() => {
    if (!selectedAppId) {
      setUserDocuments([]);
      setTextFields({});
      return;
    }

    const selectedApp = allApplications.find(app => app.id === selectedAppId);
    if (!selectedApp) {
      setUserDocuments([]);
      setTextFields({});
      setLoadingDocs(false);
      return;
    }

    setLoadingDocs(true);
    
    // Convert documents object to DocumentData array (old format - all images)
    const documents = selectedApp.documents || {};
    const documentsMeta = selectedApp.documentsMeta || {};
    
    const oldDocs: DocumentData[] = Object.entries(documents).map(([docName, imageUrl]) => {
      const meta = documentsMeta[docName] || {};
      return {
        id: docName,
        documentName: docName,
        status: meta.status || 'pending',
        imageUrl: imageUrl,
        rejectionReason: meta.rejectionReason || null,
        uploadedAt: selectedApp.createdAt,
        reviewedAt: meta.reviewedAt || undefined,
      };
    });
    
    // Convert fieldData - separate images from text fields
    const fieldData = selectedApp.fieldData || {};
    const imageDocs: DocumentData[] = [];
    const textFieldValues: Record<string, string> = {};
    
    Object.entries(fieldData).forEach(([fieldName, fieldValue]) => {
      const meta = documentsMeta[fieldName] || {};
      const isImageField = typeof fieldValue === 'string' && (fieldValue.startsWith('http://') || fieldValue.startsWith('https://'));
      
      if (isImageField) {
        // Add to image documents
        imageDocs.push({
          id: fieldName,
          documentName: fieldName,
          status: meta.status || 'pending',
          imageUrl: fieldValue,
          rejectionReason: meta.rejectionReason || null,
          uploadedAt: selectedApp.createdAt,
          reviewedAt: meta.reviewedAt || undefined,
        });
      } else {
        // Add to text fields
        textFieldValues[fieldName] = String(fieldValue);
      }
    });
    
    // Combine old documents and image fields only
    const allImageDocs = [...oldDocs, ...imageDocs];
    
    console.log('Loaded image documents:', allImageDocs);
    console.log('Loaded text fields:', textFieldValues);
    setUserDocuments(allImageDocs);
    setTextFields(textFieldValues);
    setLoadingDocs(false);
  }, [selectedAppId, allApplications]);

  const handleDocumentStatusChange = async (
    docId: string,
    status: 'approved' | 'rejected'
  ) => {
    if (!selectedAppId) return;

    let rejectionReason: string | null = null;
    if (status === 'rejected') {
      rejectionReason =
        window.prompt('Provide a rejection reason', 'Document is unreadable') ??
        'Document rejected';
    }

    try {
      const applicationRef = doc(db, 'serviceApplications', selectedAppId);
      
      // If rejecting a document, mark entire application as rejected
      if (status === 'rejected') {
        await updateDoc(applicationRef, {
          [`documentsMeta.${docId}.status`]: status,
          [`documentsMeta.${docId}.rejectionReason`]: rejectionReason,
          [`documentsMeta.${docId}.reviewedAt`]: serverTimestamp(),
          status: 'rejected', // Mark application as rejected
          rejectionReason: `Document "${docId}" was rejected: ${rejectionReason}`,
          reviewedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        console.log(`Document ${docId} rejected - Application marked as rejected`);
      } else {
        // Just update the document status if approving
        await updateDoc(applicationRef, {
          [`documentsMeta.${docId}.status`]: status,
          [`documentsMeta.${docId}.reviewedAt`]: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        console.log(`Document ${docId} approved`);
      }
    } catch (err) {
      console.error('Error updating document status:', err);
      window.alert('Unable to update document. Please try again.');
      throw err;
    }
  };

  const handleApproveAll = async () => {
    if (!selectedAppId) return;

    try {
      const applicationRef = doc(db, 'serviceApplications', selectedAppId);
      
      // Create documentsMeta updates for all documents
      const updates: Record<string, any> = {
        status: 'approved',
        reviewedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };
      
      // Mark all documents as approved in documentsMeta (if any exist)
      userDocuments.forEach(docInfo => {
        updates[`documentsMeta.${docInfo.id}.status`] = 'approved';
        updates[`documentsMeta.${docInfo.id}.reviewedAt`] = serverTimestamp();
      });
      
      await updateDoc(applicationRef, updates);
      
      const message = userDocuments.length > 0 
        ? `All ${userDocuments.length} images approved - Application marked as approved`
        : 'Application approved (no images to verify)';
      console.log(message);
      window.alert('Application approved successfully!');
    } catch (err) {
      console.error('Error approving documents:', err);
      window.alert('Unable to approve application. Please try again.');
    }
  };

  const handleRejectApplication = async () => {
    if (!selectedAppId) return;

    const rejectionReason = window.prompt('Provide a rejection reason for the entire application:', 'Application does not meet requirements');
    if (!rejectionReason) return;

    try {
      const applicationRef = doc(db, 'serviceApplications', selectedAppId);
      
      await updateDoc(applicationRef, {
        status: 'rejected',
        rejectionReason: rejectionReason,
        reviewedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      
      console.log('Application rejected:', selectedAppId);
      window.alert('Application rejected successfully!');
    } catch (err) {
      console.error('Error rejecting application:', err);
      window.alert('Unable to reject application. Please try again.');
    }
  };

  // Count only image documents (old documents + image fields from fieldData)
  const documentCount = userDocuments.length;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl text-gray-100 mb-2">Customer Document Verification</h1>
        <p className="text-gray-400">Review and verify customer application documents</p>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        {/* Status filter chips */}
        <div className="flex items-center gap-2">
          <Filter className="w-5 h-5 text-gray-400 flex-shrink-0" />
          <div className="flex gap-2">
            {statusFilters.map((status) => (
              <button
                key={status.value}
                onClick={() => setFilterStatus(status.value)}
                className={`
                  px-4 py-2 rounded text-sm transition-colors
                  ${filterStatus === status.value
                    ? 'bg-[#243BFF] text-white shadow-md'
                    : 'bg-[#0f1518] text-gray-400 hover:bg-[#13171a]'
                  }
                `}
              >
                {status.label}
              </button>
            ))}
          </div>
        </div>

        {/* Service dropdown */}
        <div className="relative flex-shrink-0">
          <select
            value={selectedService}
            onChange={(e) => setSelectedService(e.target.value)}
            className="appearance-none bg-[#0f1518] text-gray-300 text-sm pl-3 pr-8 py-2 rounded border border-[#1a2130] focus:outline-none focus:border-[#243BFF] cursor-pointer min-w-[160px]"
          >
            <option value="all">All Services</option>
            {services.map((svc) => (
              <option key={svc.id} value={svc.id}>
                {svc.name}
              </option>
            ))}
          </select>
          <ChevronDown className="pointer-events-none absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        </div>

        {/* Search input */}
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by name, phone, or ID..."
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

      {error && (
        <div className="p-4 border border-[#7f1d1d] bg-[#3b0b0b] text-[#fca5a5] rounded">{error}</div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-[#071018] border border-[#111318] rounded">
          <div className="px-5 py-4 border-b border-[#111318] flex items-center justify-between">
            <h2 className="text-base text-gray-100">Customer Applications</h2>
            {loadingApps && <span className="text-xs text-gray-400">Loading...</span>}
          </div>
          <div className="divide-y divide-[#0f1518] max-h-[600px] overflow-y-auto">
            {applications.length === 0 && !loadingApps && (
              <div className="p-6 text-center text-sm text-gray-400">
                No applications found for this filter.
              </div>
            )}
            {applications.map((app) => {
              const chipClass = badgeClasses[app.status] ?? badgeClasses.pending;
              const docsInQueue = app.documents
                ? Object.keys(app.documents).length
                : 0;

              return (
                <div
                  key={app.id}
                  onClick={() => setSelectedAppId(app.id)}
                  className={`
                    p-5 cursor-pointer transition-colors
                    ${selectedAppId === app.id ? 'bg-[#0f243b]' : 'hover:bg-[#071318]'}
                  `}
                >
                  <div className="flex items-start justify-between mb-2">
                    <div>
                      <h3 className="text-sm text-gray-100">
                        {app.serviceName ?? 'Service'} ({app.serviceId})
                      </h3>
                      <p className="text-xs text-gray-400">
                        Applicant: {app.userName ?? app.userId}
                      </p>
                    </div>
                    <span className={`px-2 py-1 text-xs rounded ${chipClass}`}>
                      {app.status.charAt(0).toUpperCase() + app.status.slice(1)}
                    </span>
                  </div>
                  <div className="text-xs text-gray-400 space-y-1">
                    <p>Documents: {docsInQueue}</p>
                    <p>Updated: {formatDate(app.updatedAt)}</p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="bg-[#071018] border border-[#111318] rounded">
          {selectedApplication ? (
            <>
              <div className="px-5 py-4 border-b-2 border-[#e5e5e5]">
                <h2 className="text-base text-gray-100 mb-2">Application Details</h2>
                <div className="text-sm text-gray-400 space-y-1">
                  <p><strong>Customer:</strong> {selectedApplication.fullName || selectedApplication.userName || selectedApplication.userId}</p>
                  {selectedApplication.phone && <p><strong>Phone:</strong> {selectedApplication.phone}</p>}
                  {selectedApplication.email && <p><strong>Email:</strong> {selectedApplication.email}</p>}
                  <p><strong>Service:</strong> {selectedApplication.serviceName ?? selectedApplication.serviceId}</p>
                  
                  {/* Display text field values */}
                  {Object.keys(textFields).length > 0 && (
                    <div className="mt-3 pt-3 border-t border-[#2a3142]">
                      <p className="text-xs text-gray-500 uppercase mb-2">Form Data:</p>
                      {Object.entries(textFields).map(([fieldName, fieldValue]) => (
                        <p key={fieldName}>
                          <strong className="capitalize">{fieldName}:</strong>{' '}
                          <span className="font-mono text-gray-300">{fieldValue}</span>
                        </p>
                      ))}
                    </div>
                  )}
                  
                  {/* Filled Form submitted by user — always shown */}
                  <div className="mt-3 pt-3 border-t border-[#2a3142]">
                    <p className="text-xs text-gray-500 uppercase mb-2">Filled Form:</p>
                    {selectedApplication.filledFormUrl ? (
                      <div className="flex items-center gap-2 p-3 bg-[#071018] border border-[#111318] rounded">
                        <FileText className="w-4 h-4 text-[#4C4CFF] flex-shrink-0" />
                        <a
                          href={selectedApplication.filledFormUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex-1 text-xs text-[#4C4CFF] hover:underline truncate"
                        >
                          {selectedApplication.filledFormUrl.split('/').pop()}
                        </a>
                        <button
                          onClick={() => downloadFile(
                            selectedApplication.filledFormUrl!,
                            selectedApplication.filledFormUrl!.split('/').pop() || 'filled_form'
                          )}
                          title="Download filled form"
                          className="flex items-center gap-1 bg-[#243BFF] hover:bg-[#1e32e0] text-white text-xs font-medium px-2 py-1 rounded shadow transition-colors"
                        >
                          <Download className="w-3 h-3" />
                          Download
                        </button>
                      </div>
                    ) : (
                      <p className="text-xs text-gray-500 italic">No filled form submitted by user.</p>
                    )}
                  </div>

                  <p className="pt-2"><strong>Images Uploaded:</strong> {documentCount}</p>
                  <p><strong>Status:</strong> <span className={`px-2 py-0.5 rounded text-xs ${badgeClasses[selectedApplication.status]}`}>{selectedApplication.status}</span></p>
                </div>
              </div>

              <div className="p-5 space-y-4">
                {loadingDocs && (
                  <div className="text-center text-sm text-gray-400">Loading documents...</div>
                )}

                {!loadingDocs && userDocuments.length === 0 && (
                  <div className="text-center text-sm text-gray-400">
                    No images uploaded yet for this application.
                  </div>
                )}

                {!loadingDocs &&
                  userDocuments.map((docData) => {
                    const badgeClass =
                      badgeClasses[docData.status] ?? badgeClasses.pending;

                    return (
                      <div key={docData.id} className="border border-[#111318] rounded p-4 bg-[#071018]">
                        <div className="flex items-center justify-between mb-3">
                          <div>
                            <h3 className="text-sm text-gray-100">{docData.documentName}</h3>
                            <p className="text-xs text-gray-400">Uploaded: {formatDate(docData.uploadedAt)}</p>
                          </div>
                          <span className={`px-2 py-1 text-xs rounded ${badgeClass}`}>
                            {documentStatusLabel(docData.status)}
                          </span>
                        </div>
                        <div className="aspect-video bg-[#0f1518] rounded flex items-center justify-center mb-3 overflow-hidden relative">
                          {docData.imageUrl ? (
                            <>
                              <img
                                src={docData.imageUrl}
                                alt={docData.documentName}
                                className="w-full h-full object-contain"
                              />
                              <button
                                onClick={() => downloadFile(docData.imageUrl!, docData.documentName)}
                                title="Download file"
                                className="absolute top-2 right-2 flex items-center gap-1 bg-[#243BFF] hover:bg-[#1e32e0] text-white text-xs font-medium px-2 py-1 rounded shadow transition-colors"
                              >
                                <Download className="w-3 h-3" />
                                Download
                              </button>
                            </>
                          ) : (
                            <FileText className="w-12 h-12 text-gray-500" />
                          )}
                        </div>
                        {docData.rejectionReason && (
                          <div className="mb-3 text-xs text-[#fca5a5] bg-[#3b0b0b] border border-[#581313] rounded p-2">
                            Rejection reason: {docData.rejectionReason}
                          </div>
                        )}
                        <div className="flex gap-2">
                          <button
                            onClick={() => handleDocumentStatusChange(docData.id, 'approved')}
                            className="flex-1 flex items-center justify-center gap-2 px-3 py-2 bg-[#4CAF50] text-white rounded hover:bg-[#45a049] transition-colors text-sm"
                          >
                            <Check className="w-4 h-4" />
                            Verify
                          </button>
                          <button
                            onClick={() => handleDocumentStatusChange(docData.id, 'rejected')}
                            className="flex-1 flex items-center justify-center gap-2 px-3 py-2 bg-[#F44336] text-white rounded hover:bg-[#d32f2f] transition-colors text-sm"
                          >
                            <X className="w-4 h-4" />
                            Reject
                          </button>
                        </div>
                      </div>
                    );
                  })}
              </div>

              <div className="px-5 pb-5 pt-3 border-t-2 border-[#e5e5e5]">
                <div className="flex gap-2">
                  <button
                    onClick={handleApproveAll}
                    className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-[#4CAF50] text-white rounded hover:bg-[#45a049] transition-colors disabled:opacity-50"
                    disabled={selectedApplication?.status === 'approved'}
                  >
                    <Check className="w-4 h-4" />
                    {userDocuments.length > 0 ? 'Approve All Images' : 'Approve Application'}
                  </button>
                  <button 
                    onClick={handleRejectApplication}
                    className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-[#F44336] text-white rounded hover:bg-[#d32f2f] transition-colors disabled:opacity-50"
                    disabled={selectedApplication?.status === 'rejected'}
                  >
                    <X className="w-4 h-4" />
                    Reject Application
                  </button>
                </div>
              </div>
            </>
          ) : (
            <div className="h-full flex items-center justify-center p-8 text-center text-gray-400">
              <div>
                <FileText className="w-12 h-12 mx-auto mb-3 text-gray-500" />
                <p>Select an application to view documents</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
