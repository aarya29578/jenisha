/**
 * CLEANUP SCRIPT: Remove Super Admin from users collection
 * 
 * This script removes any admin accounts that were accidentally
 * created in the 'users' collection (which is for agents only).
 * 
 * Run this once to clean up existing data.
 */

import { initializeApp } from 'firebase/app';
import { getFirestore, collection, query, where, getDocs, deleteDoc, doc } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyC72UmM3pMwRBh0pKjKy_jN9wmpE_MP_GM',
  authDomain: 'jenisha-46c62.firebaseapp.com',
  projectId: 'jenisha-46c62',
  storageBucket: 'jenisha-46c62.appspot.com',
  messagingSenderId: '245020879102',
  appId: '1:245020879102:web:05969fe2820677483c9daf',
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function cleanupSuperAdminFromUsers() {
  try {
    console.log('🔍 Searching for Super Admin in users collection...');
    
    // Query for Super Admin by email
    const usersRef = collection(db, 'users');
    const q = query(usersRef, where('email', '==', 'jenisha@gmail.com'));
    const querySnapshot = await getDocs(q);
    
    if (querySnapshot.empty) {
      console.log('✅ No Super Admin found in users collection. Already clean!');
      return;
    }
    
    console.log(`⚠️  Found ${querySnapshot.size} document(s) with Super Admin email in users collection`);
    
    // Delete all matching documents
    for (const docSnapshot of querySnapshot.docs) {
      console.log(`🗑️  Deleting document: ${docSnapshot.id}`);
      console.log(`   Data:`, docSnapshot.data());
      
      await deleteDoc(doc(db, 'users', docSnapshot.id));
      console.log(`✅ Deleted Super Admin from users/${docSnapshot.id}`);
    }
    
    console.log('\n✅ Cleanup complete! Super Admin removed from users collection.');
    console.log('ℹ️  Super Admin should only exist in admin_users collection.');
    
  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }
}

// Run cleanup
cleanupSuperAdminFromUsers()
  .then(() => {
    console.log('\n🎉 Script completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Script failed:', error);
    process.exit(1);
  });
