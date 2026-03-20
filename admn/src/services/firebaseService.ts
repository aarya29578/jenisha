import { 
  initializeApp,
  getApps,
  FirebaseApp 
} from 'firebase/app';
import {
  getAuth,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  Auth,
  User
} from 'firebase/auth';
import {
  getFirestore,
  collection,
  query,
  where,
  onSnapshot,
  updateDoc,
  deleteDoc,
  doc,
  serverTimestamp,
  Firestore,
  Timestamp,
  getDocs
} from 'firebase/firestore';
import { authService } from './authService';

// Firebase Configuration
const firebaseConfig = {
  apiKey: 'AIzaSyC72UmM3pMwRBh0pKjKy_jN9wmpE_MP_GM',
  authDomain: 'jenisha-46c62.firebaseapp.com',
  projectId: 'jenisha-46c62',
  storageBucket: 'jenisha-46c62.appspot.com',
  messagingSenderId: '245020879102',
  appId: '1:245020879102:web:05969fe2820677483c9daf',
};

// Reuse the already-initialised default app (authService initialises it first).
// Calling initializeApp() a second time would create an orphan app with no
// signed-in user, causing every Firestore write to fail with
// "Missing or insufficient permissions".
const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
const auth = getAuth(app);
const firestore = getFirestore(app);

// User Interface
export interface UserData {
  uid: string;
  fullName: string;
  shopName: string;
  phone: string;
  email: string;
  address: {
    line1: string;
    city: string;
    state: string;
    pincode: string;
  };
  documents: {
    adhaar?: { imageUrl?: string } | string | null;
    pan?: { imageUrl?: string } | string | null;
  };
  profilePhotoUrl?: string | null;
  // Single source of truth: `status` field from Flutter/Firestore
  status: 'pending' | 'approved' | 'rejected' | 'blocked';
  createdAt: Timestamp | null;
  reviewedAt: Timestamp | null;
  reviewedBy: string | null;
  rejectionReason: string | null;
  walletBalance?: number;
}

// Admin Auth Service (delegates to authService for consistency)
// Uses 'admin_users' collection (separate from agent 'users' collection)
export const adminAuth = {
  login: async (email: string, password: string) => {
    try {
      await authService.login(email, password);
      return authService.getAuth().currentUser;
    } catch (error) {
      console.error('❌ Admin login failed:', error);
      throw error;
    }
  },

  logout: async () => {
    try {
      await authService.logout();
      console.log('✅ Admin logged out');
    } catch (error) {
      console.error('❌ Logout failed:', error);
      throw error;
    }
  },

  getCurrentUser: () => {
    const adminUser = authService.getCurrentUser();
    return adminUser ? { email: adminUser.email, uid: adminUser.uid } : null;
  },

  onAuthStateChanged: (callback: (user: User | null) => void) => {
    return onAuthStateChanged(auth, callback);
  },
};

// Pending Users Service
// NOTE: This operates on the 'users' collection which contains AGENT data only
// Admin users are stored separately in 'admin_users' collection
export const pendingUsersService = {
  // Get real-time stream of pending users (agents)
  subscribeToPendingUsers: (
    callback: (users: UserData[]) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      // Query Firestore `users` collection for pending AGENTS (not admins)
      const q = query(
        collection(firestore, 'users'),
        where('status', '==', 'pending')
      );

      return onSnapshot(
        q,
        (snapshot) => {
          const users: UserData[] = [];
          snapshot.forEach((doc) => {
            const d = doc.data() as any;
            users.push({
              uid: doc.id,
              fullName: d.name || d.fullName || '',
              shopName: d.shopName || '',
              phone: d.phone || '',
              email: d.email || '',
              address: d.address || { line1: '', city: '', state: '', pincode: '' },
              documents: d.documents || { aadhar: null, pan: null },
              profilePhotoUrl: d.profilePhotoUrl || null,
              status: d.status || 'pending',
              createdAt: d.createdAt || null,
              reviewedAt: d.reviewedAt || null,
              reviewedBy: d.reviewedBy || null,
              rejectionReason: d.rejectionReason || null,
              walletBalance: typeof d.walletBalance === 'number' ? d.walletBalance : 0,
            } as UserData);
          });
          callback(users.sort((a, b) => {
            const aTime = a.createdAt?.toMillis() || 0;
            const bTime = b.createdAt?.toMillis() || 0;
            return bTime - aTime; // Newest first
          }));
        },
        (error) => {
          console.error('❌ Error listening to pending users:', error);
          if (onError) onError(error as Error);
        }
      );
    } catch (error) {
      console.error('❌ Error subscribing to pending users:', error);
      if (onError) onError(error as Error);
      return () => {}; // Return unsubscribe function
    }
  },

  // Get real-time stream of ALL users
  subscribeToAllUsers: (
    callback: (users: UserData[]) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      // Subscribe to all users (map firestore shape to UI-friendly UserData)
      const q = query(collection(firestore, 'users'));

      return onSnapshot(
        q,
        (snapshot) => {
          const users: UserData[] = [];
          snapshot.forEach((doc) => {
            const d = doc.data() as any;
            users.push({
              uid: doc.id,
              fullName: d.name || d.fullName || '',
              shopName: d.shopName || '',
              phone: d.phone || '',
              email: d.email || '',
              address: d.address || { line1: '', city: '', state: '', pincode: '' },
              documents: d.documents || { aadhar: null, pan: null },
              profilePhotoUrl: d.profilePhotoUrl || null,
              status: d.status || 'pending',
              createdAt: d.createdAt || null,
              reviewedAt: d.reviewedAt || null,
              reviewedBy: d.reviewedBy || null,
              rejectionReason: d.rejectionReason || null,
              walletBalance: typeof d.walletBalance === 'number' ? d.walletBalance : 0,
            } as UserData);
          });
          callback(users.sort((a, b) => {
            const aTime = a.createdAt?.toMillis() || 0;
            const bTime = b.createdAt?.toMillis() || 0;
            return bTime - aTime; // Newest first
          }));
        },
        (error) => {
          console.error('❌ Error listening to all users:', error);
          if (onError) onError(error as Error);
        }
      );
    } catch (error) {
      console.error('❌ Error subscribing to all users:', error);
      if (onError) onError(error as Error);
      return () => {}; // Return unsubscribe function
    }
  },
};

