/**
 * Firebase Cloud Functions for Admin Creation System (v2)
 * 
 * This function allows Super Admins to create new admin users
 * without affecting their own authentication session.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Set global options - region and CORS
setGlobalOptions({ region: 'us-central1' });

/**
 * Create Admin User Cloud Function (v2)
 * 
 * This is a Firebase v2 callable HTTPS function that creates a new admin user
 * in Firebase Authentication and Firestore.
 * 
 * Security:
 * - Only callable by authenticated users
 * - Caller must have super_admin role
 * - Uses Admin SDK to avoid session issues
 * 
 * @param {Object} request.data - Function parameters
 * @param {string} request.data.name - Admin name
 * @param {string} request.data.email - Admin email
 * @param {string} request.data.password - Admin password
 * @param {string} request.data.role - Admin role (admin | super_admin | moderator)
 * @param {Object} request.auth - Auth context
 * @returns {Promise<Object>} Result with success status and new admin UID
 */
exports.createAdminUser = onCall(
  {
    cors: [
      'http://localhost:5173',
      'http://localhost:3000',
      'https://jenisha-46c62.web.app',
      'https://jenisha-46c62.firebaseapp.com',
    ],
    enforceAppCheck: false,
  },
  async (request) => {
  const data = request.data;
  const context = { auth: request.auth };

  console.log('🔵 createAdminUser called with:', { 
    callerUid: context.auth?.uid, 
    targetEmail: data.email,
    targetRole: data.role 
  });

  // ========================================
  // SECURITY CHECK #1: User must be authenticated
  // ========================================
  if (!context.auth) {
    console.error('❌ Unauthenticated call rejected');
    throw new HttpsError(
      'unauthenticated',
      'You must be logged in to create admin users.'
    );
  }

  const callerUid = context.auth.uid;
  const callerEmail = context.auth.token.email;

  try {
    // ========================================
    // SECURITY CHECK #2: Verify caller is Super Admin
    // ========================================
    console.log('🔍 Checking caller permissions:', callerUid);
    
    const callerDoc = await admin.firestore()
      .collection('admin_users')
      .doc(callerUid)
      .get();

    if (!callerDoc.exists) {
      console.error('❌ Caller not found in admin_users:', callerUid);
      throw new HttpsError(
        'permission-denied',
        'Only admin users can create new admins.'
      );
    }

    const callerRole = callerDoc.data().role;
    console.log('👤 Caller role:', callerRole);

    if (callerRole !== 'super_admin') {
      console.error('❌ Insufficient role. Required: super_admin, Got:', callerRole);
      throw new HttpsError(
        'permission-denied',
        'Only Super Admins can create new admin users.'
      );
    }

    console.log('✅ Super Admin verification passed');

    // ========================================
    // VALIDATE INPUT DATA
    // ========================================
    const { name, email, password, role } = data;

    if (!name || !email || !password || !role) {
      throw new HttpsError(
        'invalid-argument',
        'Missing required fields: name, email, password, role'
      );
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new HttpsError(
        'invalid-argument',
        'Invalid email format'
      );
    }

    // Validate password length
    if (password.length < 6) {
      throw new HttpsError(
        'invalid-argument',
        'Password must be at least 6 characters'
      );
    }

    // Validate role
    const validRoles = ['admin', 'super_admin', 'moderator'];
    if (!validRoles.includes(role)) {
      throw new HttpsError(
        'invalid-argument',
        'Invalid role. Must be: admin, super_admin, or moderator'
      );
    }

    console.log('✅ Input validation passed');

    // ========================================
    // STEP 1: Create Firebase Authentication User
    // ========================================
    console.log('📝 Creating Firebase Auth user:', email);
    
    let newUserRecord;
    try {
      newUserRecord = await admin.auth().createUser({
        email: email,
        password: password,
        emailVerified: false,
        disabled: false
      });
      console.log('✅ Firebase Auth user created:', newUserRecord.uid);
    } catch (authError) {
      console.error('❌ Firebase Auth error:', authError);
      
      // Handle specific Firebase Auth errors
      if (authError.code === 'auth/email-already-exists') {
        throw new HttpsError(
          'already-exists',
          'This email is already registered in Firebase Authentication.'
        );
      } else if (authError.code === 'auth/invalid-email') {
        throw new HttpsError(
          'invalid-argument',
          'Invalid email address format.'
        );
      } else if (authError.code === 'auth/weak-password') {
        throw new HttpsError(
          'invalid-argument',
          'Password is too weak. Must be at least 6 characters.'
        );
      } else {
        throw new HttpsError(
          'internal',
          `Failed to create authentication user: ${authError.message}`
        );
      }
    }

    // ========================================
    // STEP 2: Create Firestore Document
    // ========================================
    console.log('📝 Creating Firestore document in admin_users');
    
    const newAdminData = {
      name: name,
      email: email,
      role: role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    try {
      await admin.firestore()
        .collection('admin_users')
        .doc(newUserRecord.uid)
        .set(newAdminData);
      
      console.log('✅ Firestore document created');
    } catch (firestoreError) {
      console.error('❌ Firestore error:', firestoreError);
      
      // Rollback: Delete the auth user we just created
      console.log('🔄 Rolling back: Deleting auth user');
      try {
        await admin.auth().deleteUser(newUserRecord.uid);
        console.log('✅ Rollback successful');
      } catch (rollbackError) {
        console.error('❌ Rollback failed:', rollbackError);
      }
      
      throw new HttpsError(
        'internal',
        `Failed to create Firestore document: ${firestoreError.message}`
      );
    }

    // ========================================
    // SUCCESS
    // ========================================
    console.log('🎉 Admin user created successfully:', {
      uid: newUserRecord.uid,
      email: email,
      role: role,
      createdBy: callerEmail
    });

    return {
      success: true,
      uid: newUserRecord.uid,
      email: email,
      role: role,
      message: `Admin "${name}" created successfully!`
    };

  } catch (error) {
    console.error('❌ Unexpected error:', error);
    
    // If it's already an HttpsError, rethrow it
    if (error instanceof HttpsError) {
      throw error;
    }
    
    // Otherwise, wrap it in an internal error
    throw new HttpsError(
      'internal',
      `An unexpected error occurred: ${error.message}`
    );
  }
});
