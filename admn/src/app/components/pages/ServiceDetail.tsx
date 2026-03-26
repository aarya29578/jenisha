import { useState, useEffect } from 'react';
import {
  Plus, Trash2, ArrowUp, ArrowDown, FileText, Loader,
  Image, FileInput, Calendar, Hash, Type, ArrowLeft,
  Globe, FileDown, MapPin, Smartphone, FileArchive, Upload, Clock,
} from 'lucide-react';
import { dynamicFieldsService } from '../../../services/categoryService';

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

export interface ServiceRow {
  id: string;
  name: string;
  categoryId: string;
  categoryName: string;
  price?: number;
  logoUrl?: string;
  redirectUrl?: string;
  formTemplateUrl?: string;
  isActive?: boolean;
}

interface FieldFormData {
  fieldName: string;
  fieldType: 'text' | 'number' | 'date' | 'dob' | 'address' | 'mobile' | 'image' | 'pdf' | 'appointment' | 'time_range' | 'document' | 'template';
  isRequired: boolean;
  placeholder: string;
  displayOrder: number;
  maxSizeKB?: number;
  dimension?: string;
}

interface Props {
  service: ServiceRow;
  onBack: () => void;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function FieldTypeIcon({ fieldType }: { fieldType: string }) {
  switch (fieldType) {
    case 'text':       return <Type        className="w-4 h-4" />;
    case 'number':     return <Hash        className="w-4 h-4" />;
    case 'date':       return <Calendar    className="w-4 h-4" />;
    case 'dob':        return <Calendar    className="w-4 h-4" />;
    case 'address':    return <MapPin      className="w-4 h-4" />;
    case 'mobile':     return <Smartphone  className="w-4 h-4" />;
    case 'image':      return <Image       className="w-4 h-4" />;
    case 'pdf':        return <FileInput   className="w-4 h-4" />;
    case 'appointment':  return <Clock     className="w-4 h-4" />;
    case 'time_range':   return <Clock     className="w-4 h-4" />;
    case 'document':   return <FileArchive className="w-4 h-4" />;
    case 'template':   return <Upload      className="w-4 h-4" />;
    default:           return <FileText    className="w-4 h-4" />;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Component
// ─────────────────────────────────────────────────────────────────────────────

export default function ServiceDetail({ service, onBack }: Props) {
  const [fields, setFields] = useState<FieldFormData[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  // ── Load fields ────────────────────────────────────────────────────────────
  useEffect(() => {
    setLoading(true);
    setError('');
    const unsubscribe = dynamicFieldsService.subscribeToServiceDocumentFields(
      service.id,
      (loadedFields) => {
        setFields(
          loadedFields.map((f) => ({
            fieldName:    f.fieldName,
            fieldType:    f.fieldType,
            isRequired:   f.isRequired,
            placeholder:  f.placeholder || '',
            displayOrder: f.displayOrder,
            maxSizeKB:    (f as any).maxSizeKB ?? undefined,
            dimension:    (f as any).dimension  ?? undefined,
          }))
        );
        setLoading(false);
      },
      (err) => {
        setError(`Error loading fields: ${err.message}`);
        setLoading(false);
      }
    );
    return unsubscribe;
  }, [service.id]);

  // ── Field handlers ─────────────────────────────────────────────────────────
  const handleAddField = () => {
    setFields([
      ...fields,
      { fieldName: '', fieldType: 'text', isRequired: true, placeholder: '', displayOrder: fields.length },
    ]);
  };

  const handleRemoveField = (index: number) => {
    const updated = fields.filter((_, i) => i !== index);
    updated.forEach((f, i) => { f.displayOrder = i; });
    setFields(updated);
  };

  const handleMoveField = (index: number, direction: 'up' | 'down') => {
    if ((direction === 'up' && index === 0) || (direction === 'down' && index === fields.length - 1)) return;
    const updated = [...fields];
    const target = direction === 'up' ? index - 1 : index + 1;
    [updated[index], updated[target]] = [updated[target], updated[index]];
    updated.forEach((f, i) => { f.displayOrder = i; });
    setFields(updated);
  };

  const handleFieldChange = (index: number, key: keyof FieldFormData, value: any) => {
    const updated = [...fields];
    updated[index] = { ...updated[index], [key]: value };
    setFields(updated);
  };

  const handleSaveFields = async () => {
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
      await dynamicFieldsService.saveServiceDocumentFields(service.id, fields);
      setSuccessMessage('Document fields saved successfully!');
      setTimeout(() => setSuccessMessage(''), 3000);
    } catch (err: any) {
      setError(`Error saving fields: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      {/* Back + header */}
      <div className="flex items-center gap-3">
        <button
          onClick={onBack}
          className="p-2 text-gray-400 hover:text-gray-100 hover:bg-[#0f1518] rounded transition-colors"
          title="Back to services"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-2xl text-gray-100">{service.name}</h1>
          <p className="text-sm text-gray-400">{service.categoryName}</p>
        </div>
      </div>

      {/* ── Service Info Card ──────────────────────────────────────────────── */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded p-5">
        <h2 className="text-base font-medium text-[#1a1a1a] mb-4">Service Info</h2>
        <div className="flex items-start gap-5">
          {/* Logo */}
          <div className="flex-shrink-0">
            {service.logoUrl ? (
              <img
                src={service.logoUrl}
                alt={service.name}
                className="w-16 h-16 rounded-full object-cover border-2 border-[#e5e5e5]"
              />
            ) : (
              <div className="w-16 h-16 rounded-full bg-[#E8E8FF] flex items-center justify-center">
                <FileText className="w-7 h-7 text-[#4C4CFF]" />
              </div>
            )}
          </div>

          {/* Details grid */}
          <div className="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
            <div>
              <p className="text-xs text-[#999] mb-0.5">Service Name</p>
              <p className="text-[#1a1a1a] font-medium">{service.name}</p>
            </div>
            <div>
              <p className="text-xs text-[#999] mb-0.5">Category</p>
              <p className="text-[#1a1a1a]">{service.categoryName}</p>
            </div>
            <div>
              <p className="text-xs text-[#999] mb-0.5">Service Fee</p>
              <p className="text-[#1a1a1a]">{service.price ? `₹${service.price}` : '—'}</p>
            </div>
            <div>
              <p className="text-xs text-[#999] mb-0.5">Status</p>
              <span
                className={`inline-block px-2 py-0.5 text-xs rounded ${
                  service.isActive
                    ? 'bg-[#E8F5E9] text-[#4CAF50]'
                    : 'bg-[#F5F5F5] text-[#666666]'
                }`}
              >
                {service.isActive ? 'Active' : 'Inactive'}
              </span>
            </div>
            {service.redirectUrl && (
              <div className="sm:col-span-2">
                <p className="text-xs text-[#999] mb-0.5">Redirect URL</p>
                <a
                  href={service.redirectUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 text-xs text-[#4C4CFF] hover:underline"
                >
                  <Globe className="w-3 h-3" />
                  <span className="truncate max-w-xs">{service.redirectUrl}</span>
                </a>
              </div>
            )}
            {service.formTemplateUrl && (
              <div className="sm:col-span-2">
                <p className="text-xs text-[#999] mb-0.5">Form Template</p>
                <a
                  href={service.formTemplateUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1 px-2 py-1 text-xs bg-[#E8E8FF] text-[#4C4CFF] rounded hover:bg-[#d8d8ff] transition-colors w-fit"
                >
                  <FileDown className="w-3 h-3" />
                  Download Template
                </a>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ── Document Fields ────────────────────────────────────────────────── */}
      <div className="bg-white border-2 border-[#e5e5e5] rounded">
        {/* Header */}
        <div className="px-5 py-4 border-b-2 border-[#e5e5e5] flex items-center justify-between">
          <h2 className="text-base font-medium text-[#1a1a1a]">Document Fields</h2>
          <div className="flex gap-2">
            <button
              onClick={handleAddField}
              className="flex items-center gap-2 px-3 py-2 bg-[#4C4CFF] text-white rounded hover:bg-[#3d3dcc] transition-colors text-sm"
            >
              <Plus className="w-4 h-4" />
              Add Field
            </button>
            <button
              onClick={handleSaveFields}
              disabled={fields.length === 0 || saving}
              className="flex items-center gap-2 px-4 py-2 bg-[#16A34A] text-white rounded hover:bg-[#15803D] transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {saving && <Loader className="w-4 h-4 animate-spin" />}
              Save Fields
            </button>
          </div>
        </div>

        {/* Messages */}
        {error && (
          <div className="mx-5 mt-4 p-3 bg-[#FFEBEE] border-2 border-[#F44336] rounded">
            <p className="text-sm text-[#C62828]">{error}</p>
          </div>
        )}
        {successMessage && (
          <div className="mx-5 mt-4 p-3 bg-[#E8F5E9] border-2 border-[#4CAF50] rounded">
            <p className="text-sm text-[#2E7D32]">{successMessage}</p>
          </div>
        )}

        {/* Fields list */}
        <div className="p-5 space-y-4">
          {loading ? (
            <div className="flex justify-center py-8">
              <Loader className="w-5 h-5 text-[#4C4CFF] animate-spin" />
            </div>
          ) : fields.length === 0 ? (
            <div className="text-center py-10">
              <FileText className="w-8 h-8 text-[#ccc] mx-auto mb-3" />
              <p className="text-sm text-[#666666] mb-4">No fields configured yet</p>
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
                {/* Row header */}
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

                {/* Fields grid */}
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
                          const updated = [...fields];
                          updated[index] = {
                            ...updated[index],
                            fieldType: e.target.value as FieldFormData['fieldType'],
                          };
                          setFields(updated);
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
                        <FieldTypeIcon fieldType={field.fieldType} />
                      </div>
                    </div>
                  </div>

                  {/* Image: Max File Size + Required Dimensions (both always visible, both optional) */}
                  {field.fieldType === 'image' && (
                    <>
                      {/* Max File Size (KB) */}
                      <div>
                        <label className="block text-xs font-medium text-[#666666] mb-1">
                          Max File Size (KB) <span className="text-[#aaa] font-normal">(optional)</span>
                        </label>
                        <input
                          type="number"
                          min={0}
                          max={5120}
                          step="100"
                          placeholder="e.g. 500"
                          value={field.maxSizeKB ?? ''}
                          onChange={(e) => {
                            const raw = e.target.value;
                            handleFieldChange(
                              index,
                              'maxSizeKB' as keyof FieldFormData,
                              raw === '' ? undefined : Math.max(0, Number(raw)),
                            );
                          }}
                          className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                        />
                        <p className="text-xs text-[#999] mt-1">Leave blank to skip size check. Max 5120 KB (5 MB).</p>
                      </div>

                      {/* Required Image Dimensions */}
                      <div>
                        <label className="block text-xs font-medium text-[#666666] mb-1">
                          Required Image Dimensions <span className="text-[#aaa] font-normal">(optional)</span>
                        </label>
                        <select
                          value={field.dimension ?? ''}
                          onChange={(e) =>
                            handleFieldChange(
                              index,
                              'dimension' as keyof FieldFormData,
                              e.target.value === '' ? undefined : e.target.value,
                            )
                          }
                          className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                        >
                          <option value="">— No dimension restriction —</option>
                          <option value="3.5x4.5">3.5 cm × 4.5 cm (Passport Size)</option>
                          <option value="213x213">213 × 213 pixels</option>
                        </select>
                        {field.dimension && (
                          <p className="text-xs text-[#999] mt-1">
                            {field.dimension === '213x213'
                              ? 'Image must be exactly 213 × 213 px'
                              : 'Image must be 3.5 cm × 4.5 cm (≈ 413 × 531 px at 300 dpi)'}
                          </p>
                        )}
                      </div>
                    </>
                  )}

                  {/* PDF / Document / Template: Max File Size only */}
                  {(field.fieldType === 'pdf' || field.fieldType === 'document' || field.fieldType === 'template') && (
                    <div>
                      <label className="block text-xs font-medium text-[#666666] mb-1">
                        Max File Size (KB) <span className="text-[#aaa] font-normal">(optional)</span>
                      </label>
                      <input
                        type="number"
                        min={0}
                        max={5120}
                        step="100"
                        placeholder="e.g. 1024"
                        value={field.maxSizeKB ?? ''}
                        onChange={(e) => {
                          const raw = e.target.value;
                          handleFieldChange(
                            index,
                            'maxSizeKB' as keyof FieldFormData,
                            raw === '' ? undefined : Math.max(0, Number(raw)),
                          );
                        }}
                        className="w-full px-3 py-2 border-2 border-[#e5e5e5] rounded text-sm text-[#1a1a1a] focus:outline-none focus:border-[#4C4CFF]"
                      />
                      <p className="text-xs text-[#999] mt-1">Leave blank to skip size check. Max 5120 KB (5 MB).</p>
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

                  {/* Required toggle */}
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

        {fields.length > 0 && (
          <div className="mx-5 mb-5 p-3 bg-[#f5f5f5] border-l-4 border-[#4C4CFF] rounded">
            <p className="text-xs text-[#666666]">
              <strong>Tip:</strong> Fields appear in the app in the order shown above. Image and PDF
              fields automatically upload to Hostinger when users fill the form.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
