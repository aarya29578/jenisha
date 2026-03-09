import { useState, useEffect, useRef } from 'react';
import { Plus, Edit, Trash2, FolderTree, FileText, Briefcase, Home, Users, Settings, ShoppingCart, CreditCard, Package, Truck, Phone, Mail, Calendar, Clock, Star, Heart, Shield, Award, Gift, Zap, Activity, TrendingUp, DollarSign, File, Folder, Database, Server, Globe, Cloud, Key, Lock, Download, FileDown, X } from 'lucide-react';
import { categoryService, serviceManagementService, ServiceCategory, Service } from '../../../services/categoryService';

// Icon options for category selection
const iconOptions = [
  { name: 'FolderTree', icon: FolderTree, label: 'Folder Tree' },
  { name: 'FileText', icon: FileText, label: 'Document' },
  { name: 'Briefcase', icon: Briefcase, label: 'Briefcase' },
  { name: 'Home', icon: Home, label: 'Home' },
  { name: 'Users', icon: Users, label: 'Users' },
  { name: 'Settings', icon: Settings, label: 'Settings' },
  { name: 'ShoppingCart', icon: ShoppingCart, label: 'Shopping' },
  { name: 'CreditCard', icon: CreditCard, label: 'Payment' },
  { name: 'Package', icon: Package, label: 'Package' },
  { name: 'Truck', icon: Truck, label: 'Delivery' },
  { name: 'Phone', icon: Phone, label: 'Phone' },
  { name: 'Mail', icon: Mail, label: 'Mail' },
  { name: 'Calendar', icon: Calendar, label: 'Calendar' },
  { name: 'Clock', icon: Clock, label: 'Time' },
  { name: 'Star', icon: Star, label: 'Star' },
  { name: 'Heart', icon: Heart, label: 'Favorite' },
  { name: 'Shield', icon: Shield, label: 'Security' },
  { name: 'Award', icon: Award, label: 'Award' },
  { name: 'Gift', icon: Gift, label: 'Gift' },
  { name: 'Zap', icon: Zap, label: 'Fast' },
  { name: 'Activity', icon: Activity, label: 'Activity' },
  { name: 'TrendingUp', icon: TrendingUp, label: 'Growth' },
  { name: 'DollarSign', icon: DollarSign, label: 'Money' },
  { name: 'File', icon: File, label: 'File' },
  { name: 'Folder', icon: Folder, label: 'Folder' },
  { name: 'Database', icon: Database, label: 'Database' },
  { name: 'Server', icon: Server, label: 'Server' },
  { name: 'Globe', icon: Globe, label: 'Global' },
  { name: 'Cloud', icon: Cloud, label: 'Cloud' },
  { name: 'Key', icon: Key, label: 'Key' },
  { name: 'Lock', icon: Lock, label: 'Lock' },
];

// Helper to get icon component by name
const getIconByName = (iconName?: string) => {
  const iconOption = iconOptions.find(opt => opt.name === iconName);
  return iconOption ? iconOption.icon : FolderTree;
};

