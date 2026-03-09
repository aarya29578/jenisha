/**
 * DEBUG SCRIPT - Check Firestore Services Collection
 * 
 * This script verifies:
 * 1. Services collection exists
 * 2. Services have required fields
 * 3. Services have isActive == true
 * 4. Services have valid categoryId
 * 5. Categories exist for those categoryIds
 */

import {
  getFirestore,
  collection,
  query,
  where,
  getDocs,
  doc,
  getDoc,
} from 'firebase/firestore';
import { initializeApp } from 'firebase/app';

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

async function debugServices() {
  console.log('\n🔍 DEBUGGING FIRESTORE SERVICES\n');

  try {
    // 1. Check ALL services (regardless of isActive)
    console.log('1️⃣  Checking ALL services in collection...');
    const allServicesRef = collection(firestore, 'services');
    const allServicesDocs = await getDocs(allServicesRef);
    
    console.log(`   Found ${allServicesDocs.docs.length} total services`);
    
    if (allServicesDocs.docs.length === 0) {
      console.log('   ⚠️  NO SERVICES EXIST AT ALL!');
    } else {
      console.log('\n   Service Details:');
      for (const doc of allServicesDocs.docs) {
        const data = doc.data();
        console.log(`\n   📌 Service: ${doc.id}`);
        console.log(`      name: "${data.name}"`);
        console.log(`      categoryId: "${data.categoryId}"`);
        console.log(`      isActive: ${data.isActive}`);
        console.log(`      createdAt: ${data.createdAt}`);
        console.log(`      price: ${data.price || 'N/A'}`);
      }
    }

    // 2. Check ACTIVE services only
    console.log('\n\n2️⃣  Checking ACTIVE services (isActive == true)...');
    const activeServicesQuery = query(
      collection(firestore, 'services'),
      where('isActive', '==', true)
    );
    const activeServicesDocs = await getDocs(activeServicesQuery);
    
    console.log(`   Found ${activeServicesDocs.docs.length} active services`);
    
    if (activeServicesDocs.docs.length === 0) {
      console.log('   ⚠️  NO ACTIVE SERVICES! All services have isActive == false');
    }

    // 3. Check categories
    console.log('\n\n3️⃣  Checking categories...');
    const categoriesRef = collection(firestore, 'categories');
    const categoriesDocs = await getDocs(categoriesRef);
    
    console.log(`   Found ${categoriesDocs.docs.length} categories`);
    
    const categoryMap = new Map<string, string>();
    for (const doc of categoriesDocs.docs) {
      const data = doc.data();
      categoryMap.set(doc.id, data.name);
      console.log(`\n   📂 Category: ${doc.id}`);
      console.log(`      name: "${data.name}"`);
      console.log(`      isActive: ${data.isActive}`);
    }

    // 4. Validate service categoryIds
    console.log('\n\n4️⃣  Validating categoryId references...');
    for (const doc of allServicesDocs.docs) {
      const data = doc.data();
      const categoryId = data.categoryId;
      const categoryExists = categoryMap.has(categoryId);
      
      console.log(`\n   Service "${data.name}"`);
      console.log(`      categoryId: "${categoryId}"`);
      console.log(`      Category exists: ${categoryExists ? '✅ YES' : '❌ NO'}`);
      
      if (categoryExists) {
        console.log(`      Category name: "${categoryMap.get(categoryId)}"`);
      }
    }

    // 5. Check required fields
    console.log('\n\n5️⃣  Checking for missing required fields...');
    let missingFields = 0;
    for (const doc of allServicesDocs.docs) {
      const data = doc.data();
      const issues = [];
      
      if (!data.name) issues.push('missing "name"');
      if (!data.categoryId) issues.push('missing "categoryId"');
      if (data.isActive === undefined) issues.push('missing "isActive"');
      
      if (issues.length > 0) {
        console.log(`   ❌ Service "${doc.id}": ${issues.join(', ')}`);
        missingFields++;
      }
    }
    
    if (missingFields === 0) {
      console.log('   ✅ All services have required fields');
    }

    // 6. Summary
    console.log('\n\n📋 SUMMARY:');
    console.log(`   Total services: ${allServicesDocs.docs.length}`);
    console.log(`   Active services (isActive==true): ${activeServicesDocs.docs.length}`);
    console.log(`   Total categories: ${categoriesDocs.docs.length}`);
    console.log(`   Services with valid categoryId: ${allServicesDocs.docs.filter(d => categoryMap.has(d.data().categoryId)).length}`);

    if (activeServicesDocs.docs.length === 0) {
      console.log('\n   ❌ ISSUE: No active services found!');
      console.log('      → Check Firestore console');
      console.log('      → Verify services have isActive: true');
      console.log('      → Create services in Service Management page');
    } else {
      console.log('\n   ✅ Services should appear in dropdown');
    }

  } catch (error) {
    console.error('\n❌ ERROR:', error);
    console.error('Details:', (error as any).message);
  }
}

// Run the debug script
debugServices();
