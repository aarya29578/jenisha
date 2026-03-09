import { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, Image as ImageIcon, Eye, Upload } from 'lucide-react';
import { getFirestore, collection, addDoc, setDoc, getDoc, updateDoc, deleteDoc, doc, onSnapshot, serverTimestamp, query, orderBy } from 'firebase/firestore';
import { initializeApp } from 'firebase/app';

// Firebase Configuration
const firebaseConfig = {
  apiKey: 'AIzaSyC72UmM3pMwRBh0pKjKy_jN9wmpE_MP_GM',
  authDomain: 'jenisha-46c62.firebaseapp.com',
  projectId: 'jenisha-46c62',
  storageBucket: 'jenisha-46c62.appspot.com',
  messagingSenderId: '245020879102',
  appId: '1:245020879102:web:05969fe2820677483c9daf',
};

const app = initializeApp(firebaseConfig);
const firestore = getFirestore(app);
// Note: Uploads are handled via Hostinger PHP endpoint (upload_banner.php)

interface Banner {
  id: string;
  imageUrl: string;
  active: boolean;
  order: number;
  createdAt: any;
}

export default function BannerManagement() {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [showAddBanner, setShowAddBanner] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [newBannerOrder, setNewBannerOrder] = useState(0);
  const [newBannerActive, setNewBannerActive] = useState(true);
  const [newBannerUrl, setNewBannerUrl] = useState('');
  const [uploading, setUploading] = useState(false);
  const [editingBanner, setEditingBanner] = useState<Banner | null>(null);

  useEffect(() => {
    const q = query(collection(firestore, 'banners'), orderBy('order', 'asc'));
    const unsubscribe = onSnapshot(q, 
      (snapshot) => {
        const bannersData = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        })) as Banner[];
        setBanners(bannersData);
      },
      (error) => {
        console.error('Error fetching banners:', error);
      }
    );

    return () => unsubscribe();
  }, []);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // Validate file type
      if (!file.type.startsWith('image/')) {
        alert('Please select an image file (PNG, JPG, JPEG)');
        return;
      }

      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        alert('File size must be less than 5MB');
        return;
      }

      setSelectedFile(file);

      // Create preview
      const reader = new FileReader();
      reader.onloadend = () => {
        setPreviewUrl(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleAddBanner = async () => {
    if (!selectedFile) {
      alert('Please select an image');
      return;
    }

    try {
      setUploading(true);

      // Upload to Hostinger PHP endpoint and then save metadata to Firestore
      const bannerId = `banner_${Date.now()}`;
      const UPLOAD_ENDPOINT = 'https://jenishaonlineservice.com/uploads/upload_banner.php';

      console.log('🚀 Starting banner upload...');
      console.log('API URL:', UPLOAD_ENDPOINT);
      console.log('File name:', selectedFile.name);
      console.log('File size:', selectedFile.size);
      console.log('File type:', selectedFile.type);

      // Build multipart form data
      const formData = new FormData();
      formData.append('banner', selectedFile as File);

      let downloadURL = '';
      try {
        console.log('📤 Sending POST request to:', UPLOAD_ENDPOINT);
        const resp = await fetch(UPLOAD_ENDPOINT, {
          method: 'POST',
          body: formData,
          mode: 'cors',
          credentials: 'omit'
        });

        console.log('📥 Response status:', resp.status);
        console.log('� Response statusText:', resp.statusText);
        console.log('📥 Response headers:', Object.fromEntries(resp.headers.entries()));

        // Try to read response as text first to see what we're getting
        const responseText = await resp.text();
        console.log('📥 Response body (raw text):', responseText);

        if (!resp.ok) {
          console.error('❌ Upload endpoint returned non-OK:', resp.status);
          alert(`Upload failed with status ${resp.status} (${resp.statusText}). Check console for details.`);
          throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
        }

        // Now try to parse as JSON
        if (!responseText) {
          throw new Error('Empty response from server');
        }

        let json;
        try {
          json = JSON.parse(responseText);
        } catch (parseError) {
          console.error('❌ Failed to parse JSON:', parseError);
          console.error('❌ Response text was:', responseText);
          throw new Error(`Failed to parse response: ${parseError}`);
        }

        console.log('✅ Upload response:', json);
        console.log('✅ Response type:', typeof json);
        console.log('✅ Response keys:', Object.keys(json || {}));
        console.log('✅ success value:', json?.success);
        console.log('✅ imageUrl value:', json?.imageUrl);
        
        if (!json || json.success !== true || !json.imageUrl || typeof json.imageUrl !== 'string') {
          console.error('❌ Invalid upload response:', json);
          console.error('❌ Error message:', json?.error || json?.message);
          alert(`Upload failed: ${json?.error || json?.message || 'Invalid response from server'}`);
          throw new Error('Invalid upload response');
        }

        downloadURL = json.imageUrl;
        console.log('✅ Image URL received:', downloadURL);
      } catch (uploadError: any) {
        console.error('❌ Banner upload error:', uploadError);
        console.error('❌ Error type:', uploadError.constructor.name);
        console.error('❌ Error message:', uploadError.message);
        console.error('❌ Full error:', JSON.stringify(uploadError, null, 2));
        
        // Provide detailed error message
        let errorMsg = uploadError.message || 'Unknown error occurred';
        
        if (uploadError.message === 'Failed to fetch') {
          errorMsg = 'Network error: Failed to connect to server.\n\nPossible causes:\n1. Server is down or unreachable\n2. CORS policy issue\n3. Invalid URL\n4. Connection timeout';
        } else if (uploadError.message.includes('HTTP')) {
          errorMsg = `HTTP Error: ${uploadError.message}`;
        }
        
        alert(`Upload failed: ${errorMsg}\n\nCheck console for detailed debugging information.`);
        throw uploadError;
      }

      // Save banner to Firestore with returned imageUrl
      const bannerDocRef = doc(firestore, 'banners', bannerId);
      await setDoc(bannerDocRef, {
        imageUrl: downloadURL,
        active: newBannerActive ?? true,
        order: typeof newBannerOrder === 'number' ? newBannerOrder : 0,
        linkUrl: newBannerUrl.trim() || null,
        createdAt: serverTimestamp(),
      });

      // Reset form
      setSelectedFile(null);
      setPreviewUrl(null);
      setNewBannerOrder(0);
      setNewBannerActive(true);
      setNewBannerUrl('');
      setShowAddBanner(false);
      alert('Banner added successfully!');
    } catch (error) {
      console.error('Error adding banner:', error);
      alert('Failed to add banner. Please try again.');
    } finally {
      setUploading(false);
    }
  };

  const handleToggleActive = async (bannerId: string, currentActive: boolean) => {
    try {
      const bannerRef = doc(firestore, 'banners', bannerId);
      await updateDoc(bannerRef, {
        active: !currentActive,
      });
    } catch (error) {
      console.error('Error toggling banner status:', error);
      alert('Failed to update banner status');
    }
  };

  const handleUpdateOrder = async (bannerId: string, newOrder: number) => {
    try {
      const bannerRef = doc(firestore, 'banners', bannerId);
      await updateDoc(bannerRef, {
        order: newOrder,
      });
    } catch (error) {
      console.error('Error updating banner order:', error);
      alert('Failed to update banner order');
    }
  };

  const handleDeleteBanner = async (bannerId: string, imageUrl: string) => {
    if (!confirm('Are you sure you want to delete this banner?')) {
      return;
    }

    try {
        // Delete from Firestore only (image stays on Hostinger storage)
        try {
          const bannerDocRef = doc(firestore, 'banners', bannerId);
          await deleteDoc(bannerDocRef);
        } catch (error) {
          console.error('Error deleting banner:', error);
          alert('Failed to delete banner');
        }

      alert('Banner deleted successfully!');
    } catch (error) {
      console.error('Error deleting banner:', error);
      alert('Failed to delete banner');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold text-gray-100">Banner Management</h2>
          <p className="text-sm text-gray-400 mt-1">Manage promotional banners for the app home page</p>
        </div>
        <button
          onClick={() => setShowAddBanner(true)}
          className="flex items-center gap-2 px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors"
        >
          <Plus className="w-4 h-4" />
          <span className="text-sm">Add Banner</span>
        </button>
      </div>

      {/* Add Banner Form */}
      {showAddBanner && (
        <div className="bg-[#071018] border border-[#111318] rounded p-6">
          <h3 className="text-base text-gray-100 mb-4">Add New Banner</h3>
          <div className="space-y-4">
            {/* File Upload */}
            <div>
              <label className="block text-sm text-gray-100 mb-2">Banner Image</label>
              {!previewUrl ? (
                <div>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleFileChange}
                    className="hidden"
                    id="banner-upload"
                  />
                  <label
                    htmlFor="banner-upload"
                    className="inline-flex items-center gap-2 px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] cursor-pointer transition-colors"
                  >
                    <Upload className="w-4 h-4" />
                    <span className="text-sm">Choose Image</span>
                  </label>
                  <p className="text-xs text-gray-500 mt-2">PNG, JPG, JPEG (Max 5MB) - Recommended: 800x300px</p>
                </div>
              ) : (
                <div className="space-y-3">
                  <div className="relative">
                    <img
                      src={previewUrl}
                      alt="Banner preview"
                      className="w-full h-48 object-cover border border-[#111318] rounded"
                    />
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setSelectedFile(null);
                      setPreviewUrl(null);
                    }}
                    className="text-xs text-red-400 hover:text-red-300 transition-colors"
                  >
                    Remove Image
                  </button>
                </div>
              )}
            </div>

            {/* Order */}
            <div>
              <label className="block text-sm text-gray-100 mb-2">Display Order</label>
              <input
                type="number"
                value={newBannerOrder}
                onChange={(e) => setNewBannerOrder(parseInt(e.target.value) || 0)}
                className="w-full px-4 py-2 border border-[#111318] rounded bg-[#071018] text-gray-100 focus:outline-none focus:border-[#243BFF]"
                placeholder="0"
              />
              <p className="text-xs text-gray-500 mt-1">Lower numbers appear first</p>
            </div>

            {/* Hyperlink URL */}
            <div>
              <label className="block text-sm text-gray-100 mb-2">Link URL (Optional)</label>
              <input
                type="url"
                value={newBannerUrl}
                onChange={(e) => setNewBannerUrl(e.target.value)}
                className="w-full px-4 py-2 border border-[#111318] rounded bg-[#071018] text-gray-100 focus:outline-none focus:border-[#243BFF]"
                placeholder="https://example.com"
              />
              <p className="text-xs text-gray-500 mt-1">Banner will open this URL when tapped in the app</p>
            </div>

            {/* Active Status */}
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="banner-active"
                checked={newBannerActive}
                onChange={(e) => setNewBannerActive(e.target.checked)}
                className="w-4 h-4"
              />
              <label htmlFor="banner-active" className="text-sm text-gray-100">
                Active (show in app)
              </label>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-2">
              <button
                onClick={handleAddBanner}
                disabled={!selectedFile || uploading}
                className="px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {uploading ? 'Uploading...' : 'Save Banner'}
              </button>
              <button
                onClick={() => {
                  setShowAddBanner(false);
                  setSelectedFile(null);
                  setPreviewUrl(null);
                }}
                className="px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Banners List */}
      {banners.length === 0 ? (
        <div className="text-center py-8 bg-[#071018] border border-[#111318] rounded">
          <ImageIcon className="w-12 h-12 text-gray-500 mx-auto mb-3" />
          <p className="text-gray-400">No banners yet. Add one to get started!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {banners.map((banner) => (
            <div key={banner.id} className="bg-[#071018] border border-[#111318] rounded p-4">
              <div className="relative mb-3">
                <img
                  src={banner.imageUrl}
                  alt="Banner"
                  className="w-full h-32 object-cover rounded"
                />
                <div className="absolute top-2 right-2 flex gap-1">
                  <span
                    className={`px-2 py-1 text-xs rounded ${
                      banner.active
                        ? 'bg-[#08310b] text-white'
                        : 'bg-[#0f1518] text-gray-400'
                    }`}
                  >
                    {banner.active ? 'Active' : 'Inactive'}
                  </span>
                </div>
              </div>
              
              <div className="flex items-center justify-between mb-3">
                <div>
                  <p className="text-sm text-gray-400">Order: {banner.order}</p>
                </div>
                <div className="flex gap-1">
                  <button
                    onClick={() => handleToggleActive(banner.id, banner.active)}
                    className="p-1.5 text-[#243BFF] hover:bg-[#0f243b] rounded transition-colors"
                    title={banner.active ? 'Deactivate' : 'Activate'}
                  >
                    <Eye className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleDeleteBanner(banner.id, banner.imageUrl)}
                    className="p-1.5 text-[#F44336] hover:bg-[#2a0b0b] rounded transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <label className="text-xs text-gray-400">Change Order:</label>
                <input
                  type="number"
                  value={banner.order}
                  onChange={(e) => handleUpdateOrder(banner.id, parseInt(e.target.value) || 0)}
                  className="w-20 px-2 py-1 text-sm border border-[#111318] rounded bg-[#071018] text-gray-100 focus:outline-none focus:border-[#243BFF]"
                />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
