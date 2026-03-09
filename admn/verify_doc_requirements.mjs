/**
 * VERIFICATION SCRIPT - Document Requirements Setup & Debugging
 * 
 * This script will:
 * 1. Check all services in Firestore
 * 2. Check if they have document requirements
 * 3. If missing, optionally create sample requirements
 * 4. Provide debugging information
 * 
 * Usage: npm run verify-docs
 * Add to package.json: "verify-docs": "node verify_doc_requirements.mjs"
 */

import {
  initializeApp,
} from 'https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js';
import {
  getFirestore,
  collection,
  where,
  getDocs,
  query,
  addDoc,
  serverTimestamp,
  updateDoc,
  doc,
} from 'https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js';

const firebaseConfig = {
  apiKey: 'AIzaSyC72UmM3pMwRBh0pKjKy_jN9wmpE_MP_GM',
  authDomain: 'jenisha-46c62.firebaseapp.com',
  projectId: 'jenisha-46c62',
  storageBucket: 'jenisha-46c62.appspot.com',
  messagingSenderId: '245020879102',
  appId: '1:245020879102:web:05969fe2820677483c9daf',
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function verifyDocumentRequirements() {
  console.log('\n' + '='.repeat(70));
  console.log('🔍 DOCUMENT REQUIREMENTS VERIFICATION & SETUP');
  console.log('='.repeat(70));

  try {
    // STEP 1: Get all active services
    console.log('\n📋 STEP 1: Fetching all active services...');
    const servicesQuery = query(
      collection(db, 'services'),
      where('isActive', '==', true)
    );
    const servicesSnap = await getDocs(servicesQuery);

    const servicesList = [];
    servicesSnap.forEach((doc) => {
      servicesList.push({
        id: doc.id,
        name: doc.data().name,
        categoryId: doc.data().categoryId,
      });
    });

    if (servicesList.length === 0) {
      console.log('  ❌ No active services found!');
      console.log('\n  💡 ACTION REQUIRED:');
      console.log('     1. Go to Admin Panel → Service Management');
      console.log('     2. Create a category');
      console.log('     3. Create a service under that category');
      console.log('     4. Come back and run this script again');
      return;
    }

    console.log(`  ✅ Found ${servicesList.length} active service(s):\n`);
    servicesList.forEach((s, idx) => {
      console.log(`    ${idx + 1}. "${s.name}" (ID: ${s.id})`);
    });

    // STEP 2: Check document requirements for each service
    console.log('\n' + '-'.repeat(70));
    console.log('📄 STEP 2: Checking document requirements for each service...\n');

    const servicesWithoutDocs = [];
    const allDocsInfo = {};

    for (const service of servicesList) {
      const docsQuery = query(
        collection(db, 'document_requirements'),
        where('serviceId', '==', service.id),
        where('isActive', '==', true)
      );
      const docsSnap = await getDocs(docsQuery);

      const docsList = [];
      docsSnap.forEach((doc) => {
        docsList.push({
          id: doc.id,
          name: doc.data().documentName,
          required: doc.data().required,
          isActive: doc.data().isActive,
          order: doc.data().order,
        });
      });

      allDocsInfo[service.id] = docsList;

      console.log(`  Service: "${service.name}"`);
      if (docsList.length === 0) {
        console.log(`    ⚠️  NO DOCUMENT REQUIREMENTS FOUND\n`);
        servicesWithoutDocs.push(service);
      } else {
        console.log(`    ✅ ${docsList.length} requirement(s):`);
        docsList.forEach((d, idx) => {
          const status = d.isActive ? '✅' : '❌';
          console.log(`      ${idx + 1}. ${d.name} ${status} (required: ${d.required})`);
        });
        console.log();
      }
    }

    // STEP 3: Summary and recommendations
    console.log('='.repeat(70));
    console.log('📊 SUMMARY\n');
    console.log(`  Total Services: ${servicesList.length}`);
    console.log(
      `  Services WITH requirements: ${servicesList.length - servicesWithoutDocs.length}`
    );
    console.log(`  Services WITHOUT requirements: ${servicesWithoutDocs.length}\n`);

    if (servicesWithoutDocs.length > 0) {
      console.log('🚨 MISSING DOCUMENT REQUIREMENTS:\n');
      servicesWithoutDocs.forEach((service) => {
        console.log(`  ❌ Service: "${service.name}" (ID: ${service.id})`);
      });

      console.log('\n' + '='.repeat(70));
      console.log('💡 HOW TO FIX:\n');
      console.log('  OPTION 1: Use Admin Panel (Recommended)');
      console.log('  ─────────────────────────────────────');
      console.log('  1. Open Admin Panel');
      console.log('  2. Go to "Document Requirements Configuration"');
      console.log('  3. Select each service listed above');
      console.log('  4. Click "+ Add Document" and add required documents');
      console.log('  5. Agents will then see these documents in the app\n');

      console.log('  OPTION 2: Create Sample Requirements via Script');
      console.log('  ──────────────────────────────────────────────');
      console.log(
        '  This will create SAMPLE documents to test the flow.\n'
      );
      console.log(
        '  Available sample documents: [ID Proof, Address Proof, Bank Account]\n'
      );

      // Show a message about how to create them
      console.log('  To create sample documents, run:');
      console.log('  $ npm run create-sample-docs\n');
    } else {
      console.log('✅ All services have document requirements configured!\n');
      console.log('📲 FLUTTER APP FLOW:');
      console.log(
        '  When users select a service, they will see these documents:'
      );
      console.log();
      for (const [serviceId, docs] of Object.entries(allDocsInfo)) {
        const service = servicesList.find((s) => s.id === serviceId);
        console.log(`    Service: "${service.name}"`);
        docs.forEach((d) => {
          console.log(`      • ${d.name}`);
        });
      }
    }

    console.log('\n' + '='.repeat(70));
    console.log('');

  } catch (error) {
    console.error('\n❌ Error during verification:', error);
    console.log(
      '\n💡 Common fixes:'
    );
    console.log('  1. Check Firebase credentials in config');
    console.log('  2. Ensure Firestore collections exist');
    console.log('  3. Check internet connection');
  }
}

async function createSampleDocuments() {
  console.log('\n' + '='.repeat(70));
  console.log('📝 CREATING SAMPLE DOCUMENT REQUIREMENTS');
  console.log('='.repeat(70) + '\n');

  try {
    // Get all active services
    const servicesQuery = query(
      collection(db, 'services'),
      where('isActive', '==', true)
    );
    const servicesSnap = await getDocs(servicesQuery);

    const servicesList = [];
    servicesSnap.forEach((doc) => {
      servicesList.push({
        id: doc.id,
        name: doc.data().name,
      });
    });

    if (servicesList.length === 0) {
      console.log('❌ No services found. Create a service first.');
      return;
    }

    const sampleDocs = [
      { name: 'Government ID Proof', required: true },
      { name: 'Address Proof', required: true },
      { name: 'Bank Account Details', required: false },
    ];

    let totalCreated = 0;

    for (const service of servicesList) {
      console.log(`📌 Service: "${service.name}"\n`);

      // Check if already has docs
      const existingQuery = query(
        collection(db, 'document_requirements'),
        where('serviceId', '==', service.id)
      );
      const existingSnap = await getDocs(existingQuery);

      if (existingSnap.size > 0) {
        console.log(`   ⏭️  Already has ${existingSnap.size} requirement(s), skipping...\n`);
        continue;
      }

      // Create sample docs
      for (const [idx, sampleDoc] of sampleDocs.entries()) {
        const docRef = await addDoc(
          collection(db, 'document_requirements'),
          {
            serviceId: service.id,
            documentName: sampleDoc.name,
            required: sampleDoc.required,
            isActive: true,
            order: idx,
            createdAt: serverTimestamp(),
          }
        );

        totalCreated++;
        const reqText = sampleDoc.required ? '✅ Required' : '⏳ Optional';
        console.log(`   ✓ ${sampleDoc.name} (${reqText})`);
      }

      console.log();
    }

    console.log('='.repeat(70));
    console.log(`\n✅ Created ${totalCreated} sample document requirements!\n`);
    console.log('📲 Test in Flutter App:');
    console.log('  1. Open the Agent App');
    console.log('  2. Navigate to a service');
    console.log('  3. You should see "Required Documents" section');
    console.log('  4. The sample documents will be listed there\n');
    console.log('='.repeat(70) + '\n');

  } catch (error) {
    console.error('\n❌ Error creating sample documents:', error);
  }
}

// Parse command line arguments
const command = process.argv[2];

if (command === 'create-sample') {
  createSampleDocuments();
} else {
  verifyDocumentRequirements();
}
