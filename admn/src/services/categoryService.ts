import {
  getFirestore,
  collection,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  onSnapshot,
  addDoc,
  serverTimestamp,
  Firestore,
  Timestamp,
} from 'firebase/firestore';
import { getStorage, ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';
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
const storage = getStorage(app);

// Type definitions - FLAT COLLECTION MODEL
export interface ServiceCategory {
  id: string;
  name: string;
  icon?: string;
  customLogoUrl?: string;
  order?: number;
  isActive: boolean;
  sideCategoryId?: string;
  createdAt: Timestamp | null;
}

export interface Service {
  id: string;
  categoryId: string; // Reference to categories collection
  name: string;
  price?: number;
  logoUrl?: string;   // Hosted on Hostinger: /uploads/services/{ts}_{filename}
  redirectUrl?: string; // Optional URL - if set, tapping the service opens this URL instead of the form
  formTemplateUrl?: string; // Optional form template (PDF/DOC) hosted on Hostinger: /uploads/forms/templates/
  isActive: boolean;
  createdAt: Timestamp | null;
}

// Service with enhanced information for UI display
export interface ServiceWithCategory extends Service {
  categoryName: string; // Display name of category
}

export interface DocumentRequirement {
  id: string;
  serviceId: string; // Reference to services collection
  required: boolean;
  type?: string;       // e.g. "Image Upload", "PDF Upload", "Text"
  maxSizeKB?: number;  // Only applicable when type === "Image Upload" (range: 500–5120 KB)
  order?: number;
  createdAt: Timestamp | null;
}

// New dynamic field structure
export interface DynamicField {
  fieldId: string;
  fieldName: string;
  fieldType: 'text' | 'number' | 'date' | 'dob' | 'address' | 'mobile' | 'image' | 'pdf' | 'appointment' | 'time_range' | 'document' | 'template';
  isRequired: boolean;
  placeholder?: string;
  displayOrder: number;
  maxSizeKB?: number; // Applicable for image/pdf/document/template uploads
}

export interface ServiceDocumentConfig {
  id: string; // serviceId
  serviceId: string;
  fields: DynamicField[];
  updatedAt: Timestamp | null;
}

// ============================================
// CATEGORY SERVICE - queries 'categories' collection
// ============================================
export const categoryService = {
  // Add new category
  addCategory: async (name: string, icon?: string, order?: number, sideCategoryId?: string): Promise<string> => {
    try {
      const docRef = await addDoc(collection(firestore, 'categories'), {
        name: name.trim(),
        icon: icon || '',
        order: order || 0,
        isActive: true,
        sideCategoryId: sideCategoryId || '',
        createdAt: serverTimestamp(),
      });
      console.log(`✅ Category created: ${name}`);
      return docRef.id;
    } catch (error) {
      console.error('❌ Error adding category:', error);
      throw error;
    }
  },
  // Upload category custom logo to Hostinger
  uploadCategoryLogo: async (categoryId: string, file: File): Promise<string> => {
    try {
      // Validate file type
      const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp'];
      if (!allowedTypes.includes(file.type)) {
        throw new Error('Invalid file type. Only PNG, JPG, JPEG, GIF, and WEBP are allowed.');
      }

      // Validate file size (max 5MB)
      if (file.size > 5 * 1024 * 1024) {
        throw new Error('File too large. Maximum size is 5MB.');
      }

      const UPLOAD_ENDPOINT = 'https://jenishaonlineservice.com/uploads/upload_logo.php';

      console.log('📤 Uploading logo to Hostinger...');
      console.log('   File:', file.name, `(${(file.size / 1024).toFixed(2)} KB)`);
      console.log('   Category ID:', categoryId);

      // Create FormData
      const formData = new FormData();
      formData.append('logo', file);

      // Upload to Hostinger PHP endpoint
      const response = await fetch(UPLOAD_ENDPOINT, {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        throw new Error(`Upload failed: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();

      if (!result.success || !result.imageUrl) {
        throw new Error(result.error || 'Upload failed: No image URL returned');
      }

      const logoUrl = result.imageUrl;
      console.log('✅ Logo uploaded successfully:', logoUrl);

      // Update category document with logo URL
      await categoryService.updateCategory(categoryId, { customLogoUrl: logoUrl });

      console.log(`✅ Logo URL saved to category ${categoryId}`);
      return logoUrl;
    } catch (error) {
      console.error('❌ Error uploading category logo:', error);
      throw error;
    }
  },

  // Delete category custom logo (no need to delete from Hostinger, just remove URL reference)
  deleteCategoryLogo: async (categoryId: string): Promise<void> => {
    try {
      // Remove logo URL from category document
      await categoryService.updateCategory(categoryId, { customLogoUrl: '' });

      console.log(`✅ Logo reference removed for category ${categoryId}`);
    } catch (error) {
      console.error('❌ Error deleting category logo:', error);
      throw error;
    }
  },

  // Update category
  updateCategory: async (categoryId: string, updates: Partial<ServiceCategory>): Promise<void> => {
    try {
      const categoryRef = doc(firestore, 'categories', categoryId);
      const updateData: any = { ...updates };
      delete updateData.id;

      await updateDoc(categoryRef, updateData);
      console.log(`✅ Category ${categoryId} updated`);
    } catch (error) {
      console.error('❌ Error updating category:', error);
      throw error;
    }
  },

  // Delete category (marks as inactive instead of permanently deleting)
  deleteCategory: async (categoryId: string): Promise<void> => {
    try {
      const categoryRef = doc(firestore, 'categories', categoryId);
      // Mark as inactive instead of deleting to maintain data integrity
      await updateDoc(categoryRef, { isActive: false });
      console.log(`✅ Category ${categoryId} marked as inactive`);
    } catch (error) {
      console.error('❌ Error deleting category:', error);
      throw error;
    }
  },

  // Subscribe to all categories with real-time listener
  subscribeToCategories: (
    callback: (categories: ServiceCategory[]) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      const q = query(collection(firestore, 'categories'));

      return onSnapshot(
        q,
        (snapshot) => {
          const categories: ServiceCategory[] = [];

          snapshot.forEach((doc) => {
            const data = doc.data();
            categories.push({
              id: doc.id,
              name: data.name || '',
              icon: data.icon || '',
              customLogoUrl: data.customLogoUrl || undefined,
              order: data.order || 0,
              isActive: data.isActive ?? true,
              sideCategoryId: data.sideCategoryId || '',
              createdAt: data.createdAt || null,
            });
          });

          // Sort by order field first, then by createdAt descending
          categories.sort((a, b) => {
            const orderDiff = (a.order || 0) - (b.order || 0);
            if (orderDiff !== 0) return orderDiff;

            // If order is same, sort by createdAt descending
            if (a.createdAt && b.createdAt) {
              const timeA = 'toMillis' in a.createdAt
                ? (a.createdAt as any).toMillis()
                : (a.createdAt as any).getTime();
              const timeB = 'toMillis' in b.createdAt
                ? (b.createdAt as any).toMillis()
                : (b.createdAt as any).getTime();
              return timeA - timeB;
            }
            return 0;
          });

          callback(categories);
        },
        (error) => {
          console.error('❌ Error listening to categories:', error);
          if (onError) onError(error as Error);
        }
      );
    } catch (error) {
      console.error('❌ Error subscribing to categories:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },

  // Subscribe to active categories only
  subscribeToActiveCategories: (
    callback: (categories: ServiceCategory[]) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      const q = query(
        collection(firestore, 'categories'),
        where('isActive', '==', true)
      );

      return onSnapshot(
        q,
        (snapshot) => {
          const categories: ServiceCategory[] = [];

          snapshot.forEach((doc) => {
            const data = doc.data();
            categories.push({
              id: doc.id,
              name: data.name || '',
              icon: data.icon || '',
              customLogoUrl: data.customLogoUrl || undefined,
              order: data.order || 0,
              isActive: true,
              createdAt: data.createdAt || null,
            });
          });

          // Sort by order field first, then by createdAt ascending (in memory)
          categories.sort((a, b) => {
            const orderDiff = (a.order || 0) - (b.order || 0);
            if (orderDiff !== 0) return orderDiff;

            if (a.createdAt && b.createdAt) {
              const timeA = 'toMillis' in a.createdAt
                ? (a.createdAt as any).toMillis()
                : (a.createdAt as any).getTime();
              const timeB = 'toMillis' in b.createdAt
                ? (b.createdAt as any).toMillis()
                : (b.createdAt as any).getTime();
              return timeA - timeB;
            }
            return 0;
          });

          callback(categories);
        },
        (error) => {
          console.error('❌ Error listening to active categories:', error);
          if (onError) onError(error as Error);
        }
      );
    } catch (error) {
      console.error('❌ Error subscribing to active categories:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },
};

// ============================================
// SIDE CATEGORY SERVICE - queries 'side_categories' collection (parent)
// ============================================
export interface SideCategory {
  id: string;
  name: string;
  icon?: string;
  customLogoUrl?: string;
  order?: number;
  isActive: boolean;
  createdAt: Timestamp | null;
}

export const sideCategoryService = {
  // Subscribe to all active side categories
  subscribeToSideCategories: (
    callback: (items: SideCategory[]) => void,
    onError?: (error: Error) => void
  ) => {
    const q = query(collection(firestore, 'side_categories'), where('isActive', '==', true));
    return onSnapshot(
      q,
      (snapshot) => {
        const items: SideCategory[] = snapshot.docs.map((d) => ({
          id: d.id,
          ...(d.data() as Omit<SideCategory, 'id'>),
        }));
        items.sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
        callback(items);
      },
      (err) => onError?.(err as Error)
    );
  },

  // Add new side category
  addSideCategory: async (name: string, icon?: string): Promise<string> => {
    const docRef = await addDoc(collection(firestore, 'side_categories'), {
      name: name.trim(),
      icon: icon || '',
      order: 0,
      isActive: true,
      createdAt: serverTimestamp(),
    });
    return docRef.id;
  },

  // Upload logo to Hostinger and store URL
  uploadLogo: async (sideCategoryId: string, file: File): Promise<string> => {
    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    if (!allowedTypes.includes(file.type)) throw new Error('Invalid file type.');
    if (file.size > 5 * 1024 * 1024) throw new Error('File too large (max 5 MB).');

    const formData = new FormData();
    formData.append('logo', file);
    const res = await fetch('https://jenishaonlineservice.com/uploads/upload_logo.php', {
      method: 'POST', body: formData,
    });
    if (!res.ok) throw new Error(`Upload failed: ${res.status}`);
    const result = await res.json();
    if (!result.success || !result.imageUrl) throw new Error(result.error || 'No URL returned');

    const logoUrl = result.imageUrl as string;
    await updateDoc(doc(firestore, 'side_categories', sideCategoryId), { customLogoUrl: logoUrl });
    return logoUrl;
  },

  // Update a side category
  updateSideCategory: async (id: string, updates: Partial<SideCategory>): Promise<void> => {
    const data = { ...updates };
    delete (data as any).id;
    delete (data as any).createdAt;
    await updateDoc(doc(firestore, 'side_categories', id), data as any);
  },

  // Soft-delete (mark inactive)
  deleteSideCategory: async (id: string): Promise<void> => {
    await updateDoc(doc(firestore, 'side_categories', id), { isActive: false });
  },
};

// ============================================
// SERVICE MANAGEMENT SERVICE - queries 'services' collection with categoryId reference
// ============================================
export const serviceManagementService = {
  // Subscribe to all active services with category names for Document Requirements dropdown
  // FIXED: Simplified logic without setTimeout race conditions
  // Works with 0 services AND 0 categories - shows empty states properly
  subscribeToActiveServices: (
    callback: (services: ServiceWithCategory[]) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      console.log('📋 subscribeToActiveServices: Starting services + categories subscription');
      
      // Map to store category names by ID
      const categoriesMap = new Map<string, string>();
      let categoriesLoaded = false;
      let servicesLoaded = false;
      let unsubscribeCategories: (() => void) | null = null;
      let unsubscribeServices: (() => void) | null = null;
      let lastServicesData: ServiceWithCategory[] = [];

      // Helper to send combined data
      const sendData = () => {
        console.log('📤 subscribeToActiveServices: Sending combined data', {
          services: lastServicesData.length,
          categoriesLoaded,
          servicesLoaded
        });
        callback(lastServicesData);
      };

      // First, subscribe to categories to build lookup map
      unsubscribeCategories = categoryService.subscribeToCategories(
        (categories) => {
          console.log('📂 subscribeToActiveServices: Categories loaded for lookup', {
            count: categories.length,
            categories: categories.map(c => `${c.id}:${c.name}`)
          });
          // Populate the categories map for service lookups
          categoriesMap.clear();
          categories.forEach((cat) => {
            categoriesMap.set(cat.id, cat.name);
          });
          categoriesLoaded = true;

          // If services already loaded, send updated data with category names
          if (servicesLoaded) {
            sendData();
          }
        },
        (error) => {
          console.error('❌ subscribeToActiveServices: Error loading categories:', error);
          categoriesLoaded = true; // Don't block on categories
          if (servicesLoaded) {
            sendData();
          }
          if (onError) onError(error as Error);
        }
      );

      // Subscribe to services without depending on categories being loaded first
      console.log('🔍 subscribeToActiveServices: Starting services listener immediately');
      
      const q = query(
        collection(firestore, 'services'),
        where('isActive', '==', true),
        orderBy('createdAt', 'asc')
      );

      unsubscribeServices = onSnapshot(
        q,
        (snapshot) => {
          console.log('📊 subscribeToActiveServices: Services snapshot received', {
            docsCount: snapshot.docs.length,
            empty: snapshot.empty,
            timestamp: new Date().toISOString()
          });

          // DEBUG: Log raw service documents
          console.log('🔍 RAW SERVICE DOCUMENTS FROM FIRESTORE:');
          snapshot.docs.forEach(doc => {
            const data = doc.data();
            console.log(`   ${doc.id}:`, {
              name: data.name,
              categoryId: data.categoryId,
              isActive: data.isActive,
              price: data.price,
              createdAt: data.createdAt ? 'exists' : 'missing'
            });
          });

          const services: ServiceWithCategory[] = [];

          snapshot.forEach((doc) => {
            const data = doc.data();
            const categoryId = data.categoryId || '';
            const categoryName = categoriesMap.get(categoryId) || 'Uncategorized';

            services.push({
              id              : doc.id,
              categoryId      : categoryId,
              name            : data.name || '',
              price           : data.price || undefined,
              logoUrl         : data.logoUrl || '',
              redirectUrl     : data.redirectUrl || '',
              formTemplateUrl : data.formTemplateUrl || '',
              isActive        : data.isActive ?? true,
              createdAt       : data.createdAt || null,
              categoryName    : categoryName,
            });
          });

          // Ensure client-side stable ordering: createdAt ascending
          services.sort((a, b) => {
            if (a.createdAt && b.createdAt) {
              const timeA = 'toMillis' in a.createdAt
                ? (a.createdAt as any).toMillis()
                : (a.createdAt as any).getTime();
              const timeB = 'toMillis' in b.createdAt
                ? (b.createdAt as any).toMillis()
                : (b.createdAt as any).getTime();
              return timeA - timeB;
            }
            return 0;
          });

          lastServicesData = services;
          servicesLoaded = true;

          console.log('✅ subscribeToActiveServices: Total services loaded:', services.length);
          if (services.length === 0) {
            console.warn('⚠️  No active services - this is OK if services haven\'t been created yet');
          } else {
            console.log('   Services by category:');
            const byCategory = new Map<string, number>();
            services.forEach(s => {
              const count = (byCategory.get(s.categoryName) || 0) + 1;
              byCategory.set(s.categoryName, count);
            });
            byCategory.forEach((count, cat) => {
              console.log(`   - ${cat}: ${count} service(s)`);
            });
          }

          sendData();
        },
        (error) => {
          console.error('❌ subscribeToActiveServices: ERROR in services listener:', error);
          console.error('   Error code:', (error as any).code);
          console.error('   Error message:', (error as any).message);
          
          // Common error diagnostics
          if ((error as any).code === 'permission-denied') {
            console.error('   💡 FIX: Firestore rules deny read access to services collection');
            console.error('   Check: Firebase Console → Firestore → Rules');
          } else if ((error as any).code === 'not-found') {
            console.error('   💡 FIX: Services collection does not exist (will be created on first service)');
          } else if ((error as any).code === 'failed-precondition') {
            console.error('   💡 FIX: Composite index required but not created');
            console.error('   Solution: Remove orderBy from query OR create the index');
          }
          
          servicesLoaded = true;
          lastServicesData = [];
          sendData();
          if (onError) onError(error as Error);
        }
      );

      // Return combined unsubscribe function
      return () => {
        console.log('🛑 subscribeToActiveServices: Unsubscribing');
        if (unsubscribeCategories) unsubscribeCategories();
        if (unsubscribeServices) unsubscribeServices();
      };
    } catch (error: any) {
      console.error('❌ subscribeToActiveServices: Exception caught:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },

  // ──────────────────────────────────────────────────────────────────
  // SERVICE LOGO HELPERS (Hostinger)
  // ──────────────────────────────────────────────────────────────────
  SERVICE_LOGO_UPLOAD_ENDPOINT: 'https://jenishaonlineservice.com/uploads/upload_service_logo.php',
  SERVICE_LOGO_DELETE_ENDPOINT: 'https://jenishaonlineservice.com/uploads/delete_service_logo.php',

  // Upload a service logo to Hostinger.
  // Returns the public URL of the uploaded image.
  uploadServiceLogo: async (file: File): Promise<string> => {
    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
      throw new Error('Invalid file type. Only PNG, JPG, JPEG, GIF, WEBP are allowed.');
    }
    if (file.size > 5 * 1024 * 1024) {
      throw new Error('File too large. Maximum size is 5 MB.');
    }

    const UPLOAD_ENDPOINT = 'https://jenishaonlineservice.com/uploads/upload_service_logo.php';
    console.log('📤 Uploading service logo to Hostinger …', file.name);

    const formData = new FormData();
    formData.append('logo', file);

    const response = await fetch(UPLOAD_ENDPOINT, { method: 'POST', body: formData });

    if (!response.ok) {
      throw new Error(`Upload failed: ${response.status} ${response.statusText}`);
    }

    const result = await response.json();
    if (!result.success || !result.imageUrl) {
      throw new Error(result.error || 'Upload failed: no imageUrl in response');
    }

    console.log('✅ Service logo uploaded:', result.imageUrl);
    return result.imageUrl as string;
  },

  // Delete a service logo file from Hostinger.
  // logoUrl should be the full public URL (e.g. https://…/uploads/services/123_name.jpg).
  // Failures are logged but not thrown — safe to call fire-and-forget.
  deleteServiceLogoFile: async (logoUrl: string): Promise<void> => {
    if (!logoUrl) return;
    try {
      const DELETE_ENDPOINT = 'https://jenishaonlineservice.com/uploads/delete_service_logo.php';
      const filename = logoUrl.split('/').pop() ?? '';
      if (!filename) return;

      console.log('🗑️  Deleting service logo from Hostinger:', filename);
      const response = await fetch(DELETE_ENDPOINT, {
        method : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body   : JSON.stringify({ filename }),
      });
      const result = await response.json();
      if (result.success) {
        console.log('✅ Service logo deleted from Hostinger:', filename);
      } else {
        console.warn('⚠️  Hostinger delete reported failure:', result.error);
      }
    } catch (err) {
      console.warn('⚠️  Could not delete service logo from Hostinger (non-fatal):', err);
    }
  },

  // Upload a form template file (PDF/DOC) to Hostinger
  uploadFormTemplate: async (file: File): Promise<string> => {
    const allowedTypes = [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ];
    const allowedExts = ['pdf', 'doc', 'docx'];
    const ext = file.name.split('.').pop()?.toLowerCase() ?? '';
    if (!allowedTypes.includes(file.type) && !allowedExts.includes(ext)) {
      throw new Error('Invalid file type. Only PDF, DOC, DOCX are allowed.');
    }
    if (file.size > 20 * 1024 * 1024) {
      throw new Error('File too large. Max 20 MB.');
    }
    const UPLOAD_ENDPOINT = 'https://jenishaonlineservice.com/uploads/upload_form_template.php';
    const formData = new FormData();
    formData.append('file', file);
    const response = await fetch(UPLOAD_ENDPOINT, { method: 'POST', body: formData });
    if (!response.ok) throw new Error(`Upload failed: ${response.status} ${response.statusText}`);
    const result = await response.json();
    if (!result.success || !result.fileUrl) throw new Error(result.error || 'Upload failed: no fileUrl in response');
    console.log('✅ Form template uploaded:', result.fileUrl);
    return result.fileUrl as string;
  },

  // Add service (with categoryId reference, not nested)
  addService: async (categoryId: string, serviceName: string, price?: number, logoUrl?: string, redirectUrl?: string, formTemplateUrl?: string): Promise<string> => {
    try {
      const docRef = await addDoc(collection(firestore, 'services'), {
        categoryId      : categoryId, // Reference, not nested
        name            : serviceName.trim(),
        price           : price || null,
        logoUrl         : logoUrl || '',
        redirectUrl     : redirectUrl || '',
        formTemplateUrl : formTemplateUrl || '',
        isActive        : true,
        createdAt       : serverTimestamp(),
      });

      console.log(`✅ Service created: ${serviceName} for category ${categoryId}`);
      return docRef.id;
    } catch (error) {
      console.error('❌ Error adding service:', error);
      throw error;
    }
  },

  // Update service
  updateService: async (serviceId: string, updates: Partial<Service>): Promise<void> => {
    try {
      const serviceRef = doc(firestore, 'services', serviceId);
      const updateData: any = { ...updates };
      delete updateData.id;

      await updateDoc(serviceRef, updateData);
      console.log(`✅ Service ${serviceId} updated`);
    } catch (error) {
      console.error('❌ Error updating service:', error);
      throw error;
    }
  },

  // Delete service (marks as inactive instead of permanently deleting)
  deleteService: async (serviceId: string): Promise<void> => {
    try {
      const serviceRef = doc(firestore, 'services', serviceId);
      // Mark as inactive instead of deleting to maintain data integrity and real-time sync
      await updateDoc(serviceRef, { isActive: false });
      console.log(`✅ Service ${serviceId} marked as inactive`);
    } catch (error) {
      console.error('❌ Error deleting service:', error);
      throw error;
    }
  },

  // Permanently delete a service and its document-field configuration
  deleteServicePermanently: async (serviceId: string): Promise<void> => {
    try {
      await Promise.all([
        deleteDoc(doc(firestore, 'services', serviceId)),
        deleteDoc(doc(firestore, 'service_document_fields', serviceId)),
      ]);
      console.log(`✅ Service ${serviceId} permanently deleted`);
    } catch (error) {
      console.error('❌ Error permanently deleting service:', error);
      throw error;
    }
  },

  // Subscribe to services for a specific category
  subscribeToServicesForCategory: (
    categoryId: string,
    callback: (services: Service[]) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      const q = query(
        collection(firestore, 'services'),
        where('categoryId', '==', categoryId),
        orderBy('createdAt', 'desc')
      );

      return onSnapshot(
        q,
        (snapshot) => {
          const services: Service[] = [];

          snapshot.forEach((doc) => {
            const data = doc.data();
            services.push({
              id              : doc.id,
              categoryId      : data.categoryId,
              name            : data.name || '',
              price           : data.price || undefined,
              logoUrl         : data.logoUrl || '',
              redirectUrl     : data.redirectUrl || '',
              formTemplateUrl : data.formTemplateUrl || '',
              isActive        : data.isActive ?? true,
              createdAt       : data.createdAt || null,
            });
          });

          callback(services);
        },
        (error) => {
          console.error('❌ Error listening to services for category:', error);
          if (onError) onError(error as Error);
        }
      );
    } catch (error) {
      console.error('❌ Error subscribing to services for category:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },

  // Subscribe to all services across all categories
  subscribeToAllServices: (
    callback: (services: Array<Service & { categoryName: string }>) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      // Query all services ordered by createdAt ascending so newer services appear at the bottom
      const q = query(collection(firestore, 'services'), orderBy('createdAt', 'asc'));

      // Map to store categories by ID for lookup
      const categoriesMap = new Map<string, string>();
      let categoriesLoaded = false;
      let unsubscribeCategories: (() => void) | null = null;
      let unsubscribeServices: (() => void) | null = null;
      let lastServicesSnapshot: Array<Service & { categoryName: string }> | null = null;

      // First, subscribe to categories to build lookup map
      unsubscribeCategories = categoryService.subscribeToCategories(
        (categories) => {
          // Populate the categories map for service lookups
          categoriesMap.clear();
          categories.forEach((cat) => {
            categoriesMap.set(cat.id, cat.name);
          });
          categoriesLoaded = true;

          // If we have cached services, reprocess them with updated categories
          if (lastServicesSnapshot) {
            // Update category names in cached services
            lastServicesSnapshot = lastServicesSnapshot.map((svc) => ({
              ...svc,
              categoryName: categoriesMap.get(svc.categoryId) || 'Unknown Category',
            }));
            callback(lastServicesSnapshot);
          }
        },
        (error) => {
          console.error('❌ Error loading categories for service lookup:', error);
          if (onError) onError(error);
        }
      );

      // Subscribe to services - fires once categories are loaded
      const initializeServicesListener = () => {
        unsubscribeServices = onSnapshot(
          q,
          (snapshot) => {
            const services: Array<Service & { categoryName: string }> = [];

            snapshot.forEach((doc) => {
              const data = doc.data();
              const categoryName = categoriesMap.get(data.categoryId) || 'Unknown Category';

              services.push({
                id              : doc.id,
                categoryId      : data.categoryId,
                name            : data.name || '',
                price           : data.price || undefined,
                logoUrl         : data.logoUrl || '',
                redirectUrl     : data.redirectUrl || '',
                formTemplateUrl : data.formTemplateUrl || '',
                isActive        : data.isActive ?? true,
                createdAt       : data.createdAt || null,
                categoryName    : categoryName,
              });
            });

            // Ensure client-side stable ordering: createdAt ascending
            services.sort((a, b) => {
              if (a.createdAt && b.createdAt) {
                const timeA = 'toMillis' in a.createdAt
                  ? (a.createdAt as any).toMillis()
                  : (a.createdAt as any).getTime();
                const timeB = 'toMillis' in b.createdAt
                  ? (b.createdAt as any).toMillis()
                  : (b.createdAt as any).getTime();
                return timeA - timeB;
              }
              return 0;
            });

            lastServicesSnapshot = services;
            callback(services);
          },
          (error) => {
            console.error('❌ Error listening to all services:', error);
            if (onError) onError(error as Error);
          }
        );
      };

      // Ensure categories load before starting services listener
      // Use interval to check when categories are ready
      const categoryReadyInterval = setInterval(() => {
        if (categoriesLoaded && !unsubscribeServices) {
          clearInterval(categoryReadyInterval);
          initializeServicesListener();
        }
      }, 50);

      // Failsafe: if categories don't load within 3 seconds, start anyway
      const failsafeTimeout = setTimeout(() => {
        clearInterval(categoryReadyInterval);
        if (!unsubscribeServices) {
          console.warn('⚠️  Categories not fully loaded, starting services listener');
          initializeServicesListener();
        }
      }, 3000);

      // Return combined unsubscribe function
      return () => {
        clearInterval(categoryReadyInterval);
        clearTimeout(failsafeTimeout);
        if (unsubscribeServices) unsubscribeServices();
        if (unsubscribeCategories) unsubscribeCategories();
      };
    } catch (error: any) {
      console.error('❌ Error subscribing to all services:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },
};

// ============================================
// DOCUMENT REQUIREMENTS SERVICE - queries 'document_requirements' collection with serviceId reference
// ============================================
export const documentRequirementsService = {
  // Add document requirement (with serviceId reference)
  addDocumentRequirement: async (
    serviceId: string,
    documentName: string,
    required: boolean = true,
    order: number = 0,
    type?: string,
    maxSizeKB?: number
  ): Promise<string> => {
    try {
      const fieldData: any = {
        serviceId: serviceId, // Reference, not nested
        documentName: documentName.trim(),
        required: required,
        isActive: true,
        order: order,
        createdAt: serverTimestamp(),
      };

      if (type) fieldData.type = type;
      // Only persist maxSizeKB when the field type is Image Upload
      if (type === 'Image Upload' && maxSizeKB != null) {
        fieldData.maxSizeKB = maxSizeKB;
      }

      const docRef = await addDoc(collection(firestore, 'document_requirements'), fieldData);

      console.log(`✅ Document requirement created: ${documentName} for service ${serviceId}`);
      return docRef.id;
    } catch (error) {
      console.error('❌ Error adding document requirement:', error);
      throw error;
    }
  },

  // Update document requirement
  updateDocumentRequirement: async (
    docReqId: string,
    updates: Partial<DocumentRequirement>
  ): Promise<void> => {
    try {
      const docRef = doc(firestore, 'document_requirements', docReqId);
      const updateData: any = { ...updates };
      delete updateData.id;

      await updateDoc(docRef, updateData);
      console.log(`✅ Document requirement ${docReqId} updated`);
    } catch (error) {
      console.error('❌ Error updating document requirement:', error);
      throw error;
    }
  },

  // Delete document requirement (marks as inactive instead of permanently deleting)
  deleteDocumentRequirement: async (docReqId: string): Promise<void> => {
    try {
      const docRef = doc(firestore, 'document_requirements', docReqId);
      // Mark as inactive instead of deleting to maintain data integrity
      await updateDoc(docRef, { isActive: false });
      console.log(`✅ Document requirement ${docReqId} marked as inactive`);
    } catch (error) {
      console.error('❌ Error deleting document requirement:', error);
      throw error;
    }
  },

  // Subscribe to document requirements for a specific service (active only)
  subscribeToDocumentRequirementsForService: (
    serviceId: string,
    callback: (requirements: DocumentRequirement[]) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      const q = query(
        collection(firestore, 'document_requirements'),
        where('serviceId', '==', serviceId),
        where('isActive', '==', true),
        orderBy('order', 'asc')
      );

      return onSnapshot(
        q,
        (snapshot) => {
          const requirements: DocumentRequirement[] = [];

          snapshot.forEach((doc) => {
            const data = doc.data();
            requirements.push({
              id: doc.id,
              serviceId: data.serviceId,
              documentName: data.documentName || '',
              required: data.required ?? true,
              order: data.order || 0,
              createdAt: data.createdAt || null,
            });
          });

          callback(requirements);
        },
        (error: any) => {
          // Check if this is a composite index error
          if (error.message && error.message.includes('index')) {
            console.warn('⚠️ Composite index not ready, using client-side sorting');
            
            // Fallback to unordered query and sort on client
            const fallbackQ = query(
              collection(firestore, 'document_requirements'),
              where('serviceId', '==', serviceId),
              where('isActive', '==', true)
            );
            
            onSnapshot(
              fallbackQ,
              (snapshot) => {
                const requirements: DocumentRequirement[] = [];

                snapshot.forEach((doc) => {
                  const data = doc.data();
                  requirements.push({
                    id: doc.id,
                    serviceId: data.serviceId,
                    documentName: data.documentName || '',
                    required: data.required ?? true,
                    order: data.order || 0,
                    createdAt: data.createdAt || null,
                  });
                });

                // Client-side sorting by order
                requirements.sort((a, b) => (a.order || 0) - (b.order || 0));
                callback(requirements);
              },
              (fallbackError) => {
                console.error('❌ Error listening to document requirements (fallback):', fallbackError);
                if (onError) onError(fallbackError as Error);
              }
            );
          } else {
            console.error('❌ Error listening to document requirements:', error);
            if (onError) onError(error as Error);
          }
        }
      );
    } catch (error) {
      console.error('❌ Error subscribing to document requirements:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },

  // Subscribe to all document requirements across all services
  subscribeToAllDocumentRequirements: (
    callback: (requirements: Array<DocumentRequirement & { serviceName: string; categoryName: string }>) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      const q = query(collection(firestore, 'document_requirements'), orderBy('order', 'asc'));

      // Build lookup maps
      const servicesMap = new Map<string, { name: string; categoryId: string }>();
      const categoriesMap = new Map<string, string>();

      let unsubscribeServices: (() => void) | null = null;
      let unsubscribeCategories: (() => void) | null = null;

      // Load services first
      unsubscribeServices = serviceManagementService.subscribeToAllServices(
        (services) => {
          services.forEach((svc) => {
            servicesMap.set(svc.id, {
              name: svc.name,
              categoryId: svc.categoryId,
            });
            categoriesMap.set(svc.categoryId, svc.categoryName);
          });
        },
        (error) => {
          console.error('❌ Error loading services for document requirement lookup:', error);
          if (onError) onError(error);
        }
      );

      // Then subscribe to requirements
      const unsubscribeRequirements = onSnapshot(
        q,
        (snapshot) => {
          const requirements: Array<DocumentRequirement & { serviceName: string; categoryName: string }> = [];

          snapshot.forEach((doc) => {
            const data = doc.data();
            const serviceInfo = servicesMap.get(data.serviceId);
            const serviceName = serviceInfo?.name || 'Unknown Service';
            const categoryName = serviceInfo ? categoriesMap.get(serviceInfo.categoryId) || 'Unknown Category' : 'Unknown Category';

            requirements.push({
              id: doc.id,
              serviceId: data.serviceId,
              documentName: data.documentName || '',
              required: data.required ?? true,
              order: data.order || 0,
              createdAt: data.createdAt || null,
              serviceName: serviceName,
              categoryName: categoryName,
            });
          });

          callback(requirements);
        },
        (error) => {
          console.error('❌ Error listening to all document requirements:', error);
          if (onError) onError(error as Error);
        }
      );

      // Return combined unsubscribe function
      return () => {
        unsubscribeRequirements();
        if (unsubscribeServices) unsubscribeServices();
      };
    } catch (error) {
      console.error('❌ Error subscribing to all document requirements:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },
};

// ===========================================
// DYNAMIC DOCUMENT FIELDS SERVICE
// ============================================
export const dynamicFieldsService = {
  // Save or update document fields configuration for a service
  // UPDATED: Saves to services collection as single source of truth
  saveServiceDocumentFields: async (
    serviceId: string,
    fields: Omit<DynamicField, 'fieldId'>[]
  ): Promise<void> => {
    try {
      console.log(`📝 Saving document fields for service ${serviceId}...`);
      
      // Generate unique fieldIds for new fields (no undefined values — Firestore rejects them)
      const fieldsWithIds: DynamicField[] = fields.map((field, index) => {
        const cleanField: DynamicField = {
          fieldId: `field_${Date.now()}_${index}`,
          fieldName: field.fieldName,
          fieldType: field.fieldType,
          isRequired: field.isRequired,
          placeholder: field.placeholder || '',
          displayOrder: field.displayOrder ?? index,
        };
        if (field.maxSizeKB !== undefined) {
          cleanField.maxSizeKB = field.maxSizeKB;
        }
        return cleanField;
      });

      // Transform to match the required structure: {id, name, type, required, placeholder}
      const transformedFields = fieldsWithIds.map(field => ({
        id: field.fieldId,
        name: field.fieldName,
        type: field.fieldType,
        required: field.isRequired,
        placeholder: field.placeholder || '',
      }));

      // PRIMARY: Save to services collection (single source of truth)
      const serviceRef = doc(firestore, 'services', serviceId);
      await updateDoc(serviceRef, {
        documentFields: transformedFields,
        updatedAt: serverTimestamp(),
      });

      console.log(`✅ Document fields saved to services/${serviceId}`);
      console.log(`   Fields: ${transformedFields.length}`, transformedFields);
      
      // OPTIONAL: Also save to separate collection for backwards compatibility
      const docRef = doc(firestore, 'service_document_fields', serviceId);
      await setDoc(
        docRef,
        {
          serviceId: serviceId,
          fields: fieldsWithIds,
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );

      console.log(`✅ Document fields also saved to service_document_fields/${serviceId} (backup)`);
    } catch (error) {
      console.error('❌ Error saving document fields:', error);
      throw error;
    }
  },

  // Get document fields for a service
  getServiceDocumentFields: async (serviceId: string): Promise<DynamicField[]> => {
    try {
      const docRef = doc(firestore, 'service_document_fields', serviceId);
      const docSnap = await getDoc(docRef);

      if (docSnap.exists()) {
        const data = docSnap.data();
        return data.fields || [];
      }

      return [];
    } catch (error) {
      console.error('❌ Error getting document fields:', error);
      throw error;
    }
  },

  // Subscribe to document fields for a service (real-time)
  subscribeToServiceDocumentFields: (
    serviceId: string,
    callback: (fields: DynamicField[]) => void,
    onError?: (error: Error) => void
  ) => {
    try {
      const docRef = doc(firestore, 'service_document_fields', serviceId);

      return onSnapshot(
        docRef,
        (docSnap) => {
          if (docSnap.exists()) {
            const data = docSnap.data();
            const fields = data.fields || [];
            // Sort by displayOrder
            fields.sort((a: DynamicField, b: DynamicField) => a.displayOrder - b.displayOrder);
            callback(fields);
          } else {
            callback([]);
          }
        },
        (error) => {
          console.error('❌ Error subscribing to document fields:', error);
          if (onError) onError(error as Error);
        }
      );
    } catch (error) {
      console.error('❌ Error setting up document fields subscription:', error);
      if (onError) onError(error as Error);
      return () => {};
    }
  },

  // Delete all document fields for a service
  deleteServiceDocumentFields: async (serviceId: string): Promise<void> => {
    try {
      const docRef = doc(firestore, 'service_document_fields', serviceId);
      await deleteDoc(docRef);
      console.log(`✅ Document fields deleted for service ${serviceId}`);
    } catch (error) {
      console.error('❌ Error deleting document fields:', error);
      throw error;
    }
  },
};

export { firestore };

