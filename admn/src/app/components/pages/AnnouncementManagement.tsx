import { useState, useEffect, useRef } from 'react';
import { Plus, Trash2, Megaphone, ToggleLeft, ToggleRight, Link as LinkIcon } from 'lucide-react';
import {
  getFirestore,
  collection,
  addDoc,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  serverTimestamp,
  query,
  orderBy,
  limit,
  writeBatch,
  getDocs,
  where,
} from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { initializeApp } from 'firebase/app';

// ── Firebase (same config used by every admin page) ─────────────────────────
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

// ── Types ────────────────────────────────────────────────────────────────────
interface Announcement {
  id: string;
  title: string;
  url: string;
  isActive: boolean;
  createdAt: any;
}

// ── Component ────────────────────────────────────────────────────────────────
export default function AnnouncementManagement() {
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [showAddForm, setShowAddForm] = useState(false);
  const [saving, setSaving] = useState(false);
  const seeded = useRef(false); // prevents double-seed in React StrictMode

  // ── Phase 4 — Auth debug log ───────────────────────────────────────────────
  // Logs the current Firebase auth UID and the role stored in admin_users.
  // If 'No admin_users document found' appears, the user cannot write to
  // Firestore (isAdmin() returns false) — create the document manually.
  useEffect(() => {
    (async () => {
      try {
        const auth = getAuth(app);
        const user = auth.currentUser;
        if (!user) {
          console.warn('[AnnouncementMgmt] ⚠️  No authenticated Firebase user found.');
          return;
        }
        console.log('[AnnouncementMgmt] ✅ Auth UID:', user.uid);
        console.log('[AnnouncementMgmt] ✅ Auth Email:', user.email);

        const adminDoc = await getDoc(doc(firestore, 'admin_users', user.uid));
        if (!adminDoc.exists()) {
          console.error(
            '[AnnouncementMgmt] ❌ No admin_users document found for UID:',
            user.uid,
            '— isAdmin() will return false. Firestore writes will be DENIED.'
          );
        } else {
          const data = adminDoc.data();
          console.log('[AnnouncementMgmt] ✅ admin_users role:', data?.role ?? '(field missing)');
          console.log('[AnnouncementMgmt] ✅ admin_users document:', data);
        }
      } catch (err) {
        console.error('[AnnouncementMgmt] Auth debug error:', err);
      }
    })();
  }, []);

  // Form state
  const [title, setTitle] = useState('');
  const [url, setUrl] = useState('');
  const [isActive, setIsActive] = useState(false);

  // ── Seed collection on first visit (runs once) ─────────────────────────────
  // Firestore does NOT create collections until a document is written.
  // This check is O(1) — it fetches at most 1 document.
  useEffect(() => {
    if (seeded.current) return;
    seeded.current = true;

    (async () => {
      try {
        const snap = await getDocs(
          query(collection(firestore, 'announcements'), limit(1))
        );
        if (snap.empty) {
          // Collection doesn't exist yet — seed a default (inactive) document
          await addDoc(collection(firestore, 'announcements'), {
            title: 'Welcome to Jenisha 🚀',
            url: 'https://google.com',
            isActive: false,
            createdAt: serverTimestamp(),
          });
          console.log('📢 announcements collection seeded with default document.');
        }
      } catch (err) {
        // Non-fatal — admin can still add documents manually
        console.warn('Could not seed announcements collection:', err);
      }
    })();
  }, []);

  // ── Real-time listener ─────────────────────────────────────────────────────
  // NOTE: The Flutter app queries:
  //   .where('isActive', '==', true)
  //   .orderBy('createdAt', 'desc')
  //   .limit(1)
  // This requires a Firestore composite index:
  //   Collection : announcements
  //   Fields     : isActive ASC  +  createdAt DESC
  // Create it in Firebase Console → Firestore → Indexes → Composite.
  useEffect(() => {
    const q = query(
      collection(firestore, 'announcements'),
      orderBy('createdAt', 'desc')
    );
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const data = snapshot.docs.map((d) => ({
          id: d.id,
          ...(d.data() as Omit<Announcement, 'id'>),
        }));
        setAnnouncements(data);
      },
      (err) => console.error('Error fetching announcements:', err)
    );
    return () => unsubscribe();
  }, []);

  // ── Add announcement (fully atomic single writeBatch) ────────────────────
  // Uses batch.set() with an auto-generated ref so deactivating others and
  // writing the new document are committed in one atomic operation.
  const handleAdd = async () => {
    if (!title.trim()) {
      alert('Title is required.');
      return;
    }
    try {
      setSaving(true);
      const batch = writeBatch(firestore);

      // If the new doc will be active, deactivate every currently-active doc first
      if (isActive) {
        const activeSnap = await getDocs(
          query(collection(firestore, 'announcements'), where('isActive', '==', true))
        );
        activeSnap.docs.forEach((d) => {
          batch.update(doc(firestore, 'announcements', d.id), { isActive: false });
        });
      }

      // Set the new document using an auto-generated ref
      const newRef = doc(collection(firestore, 'announcements'));
      batch.set(newRef, {
        title: title.trim(),
        url: url.trim(),
        isActive,
        createdAt: serverTimestamp(),
      });

      await batch.commit();

      // Reset form
      setTitle('');
      setUrl('');
      setIsActive(false);
      setShowAddForm(false);
    } catch (err) {
      console.error('Error adding announcement:', err);
      alert('Failed to save announcement.');
    } finally {
      setSaving(false);
    }
  };

  // ── Toggle active (fully atomic single writeBatch) ────────────────────────
  // Both deactivating others AND activating the chosen doc happen in one commit.
  const handleToggle = async (item: Announcement) => {
    try {
      const batch = writeBatch(firestore);

      if (!item.isActive) {
        // Activating: deactivate every other active doc in the same batch
        const activeSnap = await getDocs(
          query(collection(firestore, 'announcements'), where('isActive', '==', true))
        );
        activeSnap.docs.forEach((d) => {
          if (d.id !== item.id) {
            batch.update(doc(firestore, 'announcements', d.id), { isActive: false });
          }
        });
      }

      // Flip the chosen document's status
      batch.update(doc(firestore, 'announcements', item.id), {
        isActive: !item.isActive,
      });

      await batch.commit();
    } catch (err) {
      console.error('Error toggling announcement:', err);
      alert('Failed to update status.');
    }
  };

  // ── Delete ─────────────────────────────────────────────────────────────────
  const handleDelete = async (id: string) => {
    if (!confirm('Delete this announcement?')) return;
    try {
      await deleteDoc(doc(firestore, 'announcements', id));
    } catch (err) {
      console.error('Error deleting announcement:', err);
      alert('Failed to delete announcement.');
    }
  };

  // ── Render ──────────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-semibold text-gray-100">Announcement Management</h2>
          <p className="text-sm text-gray-400 mt-1">
            Control the scrolling announcement banner shown on the app home screen.
            Only one announcement can be active at a time.
          </p>
        </div>
        <button
          onClick={() => setShowAddForm(true)}
          className="flex items-center gap-2 px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors"
        >
          <Plus className="w-4 h-4" />
          <span className="text-sm">Add Announcement</span>
        </button>
      </div>

      {/* Add Form */}
      {showAddForm && (
        <div className="bg-[#071018] border border-[#111318] rounded p-6">
          <h3 className="text-base text-gray-100 mb-4">New Announcement</h3>
          <div className="space-y-4">
            {/* Title */}
            <div>
              <label className="block text-sm text-gray-300 mb-1">
                Title <span className="text-red-400">*</span>
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. New Aadhaar update services now available!"
                className="w-full px-4 py-2 border border-[#111318] rounded bg-[#0b1524] text-gray-100 placeholder-gray-500 focus:outline-none focus:border-[#243BFF]"
              />
            </div>

            {/* URL */}
            <div>
              <label className="block text-sm text-gray-300 mb-1">URL (optional)</label>
              <div className="relative">
                <LinkIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" />
                <input
                  type="url"
                  value={url}
                  onChange={(e) => setUrl(e.target.value)}
                  placeholder="https://example.com"
                  className="w-full pl-9 pr-4 py-2 border border-[#111318] rounded bg-[#0b1524] text-gray-100 placeholder-gray-500 focus:outline-none focus:border-[#243BFF]"
                />
              </div>
              <p className="text-xs text-gray-500 mt-1">
                Opens this URL when user taps the banner in the app.
              </p>
            </div>

            {/* Active toggle */}
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => setIsActive((v) => !v)}
                className="focus:outline-none"
                title={isActive ? 'Active' : 'Inactive'}
              >
                {isActive ? (
                  <ToggleRight className="w-8 h-8 text-[#243BFF]" />
                ) : (
                  <ToggleLeft className="w-8 h-8 text-gray-500" />
                )}
              </button>
              <span className="text-sm text-gray-300">
                {isActive
                  ? 'Active — will be shown in app (others will be deactivated)'
                  : 'Inactive — will not be shown in app'}
              </span>
            </div>

            {/* Actions */}
            <div className="flex gap-2 pt-2">
              <button
                onClick={handleAdd}
                disabled={saving}
                className="px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {saving ? 'Saving…' : 'Save Announcement'}
              </button>
              <button
                onClick={() => {
                  setShowAddForm(false);
                  setTitle('');
                  setUrl('');
                  setIsActive(false);
                }}
                className="px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* List */}
      {announcements.length === 0 ? (
        <div className="text-center py-12 bg-[#071018] border border-[#111318] rounded">
          <Megaphone className="w-12 h-12 text-gray-600 mx-auto mb-3" />
          <p className="text-gray-400">No announcements yet. Add one to get started!</p>
        </div>
      ) : (
        <div className="space-y-3">
          {announcements.map((item) => (
            <div
              key={item.id}
              className={`bg-[#071018] border rounded p-4 flex items-start justify-between gap-4 ${
                item.isActive ? 'border-[#243BFF]/40' : 'border-[#111318]'
              }`}
            >
              {/* Info */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <span
                    className={`inline-block px-2 py-0.5 text-xs rounded-full font-medium ${
                      item.isActive
                        ? 'bg-green-900/50 text-green-400'
                        : 'bg-gray-800 text-gray-500'
                    }`}
                  >
                    {item.isActive ? 'Active' : 'Inactive'}
                  </span>
                </div>
                <p className="text-sm font-medium text-gray-100 truncate">{item.title}</p>
                {item.url ? (
                  <a
                    href={item.url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-xs text-[#4C4CFF] hover:underline truncate block mt-0.5"
                  >
                    {item.url}
                  </a>
                ) : (
                  <p className="text-xs text-gray-600 mt-0.5">No URL</p>
                )}
              </div>

              {/* Actions */}
              <div className="flex items-center gap-2 flex-shrink-0">
                {/* Toggle */}
                <button
                  onClick={() => handleToggle(item)}
                  title={item.isActive ? 'Deactivate' : 'Activate'}
                  className="p-1.5 rounded hover:bg-[#0f1518] transition-colors"
                >
                  {item.isActive ? (
                    <ToggleRight className="w-6 h-6 text-[#243BFF]" />
                  ) : (
                    <ToggleLeft className="w-6 h-6 text-gray-500" />
                  )}
                </button>

                {/* Delete */}
                <button
                  onClick={() => handleDelete(item.id)}
                  title="Delete"
                  className="p-1.5 rounded hover:bg-[#0f1518] text-gray-500 hover:text-red-400 transition-colors"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Firestore schema hint (dev only) */}
      <details className="text-xs text-gray-600 border border-dashed border-[#1a2030] rounded p-3">
        <summary className="cursor-pointer hover:text-gray-400">Firestore schema — announcements</summary>
        <pre className="mt-2 text-[#4C4CFF]/70 leading-relaxed">
{`Collection: announcements
Document fields:
  title     : string   (required)
  url       : string   (optional — opens in browser on tap)
  isActive  : boolean  (only one true at a time)
  createdAt : timestamp`}
        </pre>
      </details>
    </div>
  );
}
