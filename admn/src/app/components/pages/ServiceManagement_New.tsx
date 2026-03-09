import { useState, useEffect } from 'react';
import { Plus, Edit, Trash2, FolderTree } from 'lucide-react';
import { categoryService, serviceManagementService, ServiceCategory, Service } from '../../services/categoryService';

export default function ServiceManagement() {
  const [activeTab, setActiveTab] = useState<'categories' | 'services'>('categories');
  const [categories, setCategories] = useState<ServiceCategory[]>([]);
  const [services, setServices] = useState<(Service & { categoryId: string; categoryName: string })[]>([]);
  const [showAddCategory, setShowAddCategory] = useState(false);
  const [showAddService, setShowAddService] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState('');
  const [newServiceData, setNewServiceData] = useState({ name: '', categoryId: '', price: 0 });
  const [loading, setLoading] = useState(true);
  const [selectedCategoryForService, setSelectedCategoryForService] = useState('');

  // Subscribe to categories
  useEffect(() => {
    setLoading(true);
    const unsubscribe = categoryService.subscribeToCategories(
      (cats) => {
        setCategories(cats);
        setLoading(false);
      },
      (error) => {
        console.error('Error:', error);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  // Subscribe to all services
  useEffect(() => {
    const unsubscribe = serviceManagementService.subscribeToAllServices(
      (svcs) => {
        setServices(svcs);
      },
      (error) => {
        console.error('Error:', error);
      }
    );

    return () => unsubscribe();
  }, []);

  // Handle add category
  const handleAddCategory = async () => {
    if (newCategoryName.trim()) {
      try {
        await categoryService.addCategory(newCategoryName);
        setNewCategoryName('');
        setShowAddCategory(false);
      } catch (error) {
        console.error('Error adding category:', error);
      }
    }
  };

  // Handle add service
  const handleAddService = async () => {
    if (newServiceData.name.trim() && selectedCategoryForService) {
      try {
        await serviceManagementService.addService(
          selectedCategoryForService,
          newServiceData.name,
          newServiceData.price || undefined
        );
        setNewServiceData({ name: '', categoryId: '', price: 0 });
        setSelectedCategoryForService('');
        setShowAddService(false);
      } catch (error) {
        console.error('Error adding service:', error);
      }
    }
  };

  // Handle delete category
  const handleDeleteCategory = async (categoryId: string) => {
    if (confirm('Are you sure you want to delete this category?')) {
      try {
        await categoryService.deleteCategory(categoryId);
      } catch (error) {
        console.error('Error deleting category:', error);
      }
    }
  };

  // Handle delete service
  const handleDeleteService = async (categoryId: string, serviceId: string) => {
    if (confirm('Are you sure you want to delete this service?')) {
      try {
        await serviceManagementService.deleteService(categoryId, serviceId);
      } catch (error) {
        console.error('Error deleting service:', error);
      }
    }
  };

  // Get service count for each category
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
            {categories.map((category) => (
              <div key={category.id} className="bg-[#071018] border border-[#111318] rounded p-5">
                <div className="flex items-start justify-between mb-3">
                  <h3 className="text-base text-gray-100">{category.name}</h3>
                  <div className="flex gap-1">
                    <button className="p-1.5 text-[#243BFF] hover:bg-[#0f243b] rounded transition-colors">
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
            ))}
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
                <div className="flex gap-2">
                  <button
                    onClick={handleAddCategory}
                    className="px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors"
                  >
                    Save Category
                  </button>
                  <button
                    onClick={() => {
                      setShowAddCategory(false);
                      setNewCategoryName('');
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
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Service Name</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Category</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Service Fee</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Status</th>
                    <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y-2 divide-[#e5e5e5]">
                  {services.map((service) => (
                    <tr key={service.id} className="hover:bg-[#fafafa] transition-colors">
                      <td className="px-5 py-4 text-sm text-[#1a1a1a]">{service.name}</td>
                      <td className="px-5 py-4 text-sm text-[#666666]">{service.categoryName}</td>
                      <td className="px-5 py-4 text-sm text-[#1a1a1a]">
                        {service.price ? `₹${service.price}` : '-'}
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
                          <button className="p-2 text-[#4C4CFF] hover:bg-[#E8E8FF] rounded transition-colors">
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() =>
                              handleDeleteService(service.categoryId, service.id)
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
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF]"
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
                    className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF]"
                    placeholder="Enter fee amount"
                  />
                </div>
              </div>
              <div className="flex gap-2 mt-4">
                <button
                  onClick={handleAddService}
                  className="px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors"
                >
                  Save Service
                </button>
                <button
                  onClick={() => {
                    setShowAddService(false);
                    setNewServiceData({ name: '', categoryId: '', price: 0 });
                    setSelectedCategoryForService('');
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
