import { useState, useEffect, useRef } from 'react';
import { Plus, Edit, Trash2, FileText, FileDown, X, Download, Globe, ArrowLeft } from 'lucide-react';
import { serviceManagementService, ServiceCategory, Service } from '../../../services/categoryService';
import ServiceDetail from './ServiceDetail';

interface Props {
  category: ServiceCategory;
  onBack: () => void;
}

type ServiceRow = Service & { categoryId: string; categoryName: string };

interface EditServiceData {
  id: string;
  name: string;
  categoryId: string;
  price: number;
  logoUrl: string;
  redirectUrl: string;
  formTemplateUrl: string;
}

export default function CategoryDetail({ category, onBack }: Props) {
  const [services, setServices] = useState<ServiceRow[]>([]);
  const [selectedService, setSelectedService] = useState<ServiceRow | null>(null);

  // ── Add form ─────────────────────────────────────────────────────────────
  const [showAddService, setShowAddService] = useState(false);
  const [newServiceData, setNewServiceData] = useState({ name: '', price: 0, redirectUrl: '' });

  // ── Edit form ─────────────────────────────────────────────────────────────
  const [showEditService, setShowEditService] = useState(false);
  const [editServiceData, setEditServiceData] = useState<EditServiceData | null>(null);

  // ── Logo upload – add ─────────────────────────────────────────────────────
  const [newServiceLogoFile, setNewServiceLogoFile] = useState<File | null>(null);
  const [newServiceLogoPreview, setNewServiceLogoPreview] = useState<string | null>(null);
  const [uploadingServiceLogo, setUploadingServiceLogo] = useState(false);
  const newServiceLogoInputRef = useRef<HTMLInputElement>(null);

  // ── Logo upload – edit ────────────────────────────────────────────────────
  const [editServiceLogoFile, setEditServiceLogoFile] = useState<File | null>(null);
  const [editServiceLogoPreview, setEditServiceLogoPreview] = useState<string | null>(null);
  const [uploadingEditServiceLogo, setUploadingEditServiceLogo] = useState(false);
  const editServiceLogoInputRef = useRef<HTMLInputElement>(null);

  // ── Form template – add ───────────────────────────────────────────────────
  const [newFormTemplateFile, setNewFormTemplateFile] = useState<File | null>(null);
  const [uploadingNewFormTemplate, setUploadingNewFormTemplate] = useState(false);
  const newFormTemplateInputRef = useRef<HTMLInputElement>(null);

  // ── Form template – edit ──────────────────────────────────────────────────
  const [editFormTemplateFile, setEditFormTemplateFile] = useState<File | null>(null);
  const [uploadingEditFormTemplate, setUploadingEditFormTemplate] = useState(false);
  const editFormTemplateInputRef = useRef<HTMLInputElement>(null);

  // ── Live service subscription for this category ───────────────────────────
  useEffect(() => {
    const unsubscribe = serviceManagementService.subscribeToAllServices(
      (svcs) => setServices(svcs.filter((s) => s.categoryId === category.id)),
      (err) => console.error('Error loading services:', err)
    );
    return () => unsubscribe();
  }, [category.id]);

  // ── Logo file handler ─────────────────────────────────────────────────────
  const handleServiceLogoFileChange = (
    e: React.ChangeEvent<HTMLInputElement>,
    mode: 'add' | 'edit'
  ) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const allowed = ['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp'];
    if (!allowed.includes(file.type)) {
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

  // ── Add service ───────────────────────────────────────────────────────────
  const handleAddService = async () => {
    if (!newServiceData.name.trim()) {
      alert('Please enter a service name.');
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
        category.id,
        newServiceData.name,
        newServiceData.price || undefined,
        logoUrl,
        newServiceData.redirectUrl || undefined,
        formTemplateUrl || undefined
      );
      setNewServiceData({ name: '', price: 0, redirectUrl: '' });
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

  // ── Edit service ──────────────────────────────────────────────────────────
  const handleEditService = async () => {
    if (!editServiceData?.name.trim()) return;
    try {
      setUploadingEditServiceLogo(true);
      setUploadingEditFormTemplate(true);
      let logoUrl = editServiceData.logoUrl || '';
      let formTemplateUrl = editServiceData.formTemplateUrl || '';

      if (editServiceLogoFile) {
        if (logoUrl) await serviceManagementService.deleteServiceLogoFile(logoUrl);
        logoUrl = await serviceManagementService.uploadServiceLogo(editServiceLogoFile);
      }
      if (editFormTemplateFile) {
        formTemplateUrl = await serviceManagementService.uploadFormTemplate(editFormTemplateFile);
      }

      await serviceManagementService.updateService(editServiceData.id, {
        name: editServiceData.name,
        categoryId: editServiceData.categoryId,
        price: editServiceData.price,
        logoUrl,
        redirectUrl: editServiceData.redirectUrl || '',
        formTemplateUrl,
      });

      setEditServiceData(null);
      setEditServiceLogoFile(null);
      setEditServiceLogoPreview(null);
      setEditFormTemplateFile(null);
      if (editServiceLogoInputRef.current) editServiceLogoInputRef.current.value = '';
      if (editFormTemplateInputRef.current) editFormTemplateInputRef.current.value = '';
      setShowEditService(false);
    } catch (error) {
      console.error('Error updating service:', error);
      alert('Failed to update service. Please try again.');
    } finally {
      setUploadingEditServiceLogo(false);
      setUploadingEditFormTemplate(false);
    }
  };

  // ── Delete service ────────────────────────────────────────────────────────
  const handleDeleteService = async (serviceId: string, logoUrl?: string) => {
    if (confirm('Are you sure you want to delete this service?')) {
      try {
        await serviceManagementService.deleteService(serviceId);
        if (logoUrl) await serviceManagementService.deleteServiceLogoFile(logoUrl);
      } catch (error) {
        console.error('Error deleting service:', error);
      }
    }
  };

  // ── Helpers ───────────────────────────────────────────────────────────────
  const resetAddForm = () => {
    setShowAddService(false);
    setNewServiceData({ name: '', price: 0, redirectUrl: '' });
    setNewServiceLogoFile(null);
    setNewServiceLogoPreview(null);
    if (newServiceLogoInputRef.current) newServiceLogoInputRef.current.value = '';
    setNewFormTemplateFile(null);
    if (newFormTemplateInputRef.current) newFormTemplateInputRef.current.value = '';
  };

  const resetEditForm = () => {
    setShowEditService(false);
    setEditServiceData(null);
    setEditServiceLogoFile(null);
    setEditServiceLogoPreview(null);
    if (editServiceLogoInputRef.current) editServiceLogoInputRef.current.value = '';
    setEditFormTemplateFile(null);
    if (editFormTemplateInputRef.current) editFormTemplateInputRef.current.value = '';
  };

  // ── Render ────────────────────────────────────────────────────────────────
  if (selectedService) {
    return (
      <ServiceDetail
        service={selectedService}
        onBack={() => setSelectedService(null)}
      />
    );
  }

  return (
    <div className="space-y-6">
      {/* Back + Header + Add Service */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button
            onClick={onBack}
            className="p-2 text-gray-400 hover:text-gray-100 hover:bg-[#0f1518] rounded transition-colors"
            title="Back to categories"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-2xl text-gray-100">{category.name}</h1>
            <p className="text-sm text-gray-400">
              {services.length} service{services.length !== 1 ? 's' : ''}
            </p>
          </div>
        </div>
        <button
          onClick={() => setShowAddService(true)}
          className="flex items-center gap-2 px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors"
        >
          <Plus className="w-4 h-4" />
          <span className="text-sm">Add Service</span>
        </button>
      </div>

      {/* ── Add Service Form ─────────────────────────────────────────────── */}
      {showAddService && (
        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <h3 className="text-base text-[#1a1a1a] mb-4">Add New Service</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Service Name */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">Service Name</label>
              <input
                type="text"
                value={newServiceData.name}
                onChange={(e) => setNewServiceData({ ...newServiceData, name: e.target.value })}
                className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                placeholder="Enter service name"
              />
            </div>

            {/* Category – locked */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">Category</label>
              <input
                type="text"
                value={category.name}
                disabled
                className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded bg-[#f5f5f5] text-[#666666] cursor-not-allowed"
              />
            </div>

            {/* Service Fee */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">Service Fee (₹)</label>
              <input
                type="number"
                value={newServiceData.price}
                onChange={(e) =>
                  setNewServiceData({ ...newServiceData, price: parseInt(e.target.value) || 0 })
                }
                className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                placeholder="Enter fee amount"
              />
            </div>

            {/* Redirect URL */}
            <div className="md:col-span-2">
              <label className="block text-sm text-[#1a1a1a] mb-2">
                Redirect URL{' '}
                <span className="text-[#999] text-xs">
                  (optional — if set, tapping the service opens this URL)
                </span>
              </label>
              <input
                type="url"
                value={newServiceData.redirectUrl}
                onChange={(e) =>
                  setNewServiceData({ ...newServiceData, redirectUrl: e.target.value })
                }
                className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                placeholder="https://example.com/service-page"
              />
            </div>

            {/* Service Logo */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">Service Logo</label>
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
                        if (newServiceLogoInputRef.current)
                          newServiceLogoInputRef.current.value = '';
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
                    id="cd-new-service-logo"
                    className="hidden"
                    onChange={(e) => handleServiceLogoFileChange(e, 'add')}
                  />
                  <label
                    htmlFor="cd-new-service-logo"
                    className="inline-flex items-center gap-2 px-4 py-2 border-2 border-dashed border-[#4C4CFF] text-[#4C4CFF] rounded cursor-pointer hover:bg-[#f0f0ff] transition-colors"
                  >
                    <Plus className="w-4 h-4" />
                    <span className="text-sm">Choose Logo Image</span>
                  </label>
                  <div className="mt-2 p-3 bg-[#f5f5f5] border border-[#e0e0e0] rounded-lg text-xs text-[#555] leading-relaxed">
                    <p className="font-semibold text-[#333] mb-1">Image Upload Guidelines</p>
                    <ul className="list-disc list-inside space-y-0.5">
                      <li>
                        Recommended size: <span className="font-medium">600 × 600 pixels</span>{' '}
                        (square)
                      </li>
                      <li>
                        Maximum file size: <span className="font-medium">400 KB</span>
                      </li>
                      <li>Allowed formats: PNG, JPG, JPEG, WEBP</li>
                      <li>Subject should fill most of the image</li>
                      <li>Avoid large white margins or transparent padding</li>
                      <li>Keep the subject centered</li>
                    </ul>
                  </div>
                </div>
              )}
            </div>

            {/* Form Template */}
            <div className="md:col-span-2">
              <label className="block text-sm text-[#1a1a1a] mb-2">
                Form Template{' '}
                <span className="text-[#999] text-xs">
                  (optional — PDF/DOC users can download before filling)
                </span>
              </label>
              {newFormTemplateFile ? (
                <div className="flex items-center gap-3 p-3 bg-[#f0f0ff] border-2 border-[#4C4CFF] rounded">
                  <FileDown className="w-5 h-5 text-[#4C4CFF] flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-[#1a1a1a] truncate">{newFormTemplateFile.name}</p>
                    <p className="text-xs text-[#666]">
                      {(newFormTemplateFile.size / 1024).toFixed(1)} KB
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setNewFormTemplateFile(null);
                      if (newFormTemplateInputRef.current)
                        newFormTemplateInputRef.current.value = '';
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
                    id="cd-new-form-template"
                    className="hidden"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) setNewFormTemplateFile(f);
                    }}
                  />
                  <label
                    htmlFor="cd-new-form-template"
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
              {uploadingServiceLogo || uploadingNewFormTemplate ? (
                <span className="flex items-center gap-2">
                  <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  Uploading…
                </span>
              ) : (
                'Save Service'
              )}
            </button>
            <button
              onClick={resetAddForm}
              className="px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {/* ── Services Table ───────────────────────────────────────────────── */}
      {services.length === 0 ? (
        <div className="text-center py-10 bg-white border-2 border-[#e5e5e5] rounded">
          <FileText className="w-8 h-8 text-[#ccc] mx-auto mb-3" />
          <p className="text-[#666666] text-sm">No services in this category yet.</p>
        </div>
      ) : (
        <div className="bg-white border-2 border-[#e5e5e5] rounded overflow-x-auto">
          <table className="w-full min-w-[700px]">
            <thead className="bg-[#f5f5f5] border-b-2 border-[#e5e5e5]">
              <tr>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Logo</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Service Name</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Service Fee</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Redirect URL</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Form Template</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Status</th>
                <th className="px-5 py-3 text-left text-sm text-[#1a1a1a]">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y-2 divide-[#e5e5e5]">
              {services.map((service) => (
                <tr
                  key={service.id}
                  className="hover:bg-[#fafafa] transition-colors cursor-pointer"
                  onClick={() => setSelectedService(service)}
                >
                  <td className="px-5 py-4">
                    {service.logoUrl ? (
                      <img
                        src={service.logoUrl}
                        alt={service.name}
                        className="w-10 h-10 rounded-full object-cover border border-[#e5e5e5]"
                        onError={(e) => {
                          (e.target as HTMLImageElement).src = '';
                        }}
                      />
                    ) : (
                      <div className="w-10 h-10 rounded-full bg-[#E8E8FF] flex items-center justify-center">
                        <FileText className="w-5 h-5 text-[#4C4CFF]" />
                      </div>
                    )}
                  </td>
                  <td className="px-5 py-4 text-sm text-[#1a1a1a]">{service.name}</td>
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
                        <span className="max-w-[140px] truncate block">
                          {(service as any).redirectUrl}
                        </span>
                      </a>
                    ) : (
                      <span className="text-xs text-[#999]">-</span>
                    )}
                  </td>
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
                        onClick={(e) => {
                          e.stopPropagation();
                          setEditServiceData({
                            id: service.id,
                            name: service.name,
                            categoryId: service.categoryId,
                            price: service.price || 0,
                            logoUrl: service.logoUrl || '',
                            redirectUrl: (service as any).redirectUrl || '',
                            formTemplateUrl: (service as any).formTemplateUrl || '',
                          });
                          setShowEditService(true);
                        }}
                        className="p-2 text-[#4C4CFF] hover:bg-[#E8E8FF] rounded transition-colors"
                        title="Edit service"
                      >
                        <Edit className="w-4 h-4" />
                      </button>
                      <button
                        onClick={(e) => { e.stopPropagation(); handleDeleteService(service.id, service.logoUrl); }}
                        className="p-2 text-[#F44336] hover:bg-[#FFEBEE] rounded transition-colors"
                        title="Delete service"
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

      {/* ── Edit Service Form ────────────────────────────────────────────── */}
      {showEditService && editServiceData && (
        <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
          <h3 className="text-base text-[#1a1a1a] mb-4">Edit Service</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Service Name */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">Service Name</label>
              <input
                type="text"
                value={editServiceData.name}
                onChange={(e) =>
                  setEditServiceData({ ...editServiceData, name: e.target.value })
                }
                className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                placeholder="Enter service name"
              />
            </div>

            {/* Category – locked */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">Category</label>
              <input
                type="text"
                value={category.name}
                disabled
                className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded bg-[#f5f5f5] text-[#666666] cursor-not-allowed"
              />
            </div>

            {/* Service Fee */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">Service Fee (₹)</label>
              <input
                type="number"
                value={editServiceData.price}
                onChange={(e) =>
                  setEditServiceData({
                    ...editServiceData,
                    price: parseInt(e.target.value) || 0,
                  })
                }
                className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                placeholder="Enter fee amount"
              />
            </div>

            {/* Redirect URL */}
            <div className="md:col-span-2">
              <label className="block text-sm text-[#1a1a1a] mb-2">
                Redirect URL{' '}
                <span className="text-[#999] text-xs">
                  (optional — if set, tapping the service opens this URL)
                </span>
              </label>
              <input
                type="url"
                value={editServiceData.redirectUrl}
                onChange={(e) =>
                  setEditServiceData({ ...editServiceData, redirectUrl: e.target.value })
                }
                className="w-full px-4 py-2 border-2 border-[#e5e5e5] rounded focus:outline-none focus:border-[#4C4CFF] text-[#1a1a1a] bg-white"
                placeholder="https://example.com/service-page"
              />
            </div>

            {/* Service Logo */}
            <div>
              <label className="block text-sm text-[#1a1a1a] mb-2">Service Logo</label>

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
                        if (editServiceLogoInputRef.current)
                          editServiceLogoInputRef.current.value = '';
                      }}
                      className="text-xs text-red-500 hover:text-red-400"
                    >
                      Cancel Replace
                    </button>
                  </div>
                </div>
              )}

              {!editServiceLogoPreview && (
                <div>
                  <input
                    ref={editServiceLogoInputRef}
                    type="file"
                    accept="image/*"
                    id="cd-edit-service-logo"
                    className="hidden"
                    onChange={(e) => handleServiceLogoFileChange(e, 'edit')}
                  />
                  <label
                    htmlFor="cd-edit-service-logo"
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
                      <li>
                        Recommended size: <span className="font-medium">600 × 600 pixels</span>{' '}
                        (square)
                      </li>
                      <li>
                        Maximum file size: <span className="font-medium">400 KB</span>
                      </li>
                      <li>Allowed formats: PNG, JPG, JPEG, WEBP</li>
                      <li>Subject should fill most of the image</li>
                      <li>Avoid large white margins or transparent padding</li>
                      <li>Keep the subject centered</li>
                    </ul>
                  </div>
                </div>
              )}
            </div>

            {/* Form Template */}
            <div className="md:col-span-2">
              <label className="block text-sm text-[#1a1a1a] mb-2">
                Form Template{' '}
                <span className="text-[#999] text-xs">
                  (optional — PDF/DOC users can download before filling)
                </span>
              </label>

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

              {editFormTemplateFile && (
                <div className="flex items-center gap-3 mb-2 p-3 bg-[#f0f0ff] border-2 border-[#4C4CFF] rounded">
                  <FileDown className="w-5 h-5 text-[#4C4CFF] flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-[#1a1a1a] truncate">{editFormTemplateFile.name}</p>
                    <p className="text-xs text-[#666]">
                      {(editFormTemplateFile.size / 1024).toFixed(1)} KB
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setEditFormTemplateFile(null);
                      if (editFormTemplateInputRef.current)
                        editFormTemplateInputRef.current.value = '';
                    }}
                    className="p-1 text-red-500 hover:text-red-400"
                  >
                    <X className="w-4 h-4" />
                  </button>
                </div>
              )}

              {!editFormTemplateFile && (
                <div>
                  <input
                    ref={editFormTemplateInputRef}
                    type="file"
                    accept=".pdf,.doc,.docx"
                    id="cd-edit-form-template"
                    className="hidden"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) setEditFormTemplateFile(f);
                    }}
                  />
                  <label
                    htmlFor="cd-edit-form-template"
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
              {uploadingEditServiceLogo || uploadingEditFormTemplate ? (
                <span className="flex items-center gap-2">
                  <span className="inline-block w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  Uploading…
                </span>
              ) : (
                'Update Service'
              )}
            </button>
            <button
              onClick={resetEditForm}
              className="px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
