import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, Check, X, FileText, Download } from 'lucide-react';
import { downloadFile } from '../../../utils/downloadFile';
import {
  getFirestore,
  onSnapshot,
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

// ── Types ─────────────────────────────────────────────────────────────────────

interface ServiceApplication {
  id: string;
  userId: string;
  serviceId: string;
  status: string;
  userName?: string;
  serviceName?: string;
  categoryName?: string;
  fullName?: string;
  phone?: string;
  email?: string;
  documents?: Record<string, string>;
  fieldData?: Record<string, any>;
  filledFormUrl?: string;
  paymentStatus?: string;
  amountPaid?: number;
  documentsMeta?: Record<
    string,
    {
      documentName?: string;
      status?: string;
      imageUrl?: string;
      rejectionReason?: string;
    }
  >;
  // Commission fields (set by Cloud Function after paid submission)
  commissionGenerated?: boolean;
  commissionAgentId?: string;
  commissionAgentName?: string;
  commissionAmount?: number;
  commissionPercentage?: number;
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
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const badgeClasses: Record<string, string> = {
  pending: 'bg-[#FFF4E6] text-[#FF9800]',
  submitted: 'bg-[#E3F2FD] text-[#1E88E5]',
  approved: 'bg-[#E8F5E9] text-[#4CAF50]',
  rejected: 'bg-[#FFEBEE] text-[#F44336]',
  draft: 'bg-[#F3F4F6] text-[#6B7280]',
};

const formatDate = (ts?: Timestamp) => {
  if (!ts) return '—';
  return ts.toDate().toLocaleString();
};

const documentStatusLabel = (status: string) => {
  switch (status) {
    case 'approved': return 'Approved';
    case 'rejected': return 'Rejected';
    case 'uploaded': return 'Uploaded';
    default: return 'Pending Review';
  }
};

// ── Component ─────────────────────────────────────────────────────────────────

export default function ApplicationDetail() {
  const { applicationId } = useParams<{ applicationId: string }>();
  const navigate = useNavigate();

  const [application, setApplication] = useState<ServiceApplication | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [userDocuments, setUserDocuments] = useState<DocumentData[]>([]);
  const [textFields, setTextFields] = useState<Record<string, string>>({});

  // ── Subscribe to single application ───────────────────────────────────────
  useEffect(() => {
    if (!applicationId) return;

    const unsubscribe = onSnapshot(
      doc(db, 'serviceApplications', applicationId),
      (snapshot) => {
        if (!snapshot.exists()) {
          setError('Application not found.');
          setLoading(false);
          return;
        }
        const data = snapshot.data();
        setApplication({
          id: snapshot.id,
          userId: data.userId,
          serviceId: data.serviceId,
          status: data.status ?? 'pending',
          userName: data.userName ?? data.fullName,
          fullName: data.fullName,
          phone: data.phone,
          email: data.email,
          serviceName: data.serviceName,
          categoryName: data.categoryName,
          documents: data.documents ?? {},
          fieldData: data.fieldData ?? {},
          filledFormUrl: data.filledFormUrl ?? '',
          paymentStatus: data.paymentStatus,
          amountPaid: data.amountPaid,
          documentsMeta: data.documentsMeta ?? {},
          commissionGenerated: data.commissionGenerated ?? false,
          commissionAgentId: data.commissionAgentId,
          commissionAgentName: data.commissionAgentName,
          commissionAmount: data.commissionAmount,
          commissionPercentage: data.commissionPercentage,
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        });
        setLoading(false);
      },
      (err) => {
        console.error('Error loading application:', err);
        setError('Unable to load application. Please try again.');
        setLoading(false);
      }
    );

    return unsubscribe;
  }, [applicationId]);

  // ── Build document / text-field data ──────────────────────────────────────
  useEffect(() => {
    if (!application) {
      setUserDocuments([]);
      setTextFields({});
      return;
    }

    const documents = application.documents || {};
    const documentsMeta = application.documentsMeta || {};

    const oldDocs: DocumentData[] = Object.entries(documents).map(([name, url]) => ({
      id: name,
      documentName: name,
      status: documentsMeta[name]?.status || 'pending',
      imageUrl: url,
      rejectionReason: documentsMeta[name]?.rejectionReason || null,
      uploadedAt: application.createdAt,
    }));

    const fieldData = application.fieldData || {};
    const imageDocs: DocumentData[] = [];
    const textFieldValues: Record<string, string> = {};

    Object.entries(fieldData).forEach(([fieldName, fieldValue]) => {
      const meta = documentsMeta[fieldName] || {};
      const isUrl =
        typeof fieldValue === 'string' &&
        (fieldValue.startsWith('http://') || fieldValue.startsWith('https://'));
      if (isUrl) {
        imageDocs.push({
          id: fieldName,
          documentName: fieldName,
          status: meta.status || 'pending',
          imageUrl: fieldValue,
          rejectionReason: meta.rejectionReason || null,
          uploadedAt: application.createdAt,
        });
      } else {
        textFieldValues[fieldName] = String(fieldValue);
      }
    });

    setUserDocuments([...oldDocs, ...imageDocs]);
    setTextFields(textFieldValues);
  }, [application]);

  // ── Actions ────────────────────────────────────────────────────────────────
  const handleDocumentStatusChange = async (docId: string, status: 'approved' | 'rejected') => {
    if (!applicationId) return;
    let rejectionReason: string | null = null;
    if (status === 'rejected') {
      rejectionReason = window.prompt('Provide a rejection reason', 'Document is unreadable') ?? 'Document rejected';
    }
    try {
      const ref = doc(db, 'serviceApplications', applicationId);
      if (status === 'rejected') {
        await updateDoc(ref, {
          [`documentsMeta.${docId}.status`]: status,
          [`documentsMeta.${docId}.rejectionReason`]: rejectionReason,
          [`documentsMeta.${docId}.reviewedAt`]: serverTimestamp(),
          status: 'rejected',
          rejectionReason: `Document "${docId}" was rejected: ${rejectionReason}`,
          reviewedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
      } else {
        await updateDoc(ref, {
          [`documentsMeta.${docId}.status`]: status,
          [`documentsMeta.${docId}.reviewedAt`]: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
      }
    } catch (err) {
      console.error('Error updating document status:', err);
      window.alert('Unable to update document. Please try again.');
    }
  };

  const handleApproveAll = async () => {
    if (!applicationId) return;
    try {
      const ref = doc(db, 'serviceApplications', applicationId);
      const updates: Record<string, any> = {
        status: 'approved',
        reviewedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };
      userDocuments.forEach((d) => {
        updates[`documentsMeta.${d.id}.status`] = 'approved';
        updates[`documentsMeta.${d.id}.reviewedAt`] = serverTimestamp();
      });
      await updateDoc(ref, updates);
      window.alert('Application approved successfully!');
    } catch (err) {
      console.error('Error approving:', err);
      window.alert('Unable to approve application. Please try again.');
    }
  };

  const handleRejectApplication = async () => {
    if (!applicationId) return;
    const reason = window.prompt('Provide a rejection reason:', 'Application does not meet requirements');
    if (!reason) return;
    try {
      await updateDoc(doc(db, 'serviceApplications', applicationId), {
        status: 'rejected',
        rejectionReason: reason,
        reviewedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      window.alert('Application rejected successfully!');
    } catch (err) {
      console.error('Error rejecting:', err);
      window.alert('Unable to reject application. Please try again.');
    }
  };

  // ── Loading / error states ─────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-400">Loading application…</div>
      </div>
    );
  }

  if (error || !application) {
    return (
      <div className="space-y-4">
        <button
          onClick={() => navigate(-1)}
          className="flex items-center gap-2 text-gray-400 hover:text-gray-100 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
        <div className="p-4 border border-[#7f1d1d] bg-[#3b0b0b] text-[#fca5a5] rounded">
          {error ?? 'Application not found.'}
        </div>
      </div>
    );
  }

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6 max-w-3xl mx-auto">
      {/* Header / breadcrumb */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => navigate(-1)}
          className="p-2 text-gray-400 hover:text-gray-100 hover:bg-[#0f1518] rounded transition-colors"
          title="Back"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div>
          {application.categoryName && (
            <p className="text-xs text-gray-500">{application.categoryName}</p>
          )}
          <h1 className="text-2xl text-gray-100">
            {application.fullName || application.userName || application.userId}
          </h1>
          <p className="text-sm text-gray-400">
            {application.serviceName ?? application.serviceId}
          </p>
        </div>
        <span
          className={`ml-auto px-3 py-1 text-sm rounded ${badgeClasses[application.status] ?? badgeClasses.pending}`}
        >
          {application.status.charAt(0).toUpperCase() + application.status.slice(1)}
        </span>
      </div>

      {/* Customer info */}
      <div className="bg-[#071018] border border-[#111318] rounded p-5">
        <h2 className="text-base text-gray-100 mb-3 pb-3 border-b border-[#111318]">
          Customer Information
        </h2>
        <div className="text-sm text-gray-400 space-y-2">
          <p>
            <strong className="text-gray-300">Name:</strong>{' '}
            {application.fullName || application.userName || application.userId}
          </p>
          {application.phone && (
            <p><strong className="text-gray-300">Phone:</strong> {application.phone}</p>
          )}
          {application.email && (
            <p><strong className="text-gray-300">Email:</strong> {application.email}</p>
          )}
          <p>
            <strong className="text-gray-300">Service:</strong>{' '}
            {application.serviceName ?? application.serviceId}
          </p>
          <p>
            <strong className="text-gray-300">Submitted:</strong> {formatDate(application.createdAt)}
          </p>
        </div>
      </div>

      {/* Payment */}
      {application.paymentStatus && (
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-base text-gray-100 mb-3 pb-3 border-b border-[#111318]">
            Payment
          </h2>
          <div className="text-sm text-gray-400 space-y-2">
            <p>
              <strong className="text-gray-300">Payment Status:</strong>{' '}
              {application.paymentStatus === 'paid' ? (
                <span className="text-green-400 font-medium">✓ Paid</span>
              ) : (
                <span className="text-gray-400">Free (No Fee Required)</span>
              )}
            </p>
            {application.paymentStatus === 'paid' && application.amountPaid !== undefined && (
              <p>
                <strong className="text-gray-300">Amount Paid:</strong>{' '}
                <span className="text-green-400 font-medium">₹{application.amountPaid}</span>
              </p>
            )}
          </div>
        </div>
      )}

      {/* Form Data */}
      {Object.keys(textFields).length > 0 && (
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-base text-gray-100 mb-3 pb-3 border-b border-[#111318]">
            Form Data
          </h2>
          <div className="text-sm text-gray-400 space-y-2">
            {Object.entries(textFields).map(([k, v]) => (
              <p key={k}>
                <strong className="text-gray-300 capitalize">{k}:</strong>{' '}
                <span className="font-mono text-gray-300">{v}</span>
              </p>
            ))}
          </div>
        </div>
      )}

      {/* Filled Form */}
      <div className="bg-[#071018] border border-[#111318] rounded p-5">
        <h2 className="text-base text-gray-100 mb-3 pb-3 border-b border-[#111318]">
          Filled Form
        </h2>
        {application.filledFormUrl ? (
          <div className="flex items-center gap-2 p-3 bg-[#0f1518] border border-[#1a2130] rounded">
            <FileText className="w-4 h-4 text-[#4C4CFF] flex-shrink-0" />
            <a
              href={application.filledFormUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 text-xs text-[#4C4CFF] hover:underline truncate"
            >
              {application.filledFormUrl.split('/').pop()}
            </a>
            <button
              onClick={() =>
                downloadFile(
                  application.filledFormUrl!,
                  application.filledFormUrl!.split('/').pop() || 'filled_form'
                )
              }
              className="flex items-center gap-1 bg-[#243BFF] hover:bg-[#1e32e0] text-white text-xs font-medium px-2 py-1 rounded shadow transition-colors"
            >
              <Download className="w-3 h-3" />
              Download
            </button>
          </div>
        ) : (
          <p className="text-xs text-gray-500 italic">No filled form submitted.</p>
        )}
      </div>

      {/* Image documents */}
      {userDocuments.length > 0 && (
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-base text-gray-100 mb-4 pb-3 border-b border-[#111318]">
            Uploaded Documents ({userDocuments.length})
          </h2>
          <div className="space-y-4">
            {userDocuments.map((docData) => {
              const badgeClass = badgeClasses[docData.status] ?? badgeClasses.pending;
              return (
                <div key={docData.id} className="border border-[#111318] rounded p-4 bg-[#0a1520]">
                  <div className="flex items-center justify-between mb-3">
                    <div>
                      <h3 className="text-sm text-gray-100">{docData.documentName}</h3>
                      <p className="text-xs text-gray-400">
                        Uploaded: {formatDate(docData.uploadedAt)}
                      </p>
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
        </div>
      )}

      {/* Commission Info */}
      {application.paymentStatus === 'paid' && (
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <h2 className="text-base text-gray-100 mb-3 pb-3 border-b border-[#111318]">
            Referral Commission
          </h2>
          {application.commissionGenerated ? (
            <div className="space-y-2 text-sm">
              <div className="flex items-center gap-2 mb-3">
                <span className="inline-flex items-center gap-1 px-2 py-1 bg-[#e8f5e9] text-[#4CAF50] text-xs rounded font-medium">
                  ✓ Commission Generated
                </span>
              </div>
              <p>
                <strong className="text-gray-300">Referred Agent:</strong>{' '}
                <span className="text-gray-100">{application.commissionAgentName || '—'}</span>
              </p>
              <p>
                <strong className="text-gray-300">Agent ID:</strong>{' '}
                <span className="text-gray-400 font-mono text-xs">{application.commissionAgentId || '—'}</span>
              </p>
              <p>
                <strong className="text-gray-300">Service Fee:</strong>{' '}
                <span className="text-gray-100">₹{application.amountPaid ?? 0}</span>
              </p>
              <p>
                <strong className="text-gray-300">Commission Rate:</strong>{' '}
                <span className="text-gray-100">{application.commissionPercentage ?? '—'}%</span>
              </p>
              <p>
                <strong className="text-gray-300">Commission Credited:</strong>{' '}
                <span className="text-green-400 font-semibold">₹{application.commissionAmount?.toLocaleString('en-IN') ?? 0}</span>
              </p>
            </div>
          ) : (
            <p className="text-sm text-gray-400">
              {application.paymentStatus === 'paid'
                ? 'This user was not referred by any agent — no commission applicable.'
                : 'Commission is only generated for paid applications.'}
            </p>
          )}
        </div>
      )}

      {/* Approve / Reject application */}
      <div className="bg-[#071018] border border-[#111318] rounded p-5">
        <div className="flex gap-3">
          <button
            onClick={handleApproveAll}
            disabled={application.status === 'approved'}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-[#4CAF50] text-white rounded hover:bg-[#45a049] transition-colors disabled:opacity-50"
          >
            <Check className="w-4 h-4" />
            {userDocuments.length > 0 ? 'Approve All Images' : 'Approve Application'}
          </button>
          <button
            onClick={handleRejectApplication}
            disabled={application.status === 'rejected'}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-[#F44336] text-white rounded hover:bg-[#d32f2f] transition-colors disabled:opacity-50"
          >
            <X className="w-4 h-4" />
            Reject Application
          </button>
        </div>
      </div>
    </div>
  );
}
