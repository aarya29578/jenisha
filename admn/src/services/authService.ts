import {
  getAuth,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  setPersistence,
  browserLocalPersistence,
  User,
} from 'firebase/auth';
import {
  getFirestore,
  doc,
  getDoc,
  setDoc,
  serverTimestamp,
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

// Initialize Firebase (reuse existing app if available)
const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

// Persist login across page refreshes (survives F5 / browser reopen)
setPersistence(auth, browserLocalPersistence).catch(console.error);

// Super Admin Credentials
const SUPER_ADMIN_EMAIL = 'jenisha@gmail.com';
const SUPER_ADMIN_PASSWORD = 'jenisha';

export interface AdminUser {
  uid: string;
  name: string;
  email: string;
  role: 'super_admin' | 'admin' | 'moderator';
  createdAt: any;
  allowedCategories?: string[];
}

class AuthService {
  private currentUser: AdminUser | null = null;

  /**
   * Initialize Super Admin Account
   * Creates the account if it doesn't exist, ensures role is set to super_admin
   * Stores admin data in 'admin_users' collection (separate from agent 'users')
   */
  async initializeSuperAdmin(): Promise<void> {
    try {
      console.log('🔐 [AUTH] Checking Super Admin account...');

      // Try to sign in first to check if account exists
      try {
        const userCredential = await signInWithEmailAndPassword(
          auth,
          SUPER_ADMIN_EMAIL,
          SUPER_ADMIN_PASSWORD
        );

        // Account exists, ensure Firestore document has correct role in admin_users
        const adminUserDoc = await getDoc(doc(db, 'admin_users', userCredential.user.uid));
        
        if (!adminUserDoc.exists() || adminUserDoc.data()?.role !== 'super_admin') {
          // Update or create document with super_admin role in admin_users collection
          await setDoc(
            doc(db, 'admin_users', userCredential.user.uid),
            {
              name: 'Super Admin',
              email: SUPER_ADMIN_EMAIL,
              role: 'super_admin',
              createdAt: serverTimestamp(),
              updatedAt: serverTimestamp(),
            },
            { merge: true }
          );
          console.log('✅ [AUTH] Super Admin role updated in admin_users collection');
        } else {
          console.log('✅ [AUTH] Super Admin account already configured');
        }

        // Sign out after verification
        await signOut(auth);
      } catch (signInError: any) {
        // Account doesn't exist, create it
        if (signInError.code === 'auth/user-not-found' || signInError.code === 'auth/wrong-password' || signInError.code === 'auth/invalid-credential') {
          console.log('📝 [AUTH] Creating Super Admin account...');
          
          const userCredential = await createUserWithEmailAndPassword(
            auth,
            SUPER_ADMIN_EMAIL,
            SUPER_ADMIN_PASSWORD
          );

          // Create Firestore document in admin_users collection (NOT in users)
          await setDoc(doc(db, 'admin_users', userCredential.user.uid), {
            name: 'Super Admin',
            email: SUPER_ADMIN_EMAIL,
            role: 'super_admin',
            createdAt: serverTimestamp(),
          });

          console.log('✅ [AUTH] Super Admin account created successfully');
          console.log(`   Email: ${SUPER_ADMIN_EMAIL}`);
          console.log(`   Role: super_admin`);
          console.log(`   Collection: admin_users (separate from agent users)`);

          // Sign out after creation
          await signOut(auth);
        } else {
          throw signInError;
        }
      }
    } catch (error: any) {
      console.error('❌ [AUTH] Error initializing Super Admin:', error);
      // Don't throw - app should still load even if super admin init fails
    }
  }

  /**
   * Login with email and password
   * Fetches admin role from 'admin_users' collection (not 'users')
   */
  async login(email: string, password: string): Promise<AdminUser> {
    try {
      console.log('🔑 [AUTH] Attempting login...');
      
      // Sign in with Firebase Auth
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const user = userCredential.user;

      // Fetch user document from admin_users collection (NOT users)
      const adminUserDocRef = doc(db, 'admin_users', user.uid);
      const adminUserDoc = await getDoc(adminUserDocRef);

      if (!adminUserDoc.exists()) {
        await signOut(auth);
        throw new Error('Unauthorized access. This portal is for administrators only.');
      }

      const userData = adminUserDoc.data();
      const role = userData.role || 'admin';

      // Validate user has admin role
      if (!['super_admin', 'admin', 'moderator'].includes(role)) {
        await signOut(auth);
        throw new Error('Access denied. Invalid admin role.');
      }

      this.currentUser = {
        uid: user.uid,
        name: userData.name || 'Admin',
        email: userData.email || email,
        role: role as 'super_admin' | 'admin' | 'moderator',
        createdAt: userData.createdAt,
        allowedCategories: Array.isArray(userData.allowedCategories) ? userData.allowedCategories : [],
      };

      console.log('✅ [AUTH] Login successful');
      console.log(`   User: ${this.currentUser.name}`);
      console.log(`   Role: ${this.currentUser.role}`);
      console.log(`   Collection: admin_users`);

      return this.currentUser;
    } catch (error: any) {
      console.error('❌ [AUTH] Login failed:', error);
      
      // Provide user-friendly error messages
      if (error.code === 'auth/invalid-credential' || error.code === 'auth/user-not-found' || error.code === 'auth/wrong-password') {
        throw new Error('Invalid email or password');
      } else if (error.code === 'auth/too-many-requests') {
        throw new Error('Too many failed attempts. Please try again later.');
      } else if (error.code === 'auth/network-request-failed') {
        throw new Error('Network error. Please check your connection.');
      } else if (error.message) {
        throw error;
      } else {
        throw new Error('Login failed. Please try again.');
      }
    }
  }

  /**
   * Logout current user
   */
  async logout(): Promise<void> {
    try {
      await signOut(auth);
      this.currentUser = null;
      console.log('✅ [AUTH] Logout successful');
    } catch (error) {
      console.error('❌ [AUTH] Logout failed:', error);
      throw error;
    }
  }

  /**
   * Get current authenticated user
   */
  getCurrentUser(): AdminUser | null {
    return this.currentUser;
  }

  /**
   * Check if user has specific role
   */
  hasRole(requiredRole: 'super_admin' | 'admin' | 'moderator'): boolean {
    if (!this.currentUser) return false;
    
    const roleHierarchy = {
      super_admin: 3,
      admin: 2,
      moderator: 1,
    };

    return roleHierarchy[this.currentUser.role] >= roleHierarchy[requiredRole];
  }

  /**
   * Check if user is super admin
   */
  isSuperAdmin(): boolean {
    return this.currentUser?.role === 'super_admin';
  }

  /**
   * Listen to auth state changes
   * Fetches role from 'admin_users' collection
   */
  onAuthStateChange(callback: (user: AdminUser | null) => void): () => void {
    return onAuthStateChanged(auth, async (firebaseUser: User | null) => {
      if (firebaseUser) {
        try {
          // Fetch user data from admin_users collection (NOT users)
          const adminUserDocRef = doc(db, 'admin_users', firebaseUser.uid);
          const adminUserDoc = await getDoc(adminUserDocRef);

          if (adminUserDoc.exists()) {
            const userData = adminUserDoc.data();
            const role = userData.role || 'admin';

            if (['super_admin', 'admin', 'moderator'].includes(role)) {
              this.currentUser = {
                uid: firebaseUser.uid,
                name: userData.name || 'Admin',
                email: userData.email || firebaseUser.email || '',
                role: role as 'super_admin' | 'admin' | 'moderator',
                createdAt: userData.createdAt,
                allowedCategories: Array.isArray(userData.allowedCategories) ? userData.allowedCategories : [],
              };
              callback(this.currentUser);
              return;
            } else {
              console.warn('⚠️ [AUTH] User has invalid role:', role);
            }
          } else {
            console.warn('⚠️ [AUTH] User not found in admin_users collection');
          }
        } catch (error) {
          console.error('❌ [AUTH] Error fetching user data:', error);
        }
      }

      this.currentUser = null;
      callback(null);
    });
  }

  /**
   * Get Firebase Auth instance (for advanced use)
   */
  getAuth() {
    return auth;
  }

  /**
   * Get Firestore instance (for advanced use)
   */
  getFirestore() {
    return db;
  }
}

// Export singleton instance
export const authService = new AuthService();

// Initialize super admin on module load
authService.initializeSuperAdmin().catch(console.error);

export default authService;
