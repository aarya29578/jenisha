import { useState, useEffect } from 'react';
import { Plus, Trash2, ArrowUp, ArrowDown, FileText, Loader, AlertCircle } from 'lucide-react';
import { serviceManagementService, documentRequirementsService, Service, ServiceWithCategory, DocumentRequirement } from '../../../services/categoryService';

export default function DocumentRequirements() {
  const [selectedServiceId, setSelectedServiceId] = useState<string>('');
  const [selectedServiceName, setSelectedServiceName] = useState<string>('');
  const [selectedCategoryName, setSelectedCategoryName] = useState<string>('');
  const [services, setServices] = useState<ServiceWithCategory[]>([]);
  const [documents, setDocuments] = useState<DocumentRequirement[]>([]);
  const [showAddDocument, setShowAddDocument] = useState(false);
  const [loading, setLoading] = useState(true);
  const [servicesLoading, setServicesLoading] = useState(true);
  const [newDocName, setNewDocName] = useState('');
  const [newDocRequired, setNewDocRequired] = useState('required');
  const [newDocType, setNewDocType] = useState('');
  const [newDocMaxSizeKB, setNewDocMaxSizeKB] = useState<number | ''>('');
  const [error, setError] = useState<string>('');

  // Load all active services on mount
  useEffect(() => {
    setServicesLoading(true);
    setError('');
    
    console.log('📋 DocumentRequirements: Loading active services...');
    
    const unsubscribe = serviceManagementService.subscribeToActiveServices(
      (loadedServices) => {
        console.log('✅ Services loaded:', {
          count: loadedServices.length,
          services: loadedServices.map(s => ({ 
            id: s.id, 
            name: s.name, 
            categoryName: s.categoryName
          }))
        });
        setServices(loadedServices);
        
        // Auto-select first service if available
        if (loadedServices.length > 0 && !selectedServiceId) {
          const firstService = loadedServices[0];
          console.log('🔄 Auto-selecting first service:', firstService.name);
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

  // Load document requirements when service changes
  useEffect(() => {
    if (selectedServiceId) {
      setLoading(true);
      const unsubscribe = documentRequirementsService.subscribeToDocumentRequirementsForService(
        selectedServiceId,
        (loadedDocs) => {
          console.log('📄 Document requirements loaded:', loadedDocs.length);
          setDocuments(loadedDocs);
          setLoading(false);
        },
        (error) => {
          console.error('❌ Error loading documents:', error);
          setError(`Error loading documents: ${error.message}`);
          setLoading(false);
        }
      );

      return unsubscribe;
    }
  }, [selectedServiceId]);

  const handleSelectService = (service: ServiceWithCategory) => {
    console.log('🎯 Selected service:', service);
    setSelectedServiceId(service.id);
    setSelectedServiceName(service.name);
    setSelectedCategoryName(service.categoryName);
    setError('');
  };

  const handleAddDocument = async () => {
    if (!newDocName.trim()) {
      setError('Document name is required');
      return;
    }
    if (newDocType === 'Image Upload' && (newDocMaxSizeKB === '' || Number(newDocMaxSizeKB) < 500)) {
      setError('Please enter a valid Max Image Size between 500 KB and 5120 KB');
      return;
    }

    try {
      await documentRequirementsService.addDocumentRequirement(
        selectedServiceId,
        newDocName,
        newDocRequired === 'required',
        documents.length,
        newDocType || undefined,
        newDocType === 'Image Upload' && newDocMaxSizeKB !== '' ? Number(newDocMaxSizeKB) : undefined
      );
      setNewDocName('');
      setNewDocRequired('required');
      setNewDocType('');
      setNewDocMaxSizeKB('');
      setShowAddDocument(false);
      setError('');
    } catch (err: any) {
      setError(`Error adding document: ${err.message}`);
    }
  };

  const handleDeleteDocument = async (docId: string) => {
    if (window.confirm('Are you sure you want to delete this document requirement?')) {
      try {
        await documentRequirementsService.deleteDocumentRequirement(docId);
        setError('');
      } catch (err: any) {
        setError(`Error deleting document: ${err.message}`);
      }
    }
  };

  const handleMoveDocument = async (docId: string, direction: 'up' | 'down') => {
    const docIndex = documents.findIndex((d) => d.id === docId);
    if (
      (direction === 'up' && docIndex === 0) ||
      (direction === 'down' && docIndex === documents.length - 1)
    ) {
      return;
    }

    const newOrder = direction === 'up' ? docIndex - 1 : docIndex + 1;

    try {
      await documentRequirementsService.updateDocumentRequirement(docId, {
        order: newOrder,
      });
      setError('');
    } catch (err: any) {
      setError(`Error updating document order: ${err.message}`);
    }
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl text-[#1a1a1a] mb-2">Document Requirement Configuration</h1>
        <p className="text-[#666666]">Define required documents for each service</p>
      </div>

      {/* Info Box */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded p-4">
        <div className="flex items-start gap-3">
          <FileText className="w-5 h-5 text-[#4C4CFF] flex-shrink-0 mt-0.5" />
          <div>
            <h3 className="text-sm text-[#1a1a1a] mb-1">Connection to Agent App</h3>
            <p className="text-sm text-[#666666]">
              ONLY admin-defined documents appear as upload slots in the agent app. Agents can see and upload only the documents you configure here.
            </p>
          </div>
        </div>
      </div>

      {/* Error Message */}
      {error && (
        <div className="bg-[#FFEBEE] border-2 border-[#F44336] rounded p-4">
          <p className="text-sm text-[#C62828]">{error}</p>
        </div>
      )}

      {/* 2-Panel Layout: LEFT (Services), RIGHT (Documents) */}
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
                  <div className="flex flex-col gap-3 items-start">
                    <AlertCircle className="w-5 h-5 text-orange-500" />
                    <div>
                      <p className="text-sm font-medium text-[#1a1a1a] mb-2">No services created yet</p>
                      <p className="text-xs text-[#666666] mb-4">
                        Create a service in Service Management to configure its required documents.
                      </p>
                      <a 
                        href="/service-management"
                        className="text-xs text-[#4C4CFF] hover:underline font-medium"
                      >
                        Create Service First →
                      </a>
                    </div>
                  </div>
                </div>
              ) : (
                services.map((service) => (
                  <button
                    key={service.id}
                    onClick={() => handleSelectService(service)}
                    className={`
                      w-full px-5 py-4 text-left border-b-2 border-[#e5e5e5] transition-colors
                      ${selectedServiceId === service.id
                        ? 'bg-[#E8E8FF] border-l-4 border-l-[#4C4CFF] pl-4'
                        : 'hover:bg-[#f9f9f9]'
                      }
                    `}
                  >
                    <h3 className="text-sm font-medium text-[#1a1a1a]">{service.name}</h3>
                    <p className="text-xs text-[#666666] mt-1">{service.categoryName}</p>
                  </button>
                ))
              )}
            </div>
          </div>
        </div>

        {/* RIGHT PANEL: Required Documents */}
        <div className="lg:col-span-2">
          <div className="bg-white border-2 border-[#e5e5e5] rounded">
            {/* Header */}
            <div className="px-5 py-4 border-b-2 border-[#e5e5e5] flex items-center justify-between">
              <h2 className="text-base text-[#1a1a1a]">Required Documents</h2>
              <button
                onClick={() => setShowAddDocument(true)}
                disabled={!selectedServiceId}
                className="flex items-center gap-2 px-3 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Plus className="w-4 h-4" />
                Add Document
              </button>
            </div>

            {/* Document List */}
            <div className="p-5 space-y-3 max-h-[500px] overflow-y-auto">
              {loading ? (
                <div className="flex justify-center py-8">
                  <Loader className="w-5 h-5 text-[#4C4CFF] animate-spin" />
                </div>
              ) : !selectedServiceId ? (
                <div className="text-center py-12">
                  <FileText className="w-8 h-8 text-[#999999] mx-auto mb-3" />
                  <p className="text-sm text-[#666666]">
                    Select a service to view and manage its required documents
                  </p>
                </div>
              ) : documents.length === 0 ? (
                <div className="text-center py-12">
                  <FileText className="w-8 h-8 text-[#999999] mx-auto mb-3" />
                  <p className="text-sm text-[#666666]">
                    No document requirements configured yet
                  </p>
                </div>
              ) : (
                documents
                  .sort((a, b) => (a.order || 0) - (b.order || 0))
                  .map((doc, index) => (
                    <div
                      key={doc.id}
                      className="flex items-center justify-between p-4 border-2 border-[#e5e5e5] rounded hover:border-[#4C4CFF] transition-colors"
                    >
                      <div className="flex items-center gap-4 flex-1">
                        {/* Reorder Controls */}
                        <div className="flex flex-col gap-1">
                          <button
                            onClick={() => handleMoveDocument(doc.id, 'up')}
                            disabled={index === 0}
                            className="p-1 text-[#666666] hover:text-[#4C4CFF] disabled:opacity-30 disabled:cursor-not-allowed"
                            title="Move Up"
                          >
                            <ArrowUp className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleMoveDocument(doc.id, 'down')}
                            disabled={index === documents.length - 1}
                            className="p-1 text-[#666666] hover:text-[#4C4CFF] disabled:opacity-30 disabled:cursor-not-allowed"
                            title="Move Down"
                          >
                            <ArrowDown className="w-4 h-4" />
                          </button>
                        </div>

                        {/* Document Details */}
                        <div className="flex-1">
                          <h3 className="text-sm font-medium text-[#1a1a1a]">{doc.documentName}</h3>
                          <div className="flex items-center flex-wrap gap-2 mt-2">
                            <span className="text-xs text-[#999999]">#{doc.order || 0}</span>
                            <span
                              className={`text-xs px-2 py-1 rounded font-medium ${
                                doc.required
                                  ? 'bg-[#E8F5E9] text-[#4CAF50]'
                                  : 'bg-[#F5F5F5] text-[#666666]'
                              }`}
                            >
                              {doc.required ? 'Required' : 'Optional'}
                            </span>
                            {doc.type && (
                              <span className="text-xs px-2 py-1 rounded font-medium bg-[#E8E8FF] text-[#4C4CFF]">
                                {doc.type}
                              </span>
                            )}
                            {doc.type === 'Image Upload' && doc.maxSizeKB != null && (
                              <span className="text-xs px-2 py-1 rounded font-medium bg-[#FFF8E1] text-[#F57C00]">
                                Max {doc.maxSizeKB} KB
                              </span>
                            )}
                          </div>
                        </div>
                      </div>

                      {/* Delete Button */}
                      <button
                        onClick={() => handleDeleteDocument(doc.id)}
                        className="p-2 text-[#F44336] hover:bg-[#FFEBEE] rounded transition-colors"
                        title="Delete"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  ))
              )}
            </div>

            {/* Add Document Form */}
            {showAddDocument && selectedServiceId && (
              <div className="px-5 pb-5">
                <div className="p-4 border-2 border-[#4C4CFF] rounded space-y-4 bg-[#f9f9ff]">
                  <h3 className="text-sm font-medium text-[#1a1a1a]">Add Document Requirement</h3>
                  
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-medium text-[#666666] mb-2">
                        Document Name
                      </label>
                      <input
                        type="text"
                        value={newDocName}
                        onChange={(e) => setNewDocName(e.target.value)}
                        className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm focus:outline-none focus:border-[#4C4CFF]"
                        placeholder="e.g., Passport Photo"
                      />
                    </div>
                    
                    <div>
                      <label className="block text-xs font-medium text-[#666666] mb-2">
                        Requirement Type
                      </label>
                      <select
                        value={newDocRequired}
                        onChange={(e) => setNewDocRequired(e.target.value)}
                        className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm focus:outline-none focus:border-[#4C4CFF]"
                      >
                        <option value="required">Required</option>
                        <option value="optional">Optional</option>
                      </select>
                    </div>

                    <div>
                      <label className="block text-xs font-medium text-[#666666] mb-2">
                        Field Type
                      </label>
                      <select
                        value={newDocType}
                        onChange={(e) => {
                          setNewDocType(e.target.value);
                          if (e.target.value !== 'Image Upload') setNewDocMaxSizeKB('');
                        }}
                        className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm focus:outline-none focus:border-[#4C4CFF]"
                      >
                        <option value="">-- Select Type --</option>
                        <option value="Image Upload">Image Upload</option>
                        <option value="PDF Upload">PDF Upload</option>
                        <option value="Text">Text</option>
                        <option value="Number">Number</option>
                        <option value="Date">Date</option>
                      </select>
                    </div>

                    {newDocType === 'Image Upload' && (
                      <div>
                        <label className="block text-xs font-medium text-[#666666] mb-2">
                          Max Image Size (KB)
                        </label>
                        <input
                          type="number"
                          min="500"
                          max="5120"
                          step="100"
                          value={newDocMaxSizeKB}
                          onChange={(e) =>
                            setNewDocMaxSizeKB(e.target.value === '' ? '' : Number(e.target.value))
                          }
                          className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm focus:outline-none focus:border-[#4C4CFF]"
                          placeholder="e.g. 1024"
                        />
                        <p className="text-xs text-[#999999] mt-1">500 KB – 5120 KB (5 MB)</p>
                      </div>
                    )}
                  </div>
                  
                  <div className="flex gap-2 pt-2">
                    <button
                      onClick={handleAddDocument}
                      className="px-4 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors text-sm font-medium"
                    >
                      Add Document
                    </button>
                    <button
                      onClick={() => setShowAddDocument(false)}
                      className="px-4 py-2 border-2 border-[#e5e5e5] text-[#666666] rounded hover:bg-[#f5f5f5] transition-colors text-sm"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Info Note */}
          <div className="mt-4 p-4 bg-[#f5f5f5] border-l-4 border-[#4C4CFF] rounded">
            <p className="text-xs text-[#666666]">
              <strong>💡 Tip:</strong> Documents appear in the agent app upload form in the order you set here. Use the arrow buttons to reorder.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
