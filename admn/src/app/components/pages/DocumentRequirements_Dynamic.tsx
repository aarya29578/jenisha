import { useState, useEffect } from 'react';
import { Plus, Trash2, ArrowUp, ArrowDown, FileText, Loader, AlertCircle, Image, FileInput, Calendar, Hash, Type, Clock, MapPin, Smartphone, FileArchive, Upload } from 'lucide-react';
import { serviceManagementService, dynamicFieldsService, ServiceWithCategory, DynamicField } from '../../../services/categoryService';

interface FieldFormData {
  fieldName: string;
  fieldType: 'text' | 'number' | 'date' | 'dob' | 'address' | 'mobile' | 'image' | 'pdf' | 'appointment' | 'time_range' | 'document' | 'template';
  isRequired: boolean;
  placeholder: string;
  displayOrder: number;
  maxSizeKB?: number;
}

export default function DocumentRequirements() {
  const [selectedServiceId, setSelectedServiceId] = useState<string>('');
  const [selectedServiceName, setSelectedServiceName] = useState<string>('');
  const [selectedCategoryName, setSelectedCategoryName] = useState<string>('');
  const [services, setServices] = useState<ServiceWithCategory[]>([]);
  const [fields, setFields] = useState<FieldFormData[]>([]);
  const [loading, setLoading] = useState(true);
  const [servicesLoading, setServicesLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string>('');
  const [successMessage, setSuccessMessage] = useState<string>('');
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Load all active services on mount
  useEffect(() => {
    setServicesLoading(true);
    setError('');
    
    console.log('📋 DocumentRequirements: Loading active services...');
    
    const unsubscribe = serviceManagementService.subscribeToActiveServices(
      (loadedServices) => {
        console.log('✅ Services loaded:', loadedServices.length);
        setServices(loadedServices);
        
        // Auto-select first service if available
        if (loadedServices.length > 0 && !selectedServiceId) {
          const firstService = loadedServices[0];
          setSelectedServiceId(firstService.id);
          setSelectedServiceName(firstService.name);
          setSelectedCategoryName(firstService.categoryName);
        }
        setServicesLoading(false);
      },
      (error) => {
        console.error('❌ Error loading services:', error);
        setServicesLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  // Load document fields when service changes
  useEffect(() => {
    if (selectedServiceId) {
      setLoading(true);
      const unsubscribe = dynamicFieldsService.subscribeToServiceDocumentFields(
        selectedServiceId,
        (loadedFields) => {
          console.log('📄 Document fields loaded:', loadedFields);
          // Convert to form data
          const formFields: FieldFormData[] = loadedFields.map((field) => ({
            fieldName: field.fieldName,
            fieldType: field.fieldType,
            isRequired: field.isRequired,
            placeholder: field.placeholder || '',
            displayOrder: field.displayOrder,
            maxSizeKB: (field as any).maxSizeKB ?? undefined,
          }));
          setFields(formFields);
          setLoading(false);
        },
        (error) => {
          console.error('❌ Error loading document fields:', error);
          setError(`Error loading fields: ${error.message}`);
          setLoading(false);
        }
      );

      return unsubscribe;
    }
  }, [selectedServiceId]);

  const handleDeleteService = async (serviceId: string) => {
    setDeleting(true);
    try {
      await serviceManagementService.deleteServicePermanently(serviceId);
      // If the deleted service was selected, clear the selection
      if (selectedServiceId === serviceId) {
        setSelectedServiceId('');
        setSelectedServiceName('');
        setSelectedCategoryName('');
        setFields([]);
      }
      setSuccessMessage('Service deleted successfully.');
      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (err: any) {
      setError(`Error deleting service: ${err.message}`);
    } finally {
      setDeleting(false);
      setDeleteConfirmId(null);
    }
  };

  const handleSelectService = (service: ServiceWithCategory) => {
    console.log('🎯 Selected service:', service);
    setSelectedServiceId(service.id);
    setSelectedServiceName(service.name);
    setSelectedCategoryName(service.categoryName);
    setError('');
    setSuccessMessage('');
  };

  const handleAddField = () => {
    const newField: FieldFormData = {
      fieldName: '',
      fieldType: 'text',
      isRequired: true,
      placeholder: '',
      displayOrder: fields.length,
    };
    setFields([...fields, newField]);
  };

  const handleRemoveField = (index: number) => {
    const updatedFields = fields.filter((_, i) => i !== index);
    // Reorder remaining fields
    updatedFields.forEach((field, i) => {
      field.displayOrder = i;
    });
    setFields(updatedFields);
  };

  const handleMoveField = (index: number, direction: 'up' | 'down') => {
    if (
      (direction === 'up' && index === 0) ||
      (direction === 'down' && index === fields.length - 1)
    ) {
      return;
    }

    const updatedFields = [...fields];
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    
    // Swap fields
    [updatedFields[index], updatedFields[targetIndex]] = [updatedFields[targetIndex], updatedFields[index]];
    
    // Update display orders
    updatedFields.forEach((field, i) => {
      field.displayOrder = i;
    });
    
    setFields(updatedFields);
  };

  const handleFieldChange = (index: number, key: keyof FieldFormData, value: any) => {
    const updatedFields = [...fields];
    updatedFields[index] = {
      ...updatedFields[index],
      [key]: value,
    };
    setFields(updatedFields);
  };

  const handleSaveFields = async () => {
    // Validation
    for (let i = 0; i < fields.length; i++) {
      if (!fields[i].fieldName.trim()) {
        setError(`Field ${i + 1}: Field name is required`);
        return;
      }
    }

    setSaving(true);
    setError('');
    setSuccessMessage('');

    try {
      await dynamicFieldsService.saveServiceDocumentFields(selectedServiceId, fields);
      setSuccessMessage('✅ Document fields saved successfully!');
      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (err: any) {
      setError(`Error saving fields: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  const getFieldTypeIcon = (fieldType: string) => {
    switch (fieldType) {
      case 'text':      return <Type        className="w-4 h-4" />;
      case 'number':    return <Hash        className="w-4 h-4" />;
      case 'date':      return <Calendar    className="w-4 h-4" />;
      case 'dob':       return <Calendar    className="w-4 h-4" />;
      case 'address':   return <MapPin      className="w-4 h-4" />;
      case 'mobile':    return <Smartphone  className="w-4 h-4" />;
      case 'image':     return <Image       className="w-4 h-4" />;
      case 'pdf':       return <FileInput   className="w-4 h-4" />;
      case 'appointment': return <Clock     className="w-4 h-4" />;
      case 'time_range':  return <Clock     className="w-4 h-4" />;
      case 'document':  return <FileArchive className="w-4 h-4" />;
      case 'template':  return <Upload      className="w-4 h-4" />;
      default:          return <FileText    className="w-4 h-4" />;
    }
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl text-[#1a1a1a] mb-2">Dynamic Document Fields</h1>
        <p className="text-[#666666]">Configure custom document fields for each service</p>
      </div>

      {/* Info Box */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded p-4">
        <div className="flex items-start gap-3">
          <FileText className="w-5 h-5 text-[#4C4CFF] flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-sm text-[#1a1a1a] mb-1">Dynamic Field System</h3>
            <p className="text-sm text-[#666666]">
              Create unlimited custom fields per service. Fields appear dynamically in the app. 
              Image/PDF fields automatically upload to Hostinger storage.
            </p>
          </div>
        </div>
      </div>

      {/* Error/Success Messages */}
      {error && (
        <div className="bg-[#FFEBEE] border-2 border-[#F44336] rounded p-4">
          <p className="text-sm text-[#C62828]">{error}</p>
        </div>
      )}

      {successMessage && (
        <div className="bg-[#E8F5E9] border-2 border-[#4CAF50] rounded p-4">
          <p className="text-sm text-[#2E7D32]">{successMessage}</p>
        </div>
      )}

      {/* Delete Confirmation Dialog */}
      {deleteConfirmId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-xl p-6 w-full max-w-sm mx-4">
            <h3 className="text-base font-medium text-[#1a1a1a] mb-2">Delete Service</h3>
            <p className="text-sm text-[#666666] mb-6">
              Are you sure you want to delete this service? This will also remove its document field configuration. This action cannot be undone.
            </p>
            <div className="flex justify-end gap-3">
              <button
                onClick={() => setDeleteConfirmId(null)}
                disabled={deleting}
                className="px-4 py-2 text-sm text-[#1a1a1a] border-2 border-[#e5e5e5] rounded hover:bg-[#f9f9f9] transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={() => handleDeleteService(deleteConfirmId)}
                disabled={deleting}
                className="flex items-center gap-2 px-4 py-2 text-sm bg-[#F44336] text-white rounded hover:bg-[#d32f2f] transition-colors disabled:opacity-50"
              >
                {deleting && <Loader className="w-4 h-4 animate-spin" />}
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 2-Panel Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* LEFT PANEL: Service List */}
        <div className="lg:col-span-1">
          <div className="bg-white border-2 border-[#e5e5e5] rounded">
            <div className="px-5 py-4 border-b-2 border-[#e5e5e5]">
              <h2 className="text-base text-[#1a1a1a]">Services</h2>
            </div>
            
            <div className="max-h-[600px] overflow-y-auto">
              {servicesLoading ? (
                <div className="px-5 py-8 flex justify-center">
                  <Loader className="w-5 h-5 text-[#4C4CFF] animate-spin" />
                </div>
              ) : services.length === 0 ? (
                <div className="px-5 py-8">
                  <AlertCircle className="w-5 h-5 text-orange-500 mb-3" />
                  <p className="text-sm text-[#666666]">No services available</p>
                </div>
              ) : (
                services.map((service) => (
                  <div
                    key={service.id}
                    className={`
                      flex items-center border-b-2 border-[#e5e5e5] transition-colors
                      ${selectedServiceId === service.id
                        ? 'bg-[#E8E8FF] border-l-4 border-l-[#4C4CFF]'
                        : 'hover:bg-[#f9f9f9]'
                      }
                    `}
                  >
                    <button
                      onClick={() => handleSelectService(service)}
                      className="flex-1 px-5 py-4 text-left min-w-0"
                    >
                      <h3 className="text-sm font-medium text-[#1a1a1a] truncate">{service.name}</h3>
                      <p className="text-xs text-[#666666] mt-1 truncate">{service.categoryName}</p>
                    </button>
                    <button
                      onClick={(e) => { e.stopPropagation(); setDeleteConfirmId(service.id); }}
                      title="Delete service"
                      className="flex-shrink-0 mr-3 p-1.5 text-[#F44336] hover:bg-[#FFEBEE] rounded transition-colors"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        {/* RIGHT PANEL: Dynamic Fields */}
        <div className="lg:col-span-2">
          <div className="bg-white border-2 border-[#e5e5e5] rounded">
            {/* Header */}
            <div className="px-5 py-4 border-b-2 border-[#e5e5e5] flex items-center justify-between">
              <h2 className="text-base text-[#1a1a1a]">Document Fields</h2>
              <div className="flex gap-2">
                <button
                  onClick={handleAddField}
                  disabled={!selectedServiceId}
                  className="flex items-center gap-2 px-3 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Plus className="w-4 h-4" />
                  Add Field
                </button>
                <button
                  onClick={handleSaveFields}
                  disabled={!selectedServiceId || fields.length === 0 || saving}
                  className="flex items-center gap-2 px-4 py-2 bg-[#16A34A] text-white rounded hover:bg-[#15803D] transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {saving ? <Loader className="w-4 h-4 animate-spin" /> : null}
                  Save Fields
                </button>
              </div>
            </div>

            {/* Fields List */}
            <div className="p-5 space-y-4 max-h-[600px] overflow-y-auto">
              {loading ? (
                <div className="flex justify-center py-8">
                  <Loader className="w-5 h-5 text-[#4C4CFF] animate-spin" />
                </div>
              ) : !selectedServiceId ? (
                <div className="text-center py-12">
                  <FileText className="w-8 h-8 text-[#999999] mx-auto mb-3" />
                  <p className="text-sm text-[#666666]">
                    Select a service to configure its document fields
                  </p>
                </div>
              ) : fields.length === 0 ? (
                <div className="text-center py-12">
                  <FileText className="w-8 h-8 text-[#999999] mx-auto mb-3" />
                  <p className="text-sm text-[#666666] mb-4">
                    No fields configured yet
                  </p>
                  <button
                    onClick={handleAddField}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors text-sm"
                  >
                    <Plus className="w-4 h-4" />
                    Add First Field
                  </button>
                </div>
              ) : (
                fields.map((field, index) => (
                  <div
                    key={index}
                    className="p-4 border-2 border-[#e5e5e5] rounded hover:border-[#4C4CFF] transition-colors space-y-3"
                  >
                    {/* Field Header with controls */}
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-medium text-[#666666]">Field #{index + 1}</span>
                        <div className="flex gap-1">
                          <button
                            onClick={() => handleMoveField(index, 'up')}
                            disabled={index === 0}
                            className="p-1 text-[#666666] hover:text-[#4C4CFF] disabled:opacity-30"
                          >
                            <ArrowUp className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleMoveField(index, 'down')}
                            disabled={index === fields.length - 1}
                            className="p-1 text-[#666666] hover:text-[#4C4CFF] disabled:opacity-30"
                          >
                            <ArrowDown className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                      <button
                        onClick={() => handleRemoveField(index)}
                        className="p-1 text-[#F44336] hover:bg-[#FFEBEE] rounded"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>

                    {/* Field Configuration */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                      {/* Field Name */}
                      <div>
                        <label className="block text-xs font-medium text-[#666666] mb-1">
                          Field Name *
                        </label>
                        <input
                          type="text"
                          value={field.fieldName}
                          onChange={(e) => handleFieldChange(index, 'fieldName', e.target.value)}
                          className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                          placeholder="e.g., Aadhaar Number"
                        />
                      </div>

                      {/* Field Type */}
                      <div>
                        <label className="block text-xs font-medium text-[#666666] mb-1">
                          Field Type *
                        </label>
                        <div className="relative">
                          <select
                            value={field.fieldType}
                            onChange={(e) => {
                              const updatedFields = [...fields];
                              updatedFields[index] = {
                                ...updatedFields[index],
                                fieldType: e.target.value as FieldFormData['fieldType'],
                                ...(e.target.value === 'image' && !updatedFields[index].maxSizeKB
                                  ? { maxSizeKB: 100 }
                                  : {}),
                              };
                              setFields(updatedFields);
                            }}
                            className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF] appearance-none pr-8"
                          >
                            <option value="text">Text</option>
                            <option value="number">Number</option>
                            <option value="dob">Date of Birth</option>
                            <option value="address">Address</option>
                            <option value="mobile">Mobile Number</option>
                            <option value="date">Date</option>
                            <option value="appointment">Appointment</option>
                            <option value="time_range">Time Period</option>
                            <option value="image">Image Upload</option>
                            <option value="pdf">PDF Upload</option>
                            <option value="document">Document Upload</option>
                            <option value="template">Template Upload (Admin)</option>
                          </select>
                          <div className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none">
                            {getFieldTypeIcon(field.fieldType)}
                          </div>
                        </div>
                      </div>

                      {/* Max Image Size — only for image/pdf/document/template types */}
                      {(field.fieldType === 'image' || field.fieldType === 'pdf' || field.fieldType === 'document' || field.fieldType === 'template') && (
                        <div>
                          <label className="block text-xs font-medium text-[#666666] mb-1">
                            Max Image Size (KB)
                          </label>
                          <input
                            type="number"
                            min={100}
                            max={5120}
                            step="100"
                            placeholder="e.g. 1024"
                            value={field.maxSizeKB || 100}
                            onChange={(e) => {
                              const value = Number(e.target.value);
                              if (value < 100) return;
                              handleFieldChange(
                                index,
                                'maxSizeKB' as keyof FieldFormData,
                                value
                              );
                            }}
                            className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                          />
                          <p className="text-xs text-[#999999] mt-1">Minimum 100 KB – Maximum 5120 KB (5 MB)</p>
                        </div>
                      )}

                      {/* Placeholder */}
                      <div>
                        <label className="block text-xs font-medium text-[#666666] mb-1">
                          Placeholder / Hint
                        </label>
                        <input
                          type="text"
                          value={field.placeholder}
                          onChange={(e) => handleFieldChange(index, 'placeholder', e.target.value)}
                          className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                          placeholder="e.g., Enter 12-digit number"
                        />
                      </div>

                      {/* Required */}
                      <div className="flex items-center pt-5">
                        <label className="flex items-center gap-2 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={field.isRequired}
                            onChange={(e) => handleFieldChange(index, 'isRequired', e.target.checked)}
                            className="w-4 h-4 text-[#4C4CFF] border-2 border-[#e5e5e5] rounded focus:ring-2 focus:ring-[#4C4CFF]"
                          />
                          <span className="text-sm text-[#666666]">Required Field</span>
                        </label>
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          {/* Info Note */}
          {selectedServiceId && fields.length > 0 && (
            <div className="mt-4 p-4 bg-[#f5f5f5] border-l-4 border-[#4C4CFF] rounded">
              <p className="text-xs text-[#666666]">
                <strong>💡 Tip:</strong> Fields appear in the app in the order shown above. 
                Image and PDF fields automatically upload to Hostinger when users fill the form.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
