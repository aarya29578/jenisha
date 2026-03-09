import { collection, getDocs, doc, getDoc } from 'firebase/firestore';
import { firestore } from '../services/categoryService'; // Import from actual location

/**
 * DIAGNOSTIC SCRIPT: Check actual Firestore data structure
 * Run this in browser console to verify:
 * 1. Services collection exists
 * 2. Services have correct fields (categoryId, isActive)
 * 3. categoryId references match actual categories
 */

export async function diagnoseFIRESTORE_DATA() {
  console.clear();
  console.log('🔍 FIRESTORE DATA DIAGNOSTIC STARTING...\n');

  try {
    // 1. Check categories
    console.log('1️⃣ CHECKING CATEGORIES...');
    const categoriesSnapshot = await getDocs(collection(firestore, 'categories'));
    console.log(`   Found ${categoriesSnapshot.size} categories:`);
    
    const categoryIds = new Set<string>();
    categoriesSnapshot.forEach(doc => {
      const data = doc.data();
      categoryIds.add(doc.id);
      console.log(`   - ${doc.id}: "${data.name}" (isActive: ${data.isActive})`);
    });
    
    if (categoryIds.size === 0) {
      console.warn('   ⚠️  NO CATEGORIES FOUND - Create categories first!');
    }

    // 2. Check services
    console.log('\n2️⃣ CHECKING SERVICES...');
    const servicesSnapshot = await getDocs(collection(firestore, 'services'));
    console.log(`   Found ${servicesSnapshot.size} services:`);
    
    let isActiveCount = 0;
    let validCategoryIdCount = 0;
    let missingFieldCount = 0;

    servicesSnapshot.forEach(doc => {
      const data = doc.data();
      const hasName = !!data.name;
      const hasCategoryId = !!data.categoryId;
      const isActive = data.isActive;
      const categoryIdValid = categoryIds.has(data.categoryId);

      // Count issues
      if (isActive) isActiveCount++;
      if (hasCategoryId && categoryIdValid) validCategoryIdCount++;
      if (!hasName || !hasCategoryId || !('isActive' in data)) missingFieldCount++;

      console.log(`\n   📌 ${doc.id}:`);
      console.log(`      name: "${data.name}" ${hasName ? '✅' : '❌'}`);
      console.log(`      categoryId: "${data.categoryId}" ${hasCategoryId ? '✅' : '❌'}`);
      console.log(`      categoryId matches category? ${categoryIdValid ? '✅' : '❌'}`);
      console.log(`      isActive: ${isActive} ${isActive ? '✅' : '❌'}`);
      console.log(`      price: ${data.price || 'not set'}`);
      console.log(`      createdAt: ${data.createdAt ? '✅' : '❌'}`);
    });

    // 3. Summary
    console.log('\n3️⃣ SUMMARY:');
    console.log(`   Total services: ${servicesSnapshot.size}`);
    console.log(`   Active services (isActive==true): ${isActiveCount}`);
    console.log(`   Services with valid categoryId: ${validCategoryIdCount}`);
    console.log(`   Services with missing fields: ${missingFieldCount}`);

    // 4. Problems & Solutions
    console.log('\n4️⃣ PROBLEMS & SOLUTIONS:');
    
    if (servicesSnapshot.size === 0) {
      console.error('   ❌ PROBLEM: No services exist in Firestore');
      console.log('   ✅ SOLUTION: Create services via Admin Panel → Services & Categories');
      console.log('      1. Go to Services & Categories page');
      console.log('      2. Click "Add Service"');
      console.log('      3. Select a category from the dropdown');
      console.log('      4. Enter service name and price');
      console.log('      5. Click "Add Service"');
    } else if (isActiveCount === 0) {
      console.error('   ❌ PROBLEM: All services have isActive: false');
      console.log('   ✅ SOLUTION: Enable services (manual Firestore edit or code update needed)');
    } else if (validCategoryIdCount < isActiveCount) {
      console.error('   ❌ PROBLEM: Some services have invalid or non-existent categoryId');
      console.log('   ✅ SOLUTION: Delete services and recreate with correct category');
    } else if (isActiveCount > 0 && validCategoryIdCount === isActiveCount) {
      console.log('   ✅ ALL CHECKS PASSED - Data structure is correct!');
      console.log('   💡 If dropdown still empty, check browser console for other errors');
    }

    // 5. Raw data export for debugging
    console.log('\n5️⃣ RAW DATA (for debugging):');
    console.log('Categories:', categoryIds);
    console.log('Services:', servicesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })));

  } catch (error) {
    console.error('❌ DIAGNOSTIC ERROR:', error);
  }
}

// Export for use
if (typeof window !== 'undefined') {
  (window as any).diagnoseFIRESTORE_DATA = diagnoseFIRESTORE_DATA;
}