// User Approval Service
export const userApprovalService = {
  // Approve a user
  approveUser: async (uid: string, adminEmail: string) => {
    try {
      const userRef = doc(firestore, 'users', uid);
      await updateDoc(userRef, {
        status: 'approved',
        reviewedAt: serverTimestamp(),
        reviewedBy: adminEmail,
      });
      console.log(`✅ User ${uid} approved by ${adminEmail}`);
    } catch (error) {
      console.error('❌ Error approving user:', error);
      throw error;
    }
  },

  // Delete a user document
  deleteAgent: async (uid: string) => {
    try {
      const userRef = doc(firestore, 'users', uid);
      await deleteDoc(userRef);
      console.log(`✅ User ${uid} deleted`);
    } catch (error) {
      console.error('❌ Error deleting user:', error);
      throw error;
    }
  },

  // Reject a user with reason
  rejectUser: async (uid: string, adminEmail: string, reason: string) => {
    try {
      const userRef = doc(firestore, 'users', uid);
      await updateDoc(userRef, {
        status: 'rejected',
        rejectionReason: reason,
        reviewedAt: serverTimestamp(),
        reviewedBy: adminEmail,
      });
      console.log(`✅ User ${uid} rejected by ${adminEmail}`);
    } catch (error) {
      console.error('❌ Error rejecting user:', error);
      throw error;
    }
  },
};

// User Documents Service - fetch documents from subcollection
export interface UserDocumentData {
  id: string;
  name: string;
  base64?: string;
  imageUrl?: string;
  status: string;
  uploadedAt?: Timestamp;
  reviewedAt?: Timestamp;
  reviewedBy?: string;
  rejectionReason?: string;
}

export const userDocumentsService = {
  // Get all documents for a user from the documents subcollection
  getUserDocuments: async (userId: string): Promise<UserDocumentData[]> => {
    try {
      const docsRef = collection(firestore, 'users', userId, 'documents');
      const snapshot = await getDocs(docsRef);
      const documents: UserDocumentData[] = [];
      
      snapshot.forEach((docSnap) => {
        const data = docSnap.data();
        documents.push({
          id: docSnap.id,
          name: data.name || '',
          base64: data.base64 || null,
          imageUrl: data.imageUrl || '',
          status: data.status || 'pending',
          uploadedAt: data.uploadedAt || null,
          reviewedAt: data.reviewedAt || null,
          reviewedBy: data.reviewedBy || null,
          rejectionReason: data.rejectionReason || null,
        } as UserDocumentData);
      });
      
      console.log(`✅ Fetched ${documents.length} documents for user ${userId}`);
      return documents;
    } catch (error) {
      console.error('❌ Error fetching user documents:', error);
      return [];
    }
  },
};

// Dashboard Service - computes counts and total wallet balance in real-time
export interface DashboardStats {
  totalAgents: number;
  pendingApprovals: number;
  activeAgents: number;
  blockedAgents: number;
  documentsPending: number;
  totalWalletBalance: number;
}

export const dashboardService = {
  subscribeToDashboard: (
    callback: (stats: DashboardStats) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      // Subscribe to users collection
      const usersQuery = query(collection(firestore, 'users'));
      const unsubscribeUsers = onSnapshot(
        usersQuery,
        async (snapshot) => {
          let totalWallet = 0;
          let pendingApprovals = 0;
          let activeAgents = 0;
          let blockedAgents = 0;

          snapshot.forEach((doc) => {
            const d = doc.data() as any;
            const status = d.status || 'pending';
            
            // Sum wallet balances
            const wallet = typeof d.wallet === 'number' ? d.wallet : 0;
            totalWallet += wallet;
            
            // Count by status
            if (status === 'pending') pendingApprovals += 1;
            if (status === 'approved') activeAgents += 1;
            if (status === 'blocked') blockedAgents += 1;
          });

          // Get pending service applications count
          let documentsPending = 0;
          try {
            const applicationsQuery = query(
              collection(firestore, 'serviceApplications'),
              where('status', '==', 'pending')
            );
            const applicationsSnapshot = await getDocs(applicationsQuery);
            documentsPending = applicationsSnapshot.size;
          } catch (err) {
            console.error('Error counting pending applications:', err);
          }

          const stats: DashboardStats = {
            totalAgents: snapshot.size,
            pendingApprovals,
            activeAgents,
            blockedAgents,
            documentsPending,
            totalWalletBalance: totalWallet,
          };
          callback(stats);
        },
        (error) => {
          console.error('❌ Error listening to dashboard stats:', error);
          if (onError) onError(error as Error);
        }
      );

      return unsubscribeUsers;
    } catch (error) {
      console.error('❌ Error subscribing to dashboard stats:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },
};

export { auth, firestore };