export default function ServiceManagement() {
  const [activeTab, setActiveTab] = useState<'categories' | 'services'>('categories');
  const [categories, setCategories] = useState<ServiceCategory[]>([]);
  const [services, setServices] = useState<(Service & { categoryId: string; categoryName: string })[]>([]);
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [showAddService, setShowAddService] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState('');
  const [newServiceData, setNewServiceData] = useState({ name: '', categoryId: '', price: 0, redirectUrl: '' });
  const [loading, setLoading] = useState(true);
  const [selectedCategoryForService, setSelectedCategoryForService] = useState('');
  
  // Edit states
  const [showEditCategory, setShowEditCategory] = useState(false);
  const [editCategoryData, setEditCategoryData] = useState<{ id: string; name: string; icon?: string; customLogoUrl?: string } | null>(null);
  const [showEditService, setShowEditService] = useState(false);
  const [editServiceData, setEditServiceData] = useState<{ id: string; name: string; categoryId: string; price: number; logoUrl: string; redirectUrl: string; formTemplateUrl: string } | null>(null);
  
  // Icon picker states
  const [selectedIcon, setSelectedIcon] = useState('FolderTree');
  const [showIconPicker, setShowIconPicker] = useState(false);
  
  // Custom logo upload states (categories)
  const [customLogoFile, setCustomLogoFile] = useState<File | null>(null);
  const [customLogoPreview, setCustomLogoPreview] = useState<string | null>(null);
  const [uploadingLogo, setUploadingLogo] = useState(false);
  
  // Edit category logo states
  const [editLogoFile, setEditLogoFile] = useState<File | null>(null);
  const [editLogoPreview, setEditLogoPreview] = useState<string | null>(null);

  // ── Service logo upload states (add form) ────────────────────────────────
  const [newServiceLogoFile, setNewServiceLogoFile]       = useState<File | null>(null);
  const [newServiceLogoPreview, setNewServiceLogoPreview] = useState<string | null>(null);
  const [uploadingServiceLogo, setUploadingServiceLogo]   = useState(false);
  const newServiceLogoInputRef = useRef<HTMLInputElement>(null);

  // ── Service logo upload states (edit form) ───────────────────────────────
  const [editServiceLogoFile, setEditServiceLogoFile]       = useState<File | null>(null);
  const [editServiceLogoPreview, setEditServiceLogoPreview] = useState<string | null>(null);
  const [uploadingEditServiceLogo, setUploadingEditServiceLogo] = useState(false);
  const editServiceLogoInputRef = useRef<HTMLInputElement>(null);

  // ── Form template upload states (add form) ────────────────────────────────
  const [newFormTemplateFile, setNewFormTemplateFile]   = useState<File | null>(null);
  const [uploadingNewFormTemplate, setUploadingNewFormTemplate] = useState(false);
  const newFormTemplateInputRef = useRef<HTMLInputElement>(null);

  // ── Form template upload states (edit form) ───────────────────────────────
  const [editFormTemplateFile, setEditFormTemplateFile]   = useState<File | null>(null);
  const [uploadingEditFormTemplate, setUploadingEditFormTemplate] = useState(false);
  const editFormTemplateInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setLoading(true);
    const unsubscribe = categoryService.subscribeToCategories(
      (cats) => {
        // Filter to show only active categories
        setCategories(cats.filter(cat => cat.isActive));
        setLoading(false);
      },
      (error) => {
        console.error('Error:', error);
        setLoading(false);
      }
    );
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    const unsubscribe = serviceManagementService.subscribeToAllServices(
      (svcs) => {
        // Filter to show only active services
        setServices(svcs.filter(svc => svc.isActive));
      },
      (error) => {
        console.error('Error:', error);
      }
    );
    return () => unsubscribe();
  }, []);

  const handleAddCategory = async () => {
    if (newCategoryName.trim()) {
      try {
        // Create category first
        const categoryId = await categoryService.addCategory(newCategoryName, selectedIcon);
        
        // Upload logo if file is selected
        if (customLogoFile) {
          setUploadingLogo(true);
          try {
            await categoryService.uploadCategoryLogo(categoryId, customLogoFile);
          } catch (logoError) {
            console.error('Logo upload failed, but category was created:', logoError);
            // Don't throw - category creation succeeded
          } finally {
            setUploadingLogo(false);
          }
        }
        
        // Reset form
        setNewCategoryName('');
        setSelectedIcon('FolderTree');
        setCustomLogoFile(null);
        setCustomLogoPreview(null);
        setShowAddCategory(false);
      } catch (error) {
        console.error('Error adding category:', error);
      }
    }
  };

  const handleLogoFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
      alert('Invalid file type. Only PNG, JPG, JPEG, and WEBP are allowed.');
      return;
    }
    setCustomLogoFile(file);
    const reader = new FileReader();
    reader.onloadend = () => setCustomLogoPreview(reader.result as string);
    reader.readAsDataURL(file);
  };

  const handleRemoveLogo = () => {
    setCustomLogoFile(null);
    setCustomLogoPreview(null);
  };

  const handleEditLogoFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
      alert('Invalid file type. Only PNG, JPG, JPEG, and WEBP are allowed.');
      return;
    }
    setEditLogoFile(file);
    const reader = new FileReader();
    reader.onloadend = () => setEditLogoPreview(reader.result as string);
    reader.readAsDataURL(file);
  };

  const handleRemoveEditLogo = async () => {
    if (editCategoryData?.customLogoUrl) {
      try {
        await categoryService.deleteCategoryLogo(editCategoryData.id, editCategoryData.customLogoUrl);
        setEditCategoryData({ ...editCategoryData, customLogoUrl: '' });
      } catch (error) {
        console.error('Error removing logo:', error);
      }
    }
    setEditLogoFile(null);
    setEditLogoPreview(null);
  };

  const handleEditCategory = async () => {
    if (editCategoryData && editCategoryData.name.trim()) {
      try {
        // Update category name and icon
        await categoryService.updateCategory(editCategoryData.id, {
          name: editCategoryData.name,
          icon: editCategoryData.icon
        });
        
        // Handle logo upload/update if new file selected
        if (editLogoFile) {
          setUploadingLogo(true);
          try {
            await categoryService.uploadCategoryLogo(editCategoryData.id, editLogoFile);
          } catch (logoError) {
            console.error('Logo upload failed:', logoError);
          } finally {
            setUploadingLogo(false);
          }
        }
        
        // Reset edit state
        setEditCategoryData(null);
        setEditLogoFile(null);
        setEditLogoPreview(null);
        setShowEditCategory(false);
      } catch (error) {
        console.error('Error updating category:', error);
      }
    }
  };

  const handleEditService = async () => {
    if (editServiceData && editServiceData.name.trim()) {
      try {
        setUploadingEditServiceLogo(true);
        setUploadingEditFormTemplate(true);
        let logoUrl = editServiceData.logoUrl || '';
        let formTemplateUrl = editServiceData.formTemplateUrl || '';

        // Upload new logo if one was selected
        if (editServiceLogoFile) {
          // Optionally delete old logo from Hostinger before replacing
          if (logoUrl) {
            await serviceManagementService.deleteServiceLogoFile(logoUrl);
          }
          logoUrl = await serviceManagementService.uploadServiceLogo(editServiceLogoFile);
        }

        // Upload new form template if one was selected
        if (editFormTemplateFile) {
          formTemplateUrl = await serviceManagementService.uploadFormTemplate(editFormTemplateFile);
        }

        await serviceManagementService.updateService(editServiceData.id, {
          name           : editServiceData.name,
          categoryId     : editServiceData.categoryId,
          price          : editServiceData.price,
          logoUrl,
          redirectUrl    : editServiceData.redirectUrl || '',
          formTemplateUrl: formTemplateUrl,
        });
        // reset
        setEditServiceData(null);
        setEditServiceLogoFile(null);
        setEditServiceLogoPreview(null);
        setEditFormTemplateFile(null);
        if (editFormTemplateInputRef.current) editFormTemplateInputRef.current.value = '';
        setShowEditService(false);
      } catch (error) {
        console.error('Error updating service:', error);
        alert('Failed to update service. Please try again.');
      } finally {
        setUploadingEditServiceLogo(false);
        setUploadingEditFormTemplate(false);
      }
    }
  };

  const handleServiceLogoFileChange = (e: React.ChangeEvent<HTMLInputElement>, mode: 'add' | 'edit') => {
    const file = e.target.files?.[0];
    if (!file) return;
    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
      alert('Invalid file type. Only PNG, JPG, JPEG, GIF, WEBP are allowed.');
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      alert('File size must be less than 5 MB.');
      return;
    }
    const reader = new FileReader();
    reader.onloadend = () => {
      if (mode === 'add') {
        setNewServiceLogoFile(file);
        setNewServiceLogoPreview(reader.result as string);
      } else {
        setEditServiceLogoFile(file);
        setEditServiceLogoPreview(reader.result as string);
      }
    };
    reader.readAsDataURL(file);
  };

  const handleAddService = async () => {
    if (!newServiceData.name.trim()) {
      alert('Please enter a service name.');
      return;
    }
    if (!selectedCategoryForService) {
      alert('Please select a category.');
      return;
    }
    try {
      setUploadingServiceLogo(true);
      setUploadingNewFormTemplate(true);
      const logoUrl = newServiceLogoFile
        ? await serviceManagementService.uploadServiceLogo(newServiceLogoFile)
        : '';
      const formTemplateUrl = newFormTemplateFile
        ? await serviceManagementService.uploadFormTemplate(newFormTemplateFile)
        : '';
      await serviceManagementService.addService(
        selectedCategoryForService,
        newServiceData.name,
        newServiceData.price || undefined,
        logoUrl,
        newServiceData.redirectUrl || undefined,
        formTemplateUrl || undefined,
      );
      // reset
      setNewServiceData({ name: '', categoryId: '', price: 0, redirectUrl: '' });
      setSelectedCategoryForService('');
      setNewServiceLogoFile(null);
      setNewServiceLogoPreview(null);
      if (newServiceLogoInputRef.current) newServiceLogoInputRef.current.value = '';
      setNewFormTemplateFile(null);
      if (newFormTemplateInputRef.current) newFormTemplateInputRef.current.value = '';
      setShowAddService(false);
    } catch (error) {
      console.error('Error adding service:', error);
      alert('Failed to add service. Please try again.');
    } finally {
      setUploadingServiceLogo(false);
      setUploadingNewFormTemplate(false);
    }
  };

  const handleDeleteCategory = async (categoryId: string) => {
    if (confirm('Are you sure you want to delete this category?')) {
      try {
        await categoryService.deleteCategory(categoryId);
      } catch (error) {
        console.error('Error deleting category:', error);
      }
    }
  };

  const handleDeleteService = async (serviceId: string, logoUrl?: string) => {
    if (confirm('Are you sure you want to delete this service?')) {
      try {
        await serviceManagementService.deleteService(serviceId);
        // Delete physical logo file from Hostinger
        if (logoUrl) {
          await serviceManagementService.deleteServiceLogoFile(logoUrl);
        }
      } catch (error) {
        console.error('Error deleting service:', error);
      }
    }
  };

  const getServiceCountForCategory = (categoryId: string) => {
    return services.filter((s) => s.categoryId === categoryId).length;
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl text-gray-100 mb-2">Service & Category Management</h1>
        <p className="text-gray-400">Manage service categories and individual services</p>
      </div>

      {/* Info Box */}
      <div className="bg-[#071018] border border-[#111318] rounded p-4">
        <div className="flex items-start gap-3">
          <FolderTree className="w-5 h-5 text-[#243BFF] flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-sm text-gray-100 mb-1">Connection to Agent App</h3>
            <p className="text-sm text-gray-400">
              Categories and services created here appear dynamically in the Agent Mobile App. Agents can only offer services that are marked as active.
            </p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b border-[#111318]">
        <div className="flex gap-1">
          <button
            onClick={() => setActiveTab('categories')}
            className={`
              px-6 py-3 text-sm transition-colors border-b-2 -mb-0.5
              ${activeTab === 'categories'
                ? 'border-[#243BFF] text-[#243BFF]'
                : 'border-transparent text-gray-400 hover:text-gray-100'
              }
            `}
          >
            Categories
          </button>
          <button
            onClick={() => setActiveTab('services')}
            className={`
              px-6 py-3 text-sm transition-colors border-b-2 -mb-0.5
              ${activeTab === 'services'
                ? 'border-[#243BFF] text-[#243BFF]'
                : 'border-transparent text-gray-400 hover:text-gray-100'
              }
            `}
          >
            Services
          </button>
        </div>
      </div>

      {loading && activeTab === 'categories' && (
        <div className="text-center py-8">
          <div className="inline-block">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#4C4CFF]"></div>
          </div>
        </div>
      )}

      {/* Categories Tab */}
      {activeTab === 'categories' && !loading && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button
              onClick={() => setShowAddCategory(true)}
              className="flex items-center gap-2 px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors"
            >
              <Plus className="w-4 h-4" />
              <span className="text-sm">Add Category</span>
            </button>
          </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {categories.map((category) => {
              const IconComponent = getIconByName(category.icon);
              return (
                <div key={category.id} className="bg-[#071018] border border-[#111318] rounded p-5">
                  <div className="flex items-start justify-between mb-3">
                    <div className="flex items-center gap-2">
                      {category.customLogoUrl ? (
                        <img
                          src={category.customLogoUrl}
                          alt={category.name}
                          className="w-8 h-8 object-contain"
                        />
                      ) : (
                        <IconComponent className="w-5 h-5 text-[#243BFF]" />
                      )}
                      <h3 className="text-base text-gray-100">{category.name}</h3>
                    </div>
                    <div className="flex gap-1">
                      <button 
                        onClick={() => {
                          setEditCategoryData({ id: category.id, name: category.name, icon: category.icon, customLogoUrl: category.customLogoUrl });
                          setShowEditCategory(true);
                        }}
                        className="p-1.5 text-[#243BFF] hover:bg-[#0f243b] rounded transition-colors"
                      >
                        <Edit className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDeleteCategory(category.id)}
                        className="p-1.5 text-[#F44336] hover:bg-[#2a0b0b] rounded transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  <p className="text-sm text-gray-400">
                    {getServiceCountForCategory(category.id)} services
                  </p>
                  <div className="mt-3">
                    <span
                      className={`inline-block px-2 py-1 text-xs rounded ${
                        category.isActive
                          ? 'bg-[#08310b] text-white'
                          : 'bg-[#0f1518] text-gray-400'
                      }`}
                    >
                      {category.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>

          {categories.length === 0 && (
            <div className="text-center py-8 bg-[#071018] border border-[#111318] rounded">
              <p className="text-gray-400">No categories yet. Create one to get started!</p>
            </div>
          )}

          {showAddCategory && (
            <div className="bg-[#071018] border border-[#111318] rounded p-5">
              <h3 className="text-base text-gray-100 mb-4">Add New Category</h3>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-100 mb-2">Category Name</label>
                  <input
                    type="text"
                    value={newCategoryName}
                    onChange={(e) => setNewCategoryName(e.target.value)}
                    className="w-full px-4 py-2 border border-[#111318] rounded bg-[#071018] text-gray-100 focus:outline-none focus:border-[#243BFF]"
                    placeholder="Enter category name"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-100 mb-2">Select Icon</label>
                  <div className="grid grid-cols-6 md:grid-cols-8 gap-2">
                    {iconOptions.map((option) => {
                      const Icon = option.icon;
                      return (
                        <button
                          key={option.name}
                          type="button"
                          onClick={() => setSelectedIcon(option.name)}
                          className={`p-3 border rounded hover:border-[#243BFF] transition-colors ${
                            selectedIcon === option.name
                              ? 'border-[#243BFF] bg-[#0f243b]'
                              : 'border border-[#111318]'
                          }`}
                          title={option.label}
                        >
                          <Icon className="w-5 h-5 text-gray-400" />
                        </button>
                      );
                    })}
                  </div>
                </div>
                
                {/* Custom Logo Upload Section */}
                <div>
                  <label className="block text-sm text-gray-100 mb-2">
                    Upload Custom Logo (Optional)
                  </label>
                  <p className="text-xs text-gray-400 mb-3">
                    If uploaded, custom logo will be displayed instead of the icon
                  </p>
                  
                  {!customLogoPreview ? (
                    <div>
                      <input
                        type="file"
                        accept="image/png,image/jpeg,image/jpg"
                        onChange={handleLogoFileChange}
                        className="hidden"
                        id="logo-upload"
                      />
                      <label
                        htmlFor="logo-upload"
                        className="inline-flex items-center gap-2 px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] cursor-pointer transition-colors"
                      >
                        <Plus className="w-4 h-4" />
                        <span className="text-sm">Choose Image</span>
                      </label>
                      <div className="mt-2 p-3 bg-[#0f1518] border border-[#1a2030] rounded-lg text-xs text-gray-400 leading-relaxed">
                        <p className="font-semibold text-gray-300 mb-1">Image Upload Guidelines</p>
                        <ul className="list-disc list-inside space-y-0.5">
                          <li>Recommended size: <span className="text-gray-200">600 × 600 pixels</span> (square)</li>
                          <li>Maximum file size: <span className="text-gray-200">400 KB</span></li>
                          <li>Allowed formats: PNG, JPG, JPEG, WEBP</li>
                          <li>Subject should fill most of the image</li>
                          <li>Avoid large white margins or transparent padding</li>
                          <li>Keep the subject centered</li>
                        </ul>
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-start gap-3">
                      <div className="relative">
                        <img
                          src={customLogoPreview}
                          alt="Logo preview"
                          className="w-24 h-24 object-contain border border-[#111318] rounded bg-[#0f1518] p-2"
                        />
                      </div>
                      <div className="flex flex-col gap-2">
                        <p className="text-sm text-gray-300">{customLogoFile?.name}</p>
                        <button
                          type="button"
                          onClick={handleRemoveLogo}
                          className="text-xs text-red-400 hover:text-red-300 transition-colors text-left"
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  )}
                </div>
                
                <div className="flex gap-2">
                  <button
                    onClick={handleAddCategory}
                    disabled={uploadingLogo}
                    className="px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {uploadingLogo ? 'Uploading Logo...' : 'Save Category'}
                  </button>
                  <button
                    onClick={() => {
                      setShowAddCategory(false);
                      setNewCategoryName('');
                      setSelectedIcon('FolderTree');
                      setCustomLogoFile(null);
                      setCustomLogoPreview(null);
                    }}
                    className="px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          )}
          
          {showEditCategory && editCategoryData && (
            <div className="bg-[#071018] border border-[#111318] rounded p-5">
              <h3 className="text-base text-gray-100 mb-4">Edit Category</h3>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-100 mb-2">Category Name</label>
                  <input
                    type="text"
                    value={editCategoryData.name}
                    onChange={(e) => setEditCategoryData({ ...editCategoryData, name: e.target.value })}
                    className="w-full px-4 py-2 border border-[#111318] rounded bg-[#071018] text-gray-100 focus:outline-none focus:border-[#243BFF]"
                    placeholder="Enter category name"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-100 mb-2">Select Icon</label>
                  <div className="grid grid-cols-6 md:grid-cols-8 gap-2">
                    {iconOptions.map((option) => {
                      const Icon = option.icon;
                      return (
                        <button
                          key={option.name}
                          type="button"
                          onClick={() => setEditCategoryData({ ...editCategoryData, icon: option.name })}
                          className={`p-3 border rounded hover:border-[#243BFF] transition-colors ${
                            editCategoryData.icon === option.name
                              ? 'border-[#243BFF] bg-[#0f243b]'
                              : 'border border-[#111318]'
                          }`}
                          title={option.label}
                        >
                          <Icon className="w-5 h-5 text-gray-400" />
                        </button>
                      );
                    })}
                  </div>
                </div>
                
                {/* Custom Logo Management Section */}
                <div>
                  <label className="block text-sm text-gray-100 mb-2">
                    Custom Logo (Optional)
                  </label>
                  
                  {/* Show existing logo if present and no new file selected */}
                  {editCategoryData.customLogoUrl && !editLogoPreview ? (
                    <div className="flex items-start gap-3 mb-3">
                      <div className="relative">
                        <img
                          src={editCategoryData.customLogoUrl}
                          alt="Current logo"
                          className="w-24 h-24 object-contain border border-[#111318] rounded bg-[#0f1518] p-2"
                        />
                      </div>
                      <div className="flex flex-col gap-2">
                        <p className="text-sm text-gray-300">Current logo</p>
                        <button
                          type="button"
                          onClick={handleRemoveEditLogo}
                          className="text-xs text-red-400 hover:text-red-300 transition-colors text-left"
                        >
                          Remove Logo
                        </button>
                      </div>
                    </div>
                  ) : null}
                  
                  {/* Show new logo preview */}
                  {editLogoPreview ? (
                    <div className="flex items-start gap-3 mb-3">
                      <div className="relative">
                        <img
                          src={editLogoPreview}
                          alt="New logo preview"
                          className="w-24 h-24 object-contain border border-[#111318] rounded bg-[#0f1518] p-2"
                        />
                      </div>
                      <div className="flex flex-col gap-2">
                        <p className="text-sm text-gray-300">{editLogoFile?.name}</p>
                        <button
                          type="button"
                          onClick={() => {
                            setEditLogoFile(null);
                            setEditLogoPreview(null);
                          }}
                          className="text-xs text-red-400 hover:text-red-300 transition-colors text-left"
                        >
                          Cancel Upload
                        </button>
                      </div>
                    </div>
                  ) : null}
                  
                  {/* Upload button */}
                  {!editLogoPreview && (
                    <div>
                      <input
                        type="file"
                        accept="image/png,image/jpeg,image/jpg"
                        onChange={handleEditLogoFileChange}
                        className="hidden"
                        id="edit-logo-upload"
                      />
                      <label
                        htmlFor="edit-logo-upload"
                        className="inline-flex items-center gap-2 px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] cursor-pointer transition-colors"
                      >
                        <Plus className="w-4 h-4" />
                        <span className="text-sm">
                          {editCategoryData.customLogoUrl ? 'Replace Logo' : 'Upload Logo'}
                        </span>
                      </label>
                      <div className="mt-2 p-3 bg-[#0f1518] border border-[#1a2030] rounded-lg text-xs text-gray-400 leading-relaxed">
                        <p className="font-semibold text-gray-300 mb-1">Image Upload Guidelines</p>
                        <ul className="list-disc list-inside space-y-0.5">
                          <li>Recommended size: <span className="text-gray-200">600 × 600 pixels</span> (square)</li>
                          <li>Maximum file size: <span className="text-gray-200">400 KB</span></li>
                          <li>Allowed formats: PNG, JPG, JPEG, WEBP</li>
                          <li>Subject should fill most of the image</li>
                          <li>Avoid large white margins or transparent padding</li>
                          <li>Keep the subject centered</li>
                        </ul>
                      </div>
                    </div>
                  )}
                </div>
                
                <div className="flex gap-2">
                  <button
                    onClick={handleEditCategory}
                    disabled={uploadingLogo}
                    className="px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {uploadingLogo ? 'Uploading Logo...' : 'Update Category'}
                  </button>
                  <button
                    onClick={() => {
                      setShowEditCategory(false);
                      setEditCategoryData(null);
                      setEditLogoFile(null);
                      setEditLogoPreview(null);
                    }}
                    className="px-4 py-2 border border-[#111318] text-gray-400 rounded hover:bg-[#0f1518] transition-colors"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Services Tab */}
      {activeTab === 'services' && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <button
              onClick={() => setShowAddService(true)}
              className="flex items-center gap-2 px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors"
            >
              <Plus className="w-4 h-4" />
              <span className="text-sm">Add Service</span>
            </button>
          </div>

          {services.length === 0 ? (
            <div className="text-center py-8 bg-white border-2 border-[#e5e5e5] rounded">
              <p className="text-[#666666]">No services yet. Create a category and add services to it!</p>
            </div>
          ) : (
            <div className="bg-white border-2 border-[#e5e5e5] rounded overflow-hidden">
              <table className="w-full">
                <thead className="bg-[#f5f5f5] border-b-2 border-[#e5e5e5]">
                  <tr>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Logo</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Service Name</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Category</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Service Fee</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Redirect URL</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Form Template</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Status</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y-2 divide-[#e5e5e5]">
                  {services.map((service) => (
                    <tr key={service.id} className="hover:bg-[#fafafa] transition-colors">
                      <td className="px-5 py-4">
                        {service.logoUrl ? (
                          <img
                            src={service.logoUrl}
                            alt={service.name}
                            className="w-10 h-10 rounded-full object-cover border border-[#e5e5e5]"
                            onError={(e) => { (e.target as HTMLImageElement).src = ''; }}
                          />
                        ) : (
                          <div className="w-10 h-10 rounded-full bg-[#E8E8FF] flex items-center justify-center">
                            <FileText className="w-5 h-5 text-[#4C4CFF]" />
                          </div>
                        )}
                      </td>
                      <td className="px-5 py-4 text-sm text-[#1a1a1a]">{service.name}</td>
                      <td className="px-5 py-4 text-sm text-[#666666]">{service.categoryName}</td>
                      <td className="px-5 py-4 text-sm text-[#1a1a1a]">
                        {service.price ? `₹${service.price}` : '-'}
                      </td>
                      <td className="px-5 py-4">
                        {(service as any).redirectUrl ? (
                          <a
                            href={(service as any).redirectUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1 text-xs text-[#4C4CFF] hover:underline"
                            title={(service as any).redirectUrl}
                          >
                            <Globe className="w-3 h-3" />
                            <span className="max-w-[140px] truncate block">{(service as any).redirectUrl}</span>
                          </a>
                        ) : (
                          <span className="text-xs text-[#999]">-</span>
                        )}
                      </td>
                      {/* Form Template column */}
                      <td className="px-5 py-4">
                        {(service as any).formTemplateUrl ? (
                          <a
                            href={(service as any).formTemplateUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            title="View / Download template"
                            className="inline-flex items-center gap-1 px-2 py-1 text-xs bg-[#E8E8FF] text-[#4C4CFF] rounded hover:bg-[#d8d8ff] transition-colors"
                          >
                            <FileDown className="w-3 h-3" />
                            Template
                          </a>
                        ) : (
                          <span className="text-xs text-[#999]">None</span>
                        )}
                      </td>
                      <td className="px-5 py-4">
                        <span
                          className={`inline-block px-3 py-1 text-xs rounded ${
                            service.isActive
                              ? 'bg-[#E8F5E9] text-[#4CAF50]'
                              : 'bg-[#F5F5F5] text-[#666666]'
                          }`}
                        >
                          {service.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                      <td className="px-5 py-4">
                        <div className="flex gap-2">
                          <button 
                            onClick={() => {
                              setEditServiceData({
                                id              : service.id,
                                name            : service.name,
                                categoryId      : service.categoryId,
                                price           : service.price || 0,
                                logoUrl         : service.logoUrl || '',
                                redirectUrl     : (service as any).redirectUrl || '',
                                formTemplateUrl : (service as any).formTemplateUrl || '',
                              });
                              setShowEditService(true);
                            }}
                            className="p-2 text-[#4C4CFF] hover:bg-[#E8E8FF] rounded transition-colors"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() =>
                              handleDeleteService(service.id, service.logoUrl)
                            }
                            className="p-2 text-[#F44336] hover:bg-[#FFEBEE] rounded transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {showAddService && (
            <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
              <h3 className="text-base text-[#1a1a1a] mb-4">Add New Service</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-[#1a1a1a] mb-2">Service Name</label>
                  <input
                    type="text"
                    value={newServiceData.name}
                    onChange={(e) =>
                      setNewServiceData({ ...newServiceData, name: e.target.value })
                    }
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                    placeholder="Enter service name"
                  />
                </div>
                <div>
                  <label className="block text-sm text-[#1a1a1a] mb-2">Category</label>
                  <select
                    value={selectedCategoryForService}
                    onChange={(e) => setSelectedCategoryForService(e.target.value)}
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                  >
                    <option value="">Select category</option>
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-[#1a1a1a] mb-2">Service Fee (₹)</label>
                  <input
                    type="number"
                    value={newServiceData.price}
                    onChange={(e) =>
                      setNewServiceData({
                        ...newServiceData,
                        price: parseInt(e.target.value) || 0,
                      })
                    }
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                    placeholder="Enter fee amount"
                  />
                </div>
                {/* Redirect URL */}
                <div className="md:col-span-2">
                  <label className="block text-sm text-[#1a1a1a] mb-2">Redirect URL <span className="text-[#999] text-xs">(optional — if set, tapping the service opens this URL)</span></label>
                  <input
                    type="url"
                    value={newServiceData.redirectUrl}
                    onChange={(e) => setNewServiceData({ ...newServiceData, redirectUrl: e.target.value })}
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                    placeholder="https://example.com/service-page"
                  />
                </div>
                {/* Service Logo Upload */}
                <div>
                  <label className="block text-sm text-[#1a1a1a] mb-2">
                    Service Logo
                  </label>
                  {newServiceLogoPreview ? (
                    <div className="flex items-center gap-3">
                      <img
                        src={newServiceLogoPreview}
                        alt="Logo preview"
                        className="w-16 h-16 rounded-full object-cover border-2 border-[#e5e5e5]"
                      />
                      <div>
                        <p className="text-xs text-[#666] mb-1">{newServiceLogoFile?.name}</p>
                        <button
                          type="button"
                          onClick={() => {
                            setNewServiceLogoFile(null);
                            setNewServiceLogoPreview(null);
                            if (newServiceLogoInputRef.current) newServiceLogoInputRef.current.value = '';
                          }}
                          className="text-xs text-red-500 hover:text-red-400"
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div>
                      <input
                        ref={newServiceLogoInputRef}
                        type="file"
                        accept="image/*"
                        id="new-service-logo"
                        className="hidden"
                        onChange={(e) => handleServiceLogoFileChange(e, 'add')}
                      />
                      <label
                        htmlFor="new-service-logo"
                        className="inline-flex items-center gap-2 px-4 py-2 border-2 border-dashed border-[#4C4CFF] text-[#4C4CFF] rounded cursor-pointer hover:bg-[#f0f0ff] transition-colors"
                      >
                        <Plus className="w-4 h-4" />
                        <span className="text-sm">Choose Logo Image</span>
                      </label>
                      <div className="mt-2 p-3 bg-[#f5f5f5] border border-[#e0e0e0] rounded-lg text-xs text-[#555] leading-relaxed">
                        <p className="font-semibold text-[#333] mb-1">Image Upload Guidelines</p>
                        <ul className="list-disc list-inside space-y-0.5">
                          <li>Recommended size: <span className="font-medium">600 × 600 pixels</span> (square)</li>
                          <li>Maximum file size: <span className="font-medium">400 KB</span></li>
                          <li>Allowed formats: PNG, JPG, JPEG, WEBP</li>
                          <li>Subject should fill most of the image</li>
                          <li>Avoid large white margins or transparent padding</li>
                          <li>Keep the subject centered</li>
                        </ul>
                      </div>
                    </div>
                  )}
                </div>
                {/* Form Template Upload */}
                <div className="md:col-span-2">
                  <label className="block text-sm text-[#1a1a1a] mb-2">
                    Form Template <span className="text-[#999] text-xs">(optional — PDF/DOC users can download before filling)</span>
                  </label>
                  {newFormTemplateFile ? (
                    <div className="flex items-center gap-3 p-3 bg-[#f0f0ff] border-2 border-[#4C4CFF] rounded">
                      <FileDown className="w-5 h-5 text-[#4C4CFF] flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm text-[#1a1a1a] truncate">{newFormTemplateFile.name}</p>
                        <p className="text-xs text-[#666]">{(newFormTemplateFile.size / 1024).toFixed(1)} KB</p>
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          setNewFormTemplateFile(null);
                          if (newFormTemplateInputRef.current) newFormTemplateInputRef.current.value = '';
                        }}
                        className="p-1 text-red-500 hover:text-red-400"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  ) : (
                    <div>
                      <input
                        ref={newFormTemplateInputRef}
                        type="file"
                        accept=".pdf,.doc,.docx"
                        id="new-form-template"
                        className="hidden"
                        onChange={(e) => {
                          const f = e.target.files?.[0];
                          if (f) setNewFormTemplateFile(f);
                        }}
                      />
                      <label
                        htmlFor="new-form-template"
                        className="inline-flex items-center gap-2 px-4 py-2 border-2 border-dashed border-[#4C4CFF] text-[#4C4CFF] rounded cursor-pointer hover:bg-[#f0f0ff] transition-colors"
                      >
                        <Plus className="w-4 h-4" />
                        <span className="text-sm">Upload Form Template</span>
                      </label>
                      <p className="text-xs text-[#999] mt-1">PDF, DOC, DOCX — Max 20 MB</p>
                    </div>
                  )}
                </div>
              </div>
              <div className="flex gap-2 mt-4">
                <button
                  onClick={handleAddService}
                  disabled={uploadingServiceLogo || uploadingNewFormTemplate}
                  className="px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {(uploadingServiceLogo || uploadingNewFormTemplate) ? (
                    <span className="flex items-center gap-2">
                      <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Uploading…
                    </span>
                  ) : 'Save Service'}
                </button>
                <button
                  onClick={() => {
                    setShowAddService(false);
                    setNewServiceData({ name: '', categoryId: '', price: 0, redirectUrl: '' });
                    setSelectedCategoryForService('');
                    setNewServiceLogoFile(null);
                    setNewServiceLogoPreview(null);
                    if (newServiceLogoInputRef.current) newServiceLogoInputRef.current.value = '';
                    setNewFormTemplateFile(null);
                    if (newFormTemplateInputRef.current) newFormTemplateInputRef.current.value = '';
                  }}
                  className="px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
          
          {showEditService && editServiceData && (
            <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
              <h3 className="text-base text-[#1a1a1a] mb-4">Edit Service</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-[#1a1a1a] mb-2">Service Name</label>
                  <input
                    type="text"
                    value={editServiceData.name}
                    onChange={(e) => setEditServiceData({ ...editServiceData, name: e.target.value })}
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                    placeholder="Enter service name"
                  />
                </div>
                <div>
                  <label className="block text-sm text-[#1a1a1a] mb-2">Category</label>
                  <select
                    value={editServiceData.categoryId}
                    onChange={(e) => setEditServiceData({ ...editServiceData, categoryId: e.target.value })}
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                  >
                    <option value="">Select category</option>
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm text-[#1a1a1a] mb-2">Service Fee (₹)</label>
                  <input
                    type="number"
                    value={editServiceData.price}
                    onChange={(e) => setEditServiceData({ ...editServiceData, price: parseInt(e.target.value) || 0 })}
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                    placeholder="Enter fee amount"
                  />
                </div>
                {/* Redirect URL */}
                <div className="md:col-span-2">
                  <label className="block text-sm text-[#1a1a1a] mb-2">Redirect URL <span className="text-[#999] text-xs">(optional — if set, tapping the service opens this URL)</span></label>
                  <input
                    type="url"
                    value={editServiceData?.redirectUrl || ''}
                    onChange={(e) => setEditServiceData(editServiceData ? { ...editServiceData, redirectUrl: e.target.value } : null)}
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                    placeholder="https://example.com/service-page"
                  />
                </div>
                {/* Service Logo Replace */}
                <div>
                  <label className="block text-sm text-[#1a1a1a] mb-2">Service Logo</label>

                  {/* Current logo (if no new file picked) */}
                  {editServiceData.logoUrl && !editServiceLogoPreview && (
                    <div className="flex items-center gap-3 mb-2">
                      <img
                        src={editServiceData.logoUrl}
                        alt="Current logo"
                        className="w-16 h-16 rounded-full object-cover border-2 border-[#e5e5e5]"
                      />
                      <p className="text-xs text-[#666]">Current logo</p>
                    </div>
                  )}

                  {/* Preview of new logo */}
                  {editServiceLogoPreview && (
                    <div className="flex items-center gap-3 mb-2">
                      <img
                        src={editServiceLogoPreview}
                        alt="New logo preview"
                        className="w-16 h-16 rounded-full object-cover border-2 border-[#4C4CFF]"
                      />
                      <div>
                        <p className="text-xs text-[#666] mb-1">{editServiceLogoFile?.name}</p>
                        <button
                          type="button"
                          onClick={() => {
                            setEditServiceLogoFile(null);
                            setEditServiceLogoPreview(null);
                            if (editServiceLogoInputRef.current) editServiceLogoInputRef.current.value = '';
                          }}
                          className="text-xs text-red-500 hover:text-red-400"
                        >
                          Cancel Replace
                        </button>
                      </div>
                    </div>
                  )}

                  {/* Upload / Replace button */}
                  {!editServiceLogoPreview && (
                    <div>
                      <input
                        ref={editServiceLogoInputRef}
                        type="file"
                        accept="image/*"
                        id="edit-service-logo"
                        className="hidden"
                        onChange={(e) => handleServiceLogoFileChange(e, 'edit')}
                      />
                      <label
                        htmlFor="edit-service-logo"
                        className="inline-flex items-center gap-2 px-4 py-2 border-2 border-dashed border-[#4C4CFF] text-[#4C4CFF] rounded cursor-pointer hover:bg-[#f0f0ff] transition-colors"
                      >
                        <Plus className="w-4 h-4" />
                        <span className="text-sm">
                          {editServiceData.logoUrl ? 'Replace Logo' : 'Upload Logo'}
                        </span>
                      </label>
                      <div className="mt-2 p-3 bg-[#f5f5f5] border border-[#e0e0e0] rounded-lg text-xs text-[#555] leading-relaxed">
                        <p className="font-semibold text-[#333] mb-1">Image Upload Guidelines</p>
                        <ul className="list-disc list-inside space-y-0.5">
                          <li>Recommended size: <span className="font-medium">600 × 600 pixels</span> (square)</li>
                          <li>Maximum file size: <span className="font-medium">400 KB</span></li>
                          <li>Allowed formats: PNG, JPG, JPEG, WEBP</li>
                          <li>Subject should fill most of the image</li>
                          <li>Avoid large white margins or transparent padding</li>
                          <li>Keep the subject centered</li>
                        </ul>
                      </div>
                    </div>
                  )}
                </div>
                {/* Form Template Section */}
                <div className="md:col-span-2">
                  <label className="block text-sm text-[#1a1a1a] mb-2">
                    Form Template <span className="text-[#999] text-xs">(optional — PDF/DOC users can download before filling)</span>
                  </label>
                  {/* Current template (if exists and no new file chosen) */}
                  {editServiceData.formTemplateUrl && !editFormTemplateFile && (
                    <div className="flex items-center gap-3 mb-2 p-3 bg-[#f0f0ff] border-2 border-[#e5e5e5] rounded">
                      <FileDown className="w-5 h-5 text-[#4C4CFF] flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <p className="text-xs text-[#666] mb-1">Current template</p>
                        <a
                          href={editServiceData.formTemplateUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-xs text-[#4C4CFF] hover:underline truncate block"
                        >
                          {editServiceData.formTemplateUrl.split('/').pop()}
                        </a>
                      </div>
                      <a
                        href={editServiceData.formTemplateUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="p-1 text-[#4C4CFF] hover:text-[#3d3dcc]"
                        title="Open template"
                      >
                        <Download className="w-4 h-4" />
                      </a>
                    </div>
                  )}
                  {/* Preview of selected new template file */}
                  {editFormTemplateFile && (
                    <div className="flex items-center gap-3 mb-2 p-3 bg-[#f0f0ff] border-2 border-[#4C4CFF] rounded">
                      <FileDown className="w-5 h-5 text-[#4C4CFF] flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm text-[#1a1a1a] truncate">{editFormTemplateFile.name}</p>
                        <p className="text-xs text-[#666]">{(editFormTemplateFile.size / 1024).toFixed(1)} KB</p>
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          setEditFormTemplateFile(null);
                          if (editFormTemplateInputRef.current) editFormTemplateInputRef.current.value = '';
                        }}
                        className="p-1 text-red-500 hover:text-red-400"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  )}
                  {/* Upload / Replace button */}
                  {!editFormTemplateFile && (
                    <div>
                      <input
                        ref={editFormTemplateInputRef}
                        type="file"
                        accept=".pdf,.doc,.docx"
                        id="edit-form-template"
                        className="hidden"
                        onChange={(e) => {
                          const f = e.target.files?.[0];
                          if (f) setEditFormTemplateFile(f);
                        }}
                      />
                      <label
                        htmlFor="edit-form-template"
                        className="inline-flex items-center gap-2 px-4 py-2 border-2 border-dashed border-[#4C4CFF] text-[#4C4CFF] rounded cursor-pointer hover:bg-[#f0f0ff] transition-colors"
                      >
                        <Plus className="w-4 h-4" />
                        <span className="text-sm">
                          {editServiceData.formTemplateUrl ? 'Replace Template' : 'Upload Form Template'}
                        </span>
                      </label>
                      <p className="text-xs text-[#999] mt-1">PDF, DOC, DOCX — Max 20 MB</p>
                    </div>
                  )}
                </div>
              </div>
              <div className="flex gap-2 mt-4">
                <button
                  onClick={handleEditService}
                  disabled={uploadingEditServiceLogo || uploadingEditFormTemplate}
                  className="px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {(uploadingEditServiceLogo || uploadingEditFormTemplate) ? (
                    <span className="flex items-center gap-2">
                      <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      Uploading…
                    </span>
                  ) : 'Update Service'}
                </button>
                <button
                  onClick={() => {
                    setShowEditService(false);
                    setEditServiceData(null);
                    setEditServiceLogoFile(null);
                    setEditServiceLogoPreview(null);
                    if (editServiceLogoInputRef.current) editServiceLogoInputRef.current.value = '';
                    setEditFormTemplateFile(null);
                    if (editFormTemplateInputRef.current) editFormTemplateInputRef.current.value = '';
                  }}
                  className="px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
