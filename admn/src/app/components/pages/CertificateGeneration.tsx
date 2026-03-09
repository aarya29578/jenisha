import { useState, useEffect, useRef } from 'react';
import { Upload, Download, Check, Shield } from 'lucide-react';
import {
  getFirestore,
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  doc,
  updateDoc,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
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

interface VerifiedApplication {
  id: string;
  customer: string;
  service: string;
  agent: string;
  date: string;
  status: string;
  certificateUrl?: string;
}

const formatDate = (timestamp: Timestamp | null | undefined) => {
  if (!timestamp) return '—';
  return timestamp.toDate().toLocaleDateString('en-IN');
};

export default function CertificateGeneration() {
  const [verifiedApplications, setVerifiedApplications] = useState<VerifiedApplication[]>([]);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState<string | null>(null);
  const fileInputRefs = useRef<{ [key: string]: HTMLInputElement | null }>({});

  useEffect(() => {
    // Fetch approved service applications
    const q = query(
      collection(db, 'serviceApplications'),
      where('status', '==', 'approved'),
      orderBy('createdAt', 'desc')
    );

    const unsubscribe = onSnapshot(q, (snapshot) => {
      const apps: VerifiedApplication[] = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          customer: data.fullName || 'Unknown Customer',
          service: data.serviceName || data.serviceId || 'Unknown Service',
          agent: data.userName || 'Unknown Agent',
          date: formatDate(data.createdAt),
          status: data.certificateUrl ? 'Generated' : 'Ready',
          certificateUrl: data.certificateUrl,
        };
      });
      setVerifiedApplications(apps);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const handleUploadClick = (appId: string) => {
    fileInputRefs.current[appId]?.click();
  };

  const handleFileSelect = async (appId: string, event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    // Validate file type
    if (!file.type.startsWith('image/')) {
      alert('Please select an image file');
      return;
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      alert('File size must be less than 5MB');
      return;
    }

    setUploading(appId);

    try {
      // Convert to base64
      const base64 = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
          const result = reader.result as string;
          resolve(result.split(',')[1]); // Remove data:image/xxx;base64, prefix
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });

      // Upload to Hostinger PHP backend
      const response = await fetch('https://jenishaonlineservice.com/uploads/upload_field.php', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          image: base64,
          filename: `certificate_${appId}_${Date.now()}.jpg`,
        }),
      });

      const data = await response.json();

      if (data.success && data.url) {
        // Update Firestore with certificate URL and status
        const currentAdmin = authService.getCurrentUser();
        const appRef = doc(db, 'serviceApplications', appId);
        await updateDoc(appRef, {
          status: 'generated',
          certificateUrl: data.url,
          certificateGeneratedAt: serverTimestamp(),
          updatedBy: currentAdmin?.uid || 'unknown',
          updatedAt: serverTimestamp(),
        });

        console.log('✅ Certificate uploaded and status updated to generated:', data.url);
        alert('Certificate uploaded successfully! Status updated to Generated.');
      } else {
        throw new Error(data.error || 'Upload failed');
      }
    } catch (error) {
      console.error('Error uploading certificate:', error);
      alert('Failed to upload certificate. Please try again.');
    } finally {
      setUploading(null);
      // Reset file input
      if (fileInputRefs.current[appId]) {
        fileInputRefs.current[appId]!.value = '';
      }
    }
  };
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl text-[#1a1a1a] mb-2">Certificate Generation & Upload</h1>
        <p className="text-[#666666]">Generate and upload certificates for verified applications</p>
      </div>

      <div className="bg-white border-2 border-[#e5e5e5] rounded overflow-hidden">
        <table className="w-full">
          <thead className="bg-[#f5f5f5] border-b-2 border-[#e5e5e5]">
            <tr>
              <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Customer Name</th>
              <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Service</th>
              <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Agent</th>
              <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Date</th>
              <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Status</th>
              <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y-2 divide-[#e5e5e5]">
            {loading ? (
              <tr>
                <td colSpan={6} className="px-5 py-8 text-center text-sm text-[#666666]">
                  Loading applications...
                </td>
              </tr>
            ) : verifiedApplications.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-5 py-8 text-center text-sm text-[#666666]">
                  No approved applications found
                </td>
              </tr>
            ) : (
              verifiedApplications.map((app) => (
                <tr key={app.id} className="hover:bg-[#fafafa]">
                  <td className="px-5 py-4 text-sm text-[#1a1a1a]">{app.customer}</td>
                  <td className="px-5 py-4 text-sm text-[#666666]">{app.service}</td>
                  <td className="px-5 py-4 text-sm text-[#666666]">{app.agent}</td>
                  <td className="px-5 py-4 text-sm text-[#666666]">{app.date}</td>
                  <td className="px-5 py-4">
                    <span className={`inline-block px-3 py-1 text-xs rounded ${
                      app.status === 'Generated' ? 'bg-[#E8F5E9] text-[#4CAF50]' : 'bg-[#FFF4E6] text-[#FF9800]'
                    }`}>
                      {app.status}
                    </span>
                  </td>
                  <td className="px-5 py-4">
                    {app.status === 'Ready' ? (
                      <>
                        <input
                          type="file"
                          ref={(el) => fileInputRefs.current[app.id] = el}
                          onChange={(e) => handleFileSelect(app.id, e)}
                          accept="image/*"
                          className="hidden"
                        />
                        <button 
                          onClick={() => handleUploadClick(app.id)}
                          disabled={uploading === app.id}
                          className="flex items-center gap-2 px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          <Upload className="w-4 h-4" />
                          {uploading === app.id ? 'Uploading...' : 'Upload Certificate'}
                        </button>
                      </>
                    ) : (
                      <a
                        href={app.certificateUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-2 px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors text-sm"
                      >
                        <Download className="w-4 h-4" />
                        Download
                      </a>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="bg-white border-2 border-[#e5e5e5] rounded p-4">
        <div className="flex items-start gap-3">
          <Check className="w-5 h-5 text-[#4C4CFF] flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-sm text-[#1a1a1a] mb-1">Connection to Agent App</h3>
            <p className="text-sm text-[#666666]">
              Once certificate is marked as "Generated", agents can see status update and download/share the certificate directly from their mobile app.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
