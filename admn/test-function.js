/**
 * Test script to verify Cloud Function is callable
 * Run this in the browser console after logging in as Super Admin
 */

// Test 1: Check if functions SDK is loaded
console.log('🧪 TEST 1: Firebase Functions SDK');
try {
  const { getFunctions } = await import('firebase/functions');
  console.log('✅ Firebase Functions SDK loaded');
} catch (e) {
  console.error('❌ Failed to load Functions SDK:', e);
}

// Test 2: Get functions instance
console.log('\n🧪 TEST 2: Get Functions Instance');
try {
  const { getFunctions } = await import('firebase/functions');
  const { getApps } = await import('firebase/app');
  const app = getApps()[0];
  const functions = getFunctions(app, 'us-central1');
  console.log('✅ Functions instance created:', functions);
} catch (e) {
  console.error('❌ Failed to create functions instance:', e);
}

// Test 3: Check authentication
console.log('\n🧪 TEST 3: Check Authentication');
try {
  const { getAuth } = await import('firebase/auth');
  const { getApps } = await import('firebase/app');
  const app = getApps()[0];
  const auth = getAuth(app);
  console.log('✅ Current user:', auth.currentUser?.email);
  console.log('✅ User UID:', auth.currentUser?.uid);
} catch (e) {
  console.error('❌ Authentication check failed:', e);
}

// Test 4: Try calling the function
console.log('\n🧪 TEST 4: Call createAdminUser Function');
console.log('⚠️  This will attempt to create a test admin!');
console.log('📝 Test data: { name: "Test", email: "test@test.com", password: "test123", role: "admin" }');

try {
  const { getFunctions, httpsCallable } = await import('firebase/functions');
  const { getApps } = await import('firebase/app');
  const app = getApps()[0];
  const functions = getFunctions(app, 'us-central1');
  const createAdminUser = httpsCallable(functions, 'createAdminUser');
  
  console.log('⏳ Calling function...');
  const result = await createAdminUser({
    name: 'Test Admin',
    email: 'test_' + Date.now() + '@test.com',
    password: 'test123',
    role: 'admin'
  });
  
  console.log('✅ SUCCESS! Function response:', result.data);
  console.log('✅ Admin created successfully!');
  console.log('🎉 Cloud Function is working correctly!');
  
} catch (e) {
  console.error('❌ Function call failed:', e);
  console.error('❌ Error code:', e.code);
  console.error('❌ Error message:', e.message);
  
  if (e.code === 'functions/not-found') {
    console.error('\n🔧 FIX: Function not deployed!');
    console.error('   Run: firebase deploy --only functions');
  } else if (e.code === 'functions/unauthenticated') {
    console.error('\n🔧 FIX: Not logged in!');
    console.error('   Please login as Super Admin first');
  } else if (e.code === 'functions/permission-denied') {
    console.error('\n🔧 FIX: Not Super Admin!');
    console.error('   You need super_admin role');
  }
}

console.log('\n📊 Test complete!');
