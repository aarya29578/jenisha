import { useState, useEffect } from 'react';
import {
  Plus, Edit, Trash2, Calendar, CheckCircle, XCircle,
  Clock, ToggleLeft, ToggleRight, Filter, RefreshCw
} from 'lucide-react';
import { initializeApp, getApps } from 'firebase/app';
import {
  getFirestore,
  collection,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  onSnapshot,
  serverTimestamp,
  query,
  orderBy,
} from 'firebase/firestore';

// ── Firebase (same config used across admin pages) ───────────────────────────
const firebaseConfig = {
  apiKey: 'AIzaSyC72UmM3pMwRBh0pKjKy_jN9wmpE_MP_GM',
  authDomain: 'jenisha-46c62.firebaseapp.com',
  projectId: 'jenisha-46c62',
  storageBucket: 'jenisha-46c62.appspot.com',
  messagingSenderId: '245020879102',
  appId: '1:245020879102:web:05969fe2820677483c9daf',
};
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
const db = getFirestore(app);

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

interface AppointmentService {
  id: string;
  name: string;
  description: string;
  price: number;
  isActive: boolean;
  createdAt?: any;
}

interface Appointment {
  id: string;
  userId: string;
  userName: string;
  phone: string;
  appointmentServiceId: string;
  appointmentServiceName: string;
  date: string;
  time: string;
  status: 'pending' | 'approved' | 'rejected';
  formData?: Record<string, unknown>;
  createdAt?: any;
}

interface AppointmentField {
  id: string;
  label: string;
  type: 'text' | 'number' | 'date';
  required: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, { bg: string; text: string; label: string }> = {
    pending:  { bg: 'bg-yellow-500/15', text: 'text-yellow-400', label: '🕐 Pending' },
    approved: { bg: 'bg-green-500/15',  text: 'text-green-400',  label: '✅ Approved' },
    rejected: { bg: 'bg-red-500/15',    text: 'text-red-400',    label: '❌ Rejected' },
  };
  const s = map[status] ?? map['pending'];
  return (
    <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold ${s.bg} ${s.text}`}>
      {s.label}
    </span>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Component
// ─────────────────────────────────────────────────────────────────────────────

export default function AppointmentManagement() {
  const [activeTab, setActiveTab] = useState<'services' | 'fields' | 'bookings'>('services');

  // ── Appointment Services state ───────────────────────────────────────────
  const [services, setServices] = useState<AppointmentService[]>([]);
  const [servicesLoading, setServicesLoading] = useState(true);
  const [showAddService, setShowAddService] = useState(false);
  const [editService, setEditService] = useState<AppointmentService | null>(null);
  const [newServiceForm, setNewServiceForm] = useState({
    name: '', description: '', price: 0, isActive: true,
  });
  const [serviceFormError, setServiceFormError] = useState('');
  const [serviceSubmitting, setServiceSubmitting] = useState(false);

  // ── Appointments state ───────────────────────────────────────────────────
  const [appointments, setAppointments] = useState<Appointment[]>([]);
  const [appointmentsLoading, setAppointmentsLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState<'all' | 'pending' | 'approved' | 'rejected'>('all');
  const [updatingId, setUpdatingId] = useState<string | null>(null);

  // ── Realtime listeners ───────────────────────────────────────────────────

  useEffect(() => {
    const q = query(collection(db, 'appointment_services'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      setServices(snap.docs.map(d => ({ id: d.id, ...(d.data() as Omit<AppointmentService, 'id'>) })));
      setServicesLoading(false);
    }, (err) => {
      console.error('appointment_services error:', err);
      setServicesLoading(false);
    });
    return () => unsub();
  }, []);

  useEffect(() => {
    const q = query(collection(db, 'appointments'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      setAppointments(snap.docs.map(d => ({ id: d.id, ...(d.data() as Omit<Appointment, 'id'>) })));
      setAppointmentsLoading(false);
    }, (err) => {
      console.error('appointments error:', err);
      setAppointmentsLoading(false);
    });
    return () => unsub();
  }, []);
  // ── Field label maps (serviceId → { fieldId: label }) ───────────────────
  const [fieldLabelMaps, setFieldLabelMaps] = useState<Record<string, Record<string, string>>>({});

  useEffect(() => {
    const uniqueServiceIds = [...new Set(appointments.map(a => a.appointmentServiceId).filter(Boolean))];
    const missing = uniqueServiceIds.filter(id => !fieldLabelMaps[id]);
    if (missing.length === 0) return;

    missing.forEach(async (serviceId) => {
      try {
        const snap = await getDoc(doc(db, 'appointment_fields', serviceId));
        const map: Record<string, string> = {};
        if (snap.exists()) {
          ((snap.data().fields ?? []) as { id: string; label: string }[]).forEach(f => {
            map[f.id] = f.label;
          });
        }
        setFieldLabelMaps(prev => ({ ...prev, [serviceId]: map }));
      } catch {
        setFieldLabelMaps(prev => ({ ...prev, [serviceId]: {} }));
      }
    });
  }, [appointments]);
  // ── Appointment Fields state ──────────────────────────────────────────────
  const [selectedFieldsServiceId, setSelectedFieldsServiceId] = useState<string>('');
  const [appointmentFields, setAppointmentFields] = useState<AppointmentField[]>([]);
  const [fieldsLoading, setFieldsLoading] = useState(false);
  const [fieldsSaving, setFieldsSaving] = useState(false);
  const [fieldsError, setFieldsError] = useState('');

  useEffect(() => {
    if (!selectedFieldsServiceId) { setAppointmentFields([]); return; }
    setFieldsLoading(true);
    const unsub = onSnapshot(doc(db, 'appointment_fields', selectedFieldsServiceId), (snap) => {
      setAppointmentFields(snap.exists() ? ((snap.data()!.fields ?? []) as AppointmentField[]) : []);
      setFieldsLoading(false);
    });
    return () => unsub();
  }, [selectedFieldsServiceId]);

  const saveAppointmentFields = async () => {
    if (!selectedFieldsServiceId) return;
    setFieldsSaving(true);
    setFieldsError('');
    try {
      await setDoc(doc(db, 'appointment_fields', selectedFieldsServiceId), { fields: appointmentFields });
    } catch (e) {
      setFieldsError('Save failed. Please try again.');
    } finally {
      setFieldsSaving(false);
    }
  };

  // ── Service CRUD ─────────────────────────────────────────────────────────

  const resetServiceForm = () => {
    setNewServiceForm({ name: '', description: '', price: 0, isActive: true });
    setServiceFormError('');
    setShowAddService(false);
    setEditService(null);
  };

  const handleAddService = async () => {
    if (!newServiceForm.name.trim()) {
      setServiceFormError('Service name is required.');
      return;
    }
    setServiceSubmitting(true);
    try {
      await addDoc(collection(db, 'appointment_services'), {
        name: newServiceForm.name.trim(),
        description: newServiceForm.description.trim(),
        price: Number(newServiceForm.price),
        isActive: newServiceForm.isActive,
        createdAt: serverTimestamp(),
      });
      resetServiceForm();
    } catch (e) {
      setServiceFormError('Failed to add service. Please try again.');
      console.error(e);
    } finally {
      setServiceSubmitting(false);
    }
  };

  const handleUpdateService = async () => {
    if (!editService) return;
    if (!newServiceForm.name.trim()) {
      setServiceFormError('Service name is required.');
      return;
    }
    setServiceSubmitting(true);
    try {
      await updateDoc(doc(db, 'appointment_services', editService.id), {
        name: newServiceForm.name.trim(),
        description: newServiceForm.description.trim(),
        price: Number(newServiceForm.price),
        isActive: newServiceForm.isActive,
      });
      resetServiceForm();
    } catch (e) {
      setServiceFormError('Failed to update service.');
      console.error(e);
    } finally {
      setServiceSubmitting(false);
    }
  };

  const handleDeleteService = async (serviceId: string) => {
    if (!window.confirm('Delete this appointment service? This cannot be undone.')) return;
    try {
      await deleteDoc(doc(db, 'appointment_services', serviceId));
    } catch (e) {
      console.error('Delete error:', e);
    }
  };

  const handleToggleActive = async (service: AppointmentService) => {
    try {
      await updateDoc(doc(db, 'appointment_services', service.id), {
        isActive: !service.isActive,
      });
    } catch (e) {
      console.error('Toggle error:', e);
    }
  };

  const openEditService = (service: AppointmentService) => {
    setEditService(service);
    setNewServiceForm({
      name: service.name,
      description: service.description,
      price: service.price,
      isActive: service.isActive,
    });
    setServiceFormError('');
    setShowAddService(false);
  };

  // ── Appointment status actions ───────────────────────────────────────────

  const handleUpdateStatus = async (apptId: string, status: 'approved' | 'rejected') => {
    setUpdatingId(apptId);
    try {
      await updateDoc(doc(db, 'appointments', apptId), { status });
    } catch (e) {
      console.error('Status update error:', e);
    } finally {
      setUpdatingId(null);
    }
  };

  // ── Filtered appointments ─────────────────────────────────────────────────

  const filteredAppointments = filterStatus === 'all'
    ? appointments
    : appointments.filter(a => a.status === filterStatus);

  // ─────────────────────────────────────────────────────────────────────────
  // Render
  // ─────────────────────────────────────────────────────────────────────────

  return (
    <div className="space-y-6">
      {/* Page header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 bg-[#243BFF] rounded-lg flex items-center justify-center shadow">
          <Calendar className="w-5 h-5 text-white" />
        </div>
        <div>
          <h1 className="text-xl font-semibold text-gray-100">Appointment Management</h1>
          <p className="text-sm text-gray-400">Manage appointment types and view bookings</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 border-b border-[#1a2030] flex-wrap">
        {([
          { key: 'services', label: '📋 Appointment Services' },
          { key: 'fields',   label: '🧩 Appointment Fields' },
          { key: 'bookings', label: '📅 Booked Appointments' },
        ] as { key: 'services' | 'fields' | 'bookings'; label: string }[]).map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
              activeTab === tab.key
                ? 'border-[#243BFF] text-[#243BFF]'
                : 'border-transparent text-gray-400 hover:text-gray-200'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* ── TAB 1: Appointment Services ─────────────────────────────────── */}
      {activeTab === 'services' && (
        <div className="space-y-4">
          {/* Add button */}
          <div className="flex justify-between items-center">
            <p className="text-sm text-gray-400">{services.length} service(s)</p>
            <button
              onClick={() => { setShowAddService(true); setEditService(null); setNewServiceForm({ name: '', description: '', price: 0, isActive: true }); setServiceFormError(''); }}
              className="flex items-center gap-2 px-4 py-2 bg-[#243BFF] text-white text-sm font-medium rounded-lg hover:bg-[#1e32e0] transition-colors shadow"
            >
              <Plus className="w-4 h-4" /> Add Service
            </button>
          </div>

          {/* Add / Edit Form */}
          {(showAddService || editService) && (
            <div className="bg-[#0d1320] border border-[#1a2030] rounded-xl p-5 space-y-4">
              <h3 className="text-base font-semibold text-gray-100">
                {editService ? 'Edit Service' : 'New Appointment Service'}
              </h3>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs text-gray-400 mb-1">Service Name *</label>
                  <input
                    type="text"
                    value={newServiceForm.name}
                    onChange={e => setNewServiceForm(f => ({ ...f, name: e.target.value }))}
                    placeholder="e.g. General Consultation"
                    className="w-full px-3 py-2 bg-[#0a0f1a] border border-[#1a2030] rounded-lg text-gray-100 text-sm focus:outline-none focus:border-[#243BFF]"
                  />
                </div>
                <div>
                  <label className="block text-xs text-gray-400 mb-1">Price (₹)</label>
                  <input
                    type="number"
                    min={0}
                    value={newServiceForm.price}
                    onChange={e => setNewServiceForm(f => ({ ...f, price: Number(e.target.value) }))}
                    className="w-full px-3 py-2 bg-[#0a0f1a] border border-[#1a2030] rounded-lg text-gray-100 text-sm focus:outline-none focus:border-[#243BFF]"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs text-gray-400 mb-1">Description</label>
                <textarea
                  value={newServiceForm.description}
                  onChange={e => setNewServiceForm(f => ({ ...f, description: e.target.value }))}
                  rows={2}
                  placeholder="Short description..."
                  className="w-full px-3 py-2 bg-[#0a0f1a] border border-[#1a2030] rounded-lg text-gray-100 text-sm focus:outline-none focus:border-[#243BFF] resize-none"
                />
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setNewServiceForm(f => ({ ...f, isActive: !f.isActive }))}
                  className="flex items-center gap-1.5 text-sm"
                >
                  {newServiceForm.isActive ? (
                    <ToggleRight className="w-5 h-5 text-green-400" />
                  ) : (
                    <ToggleLeft className="w-5 h-5 text-gray-500" />
                  )}
                  <span className={newServiceForm.isActive ? 'text-green-400' : 'text-gray-500'}>
                    {newServiceForm.isActive ? 'Active' : 'Inactive'}
                  </span>
                </button>
              </div>

              {serviceFormError && (
                <p className="text-red-400 text-xs">{serviceFormError}</p>
              )}

              <div className="flex gap-2">
                <button
                  onClick={editService ? handleUpdateService : handleAddService}
                  disabled={serviceSubmitting}
                  className="px-4 py-2 bg-[#243BFF] text-white text-sm font-medium rounded-lg hover:bg-[#1e32e0] disabled:opacity-50 transition-colors"
                >
                  {serviceSubmitting ? (
                    <RefreshCw className="w-4 h-4 animate-spin inline" />
                  ) : editService ? 'Update Service' : 'Add Service'}
                </button>
                <button
                  onClick={resetServiceForm}
                  className="px-4 py-2 bg-[#1a2030] text-gray-300 text-sm rounded-lg hover:bg-[#222840] transition-colors"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          {/* Services list */}
          {servicesLoading ? (
            <div className="flex items-center justify-center py-10">
              <RefreshCw className="w-6 h-6 text-[#243BFF] animate-spin" />
            </div>
          ) : services.length === 0 ? (
            <div className="text-center py-10 text-gray-500">
              <Calendar className="w-12 h-12 mx-auto mb-3 opacity-30" />
              <p>No appointment services yet. Add one above.</p>
            </div>
          ) : (
            <div className="grid gap-3">
              {services.map(service => (
                <div
                  key={service.id}
                  className="bg-[#0d1320] border border-[#1a2030] rounded-xl p-4 flex items-center justify-between gap-3"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="w-10 h-10 bg-[#243BFF]/15 rounded-lg flex items-center justify-center flex-shrink-0">
                      <Calendar className="w-5 h-5 text-[#243BFF]" />
                    </div>
                    <div className="min-w-0">
                      <p className="text-gray-100 font-medium text-sm truncate">{service.name}</p>
                      {service.description && (
                        <p className="text-gray-400 text-xs truncate">{service.description}</p>
                      )}
                      <p className="text-[#243BFF] text-xs font-semibold mt-0.5">
                        {service.price > 0 ? `₹${service.price}` : 'Free'}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 flex-shrink-0">
                    {/* Active toggle */}
                    <button
                      title={service.isActive ? 'Deactivate' : 'Activate'}
                      onClick={() => handleToggleActive(service)}
                      className="p-1.5 rounded hover:bg-[#1a2030] transition-colors"
                    >
                      {service.isActive ? (
                        <ToggleRight className="w-5 h-5 text-green-400" />
                      ) : (
                        <ToggleLeft className="w-5 h-5 text-gray-500" />
                      )}
                    </button>

                    {/* Status pill */}
                    <span className={`hidden sm:inline-flex px-2 py-0.5 rounded-full text-xs font-medium ${
                      service.isActive
                        ? 'bg-green-500/15 text-green-400'
                        : 'bg-gray-500/15 text-gray-400'
                    }`}>
                      {service.isActive ? 'Active' : 'Inactive'}
                    </span>

                    {/* Edit */}
                    <button
                      onClick={() => openEditService(service)}
                      className="p-1.5 rounded hover:bg-[#1a2030] text-gray-400 hover:text-blue-400 transition-colors"
                      title="Edit"
                    >
                      <Edit className="w-4 h-4" />
                    </button>

                    {/* Delete */}
                    <button
                      onClick={() => handleDeleteService(service.id)}
                      className="p-1.5 rounded hover:bg-[#1a2030] text-gray-400 hover:text-red-400 transition-colors"
                      title="Delete"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* ── TAB 2: Appointment Fields ────────────────────────────────────── */}
      {activeTab === 'fields' && (
        <div className="space-y-4">
          {/* Service selector */}
          <div>
            <label className="block text-xs text-gray-400 mb-2">Select a service to manage its fields</label>
            <div className="flex flex-wrap gap-2">
              {services.map(s => (
                <button
                  key={s.id}
                  onClick={() => setSelectedFieldsServiceId(s.id)}
                  className={`px-3 py-1.5 text-xs rounded-lg border transition-colors ${
                    selectedFieldsServiceId === s.id
                      ? 'bg-[#243BFF] border-[#243BFF] text-white'
                      : 'border-[#1a2030] text-gray-400 hover:text-gray-200'
                  }`}
                >
                  {s.name}
                </button>
              ))}
            </div>
          </div>

          {selectedFieldsServiceId && (
            <>
              <div className="flex justify-between items-center">
                <p className="text-sm text-gray-300 font-medium">
                  Fields for: <span className="text-[#243BFF]">{services.find(s => s.id === selectedFieldsServiceId)?.name}</span>
                </p>
                <button
                  onClick={() => setAppointmentFields(f => [
                    ...f,
                    { id: crypto.randomUUID(), label: '', type: 'text', required: true },
                  ])}
                  className="flex items-center gap-1 px-3 py-1.5 bg-[#243BFF] text-white text-xs rounded-lg hover:bg-[#1e32e0]"
                >
                  <Plus className="w-3 h-3" /> Add Field
                </button>
              </div>

              {fieldsLoading ? (
                <div className="flex items-center justify-center py-8">
                  <RefreshCw className="w-5 h-5 text-[#243BFF] animate-spin" />
                </div>
              ) : appointmentFields.length === 0 ? (
                <p className="text-gray-500 text-sm text-center py-8">No fields yet. Click "Add Field" to create one.</p>
              ) : (
                <div className="space-y-3">
                  {appointmentFields.map((field, i) => (
                    <div key={field.id} className="bg-[#0d1320] border border-[#1a2030] rounded-xl p-4 space-y-3">
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                        <div>
                          <label className="block text-xs text-gray-400 mb-1">Label *</label>
                          <input
                            value={field.label}
                            onChange={e => {
                              const copy = [...appointmentFields];
                              copy[i] = { ...copy[i], label: e.target.value };
                              setAppointmentFields(copy);
                            }}
                            placeholder="e.g. Full Name"
                            className="w-full px-3 py-2 bg-[#0a0f1a] border border-[#1a2030] rounded-lg text-gray-100 text-sm focus:outline-none focus:border-[#243BFF]"
                          />
                        </div>
                        <div>
                          <label className="block text-xs text-gray-400 mb-1">Type</label>
                          <select
                            value={field.type}
                            onChange={e => {
                              const copy = [...appointmentFields];
                              copy[i] = { ...copy[i], type: e.target.value as AppointmentField['type'] };
                              setAppointmentFields(copy);
                            }}
                            className="w-full px-3 py-2 bg-[#0a0f1a] border border-[#1a2030] rounded-lg text-gray-100 text-sm focus:outline-none focus:border-[#243BFF]"
                          >
                            <option value="text">Text</option>
                            <option value="number">Number</option>
                            <option value="date">Date</option>
                          </select>
                        </div>
                        <div className="flex items-end gap-3">
                          <label className="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={field.required}
                              onChange={e => {
                                const copy = [...appointmentFields];
                                copy[i] = { ...copy[i], required: e.target.checked };
                                setAppointmentFields(copy);
                              }}
                              className="accent-[#243BFF] w-4 h-4"
                            />
                            Required
                          </label>
                          <button
                            onClick={() => setAppointmentFields(f => f.filter((_, fi) => fi !== i))}
                            className="p-1.5 text-red-400 hover:bg-red-500/15 rounded transition-colors"
                            title="Delete field"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>

                    </div>
                  ))}
                </div>
              )}

              {fieldsError && <p className="text-red-400 text-xs mt-1">{fieldsError}</p>}

              <button
                onClick={saveAppointmentFields}
                disabled={fieldsSaving}
                className="flex items-center gap-2 px-5 py-2 bg-[#243BFF] text-white text-sm font-medium rounded-lg hover:bg-[#1e32e0] disabled:opacity-50 transition-colors"
              >
                {fieldsSaving ? <RefreshCw className="w-4 h-4 animate-spin" /> : null}
                💾 Save Fields
              </button>
            </>
          )}
        </div>
      )}

      {/* ── TAB 3: Booked Appointments ──────────────────────────────────── */}
      {activeTab === 'bookings' && (
        <div className="space-y-4">
          {/* Filter bar */}
          <div className="flex items-center gap-2 flex-wrap">
            <Filter className="w-4 h-4 text-gray-400" />
            {(['all', 'pending', 'approved', 'rejected'] as const).map(s => (
              <button
                key={s}
                onClick={() => setFilterStatus(s)}
                className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors capitalize ${
                  filterStatus === s
                    ? 'bg-[#243BFF] text-white'
                    : 'bg-[#0d1320] text-gray-400 hover:text-gray-200 border border-[#1a2030]'
                }`}
              >
                {s === 'all' ? 'All' : s.charAt(0).toUpperCase() + s.slice(1)}
                {s !== 'all' && (
                  <span className="ml-1 opacity-70">
                    ({appointments.filter(a => a.status === s).length})
                  </span>
                )}
                {s === 'all' && <span className="ml-1 opacity-70">({appointments.length})</span>}
              </button>
            ))}
          </div>

          {/* Appointments list */}
          {appointmentsLoading ? (
            <div className="flex items-center justify-center py-10">
              <RefreshCw className="w-6 h-6 text-[#243BFF] animate-spin" />
            </div>
          ) : filteredAppointments.length === 0 ? (
            <div className="text-center py-10 text-gray-500">
              <Clock className="w-12 h-12 mx-auto mb-3 opacity-30" />
              <p>No appointments found{filterStatus !== 'all' ? ` with status "${filterStatus}"` : ''}.</p>
            </div>
          ) : (
            <div className="grid gap-3">
              {filteredAppointments.map(appt => (
                <div
                  key={appt.id}
                  className="bg-[#0d1320] border border-[#1a2030] rounded-xl p-4"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="space-y-1 min-w-0">
                      <p className="text-gray-100 font-semibold text-sm">{appt.appointmentServiceName}</p>
                      <div className="flex flex-wrap gap-x-4 gap-y-0.5 text-xs text-gray-400">
                        <span>👤 {appt.userName}</span>
                        <span>📞 {appt.phone}</span>
                      </div>
                      <div className="flex flex-wrap gap-x-4 gap-y-0.5 text-xs text-gray-400">
                        <span>📅 {appt.date}</span>
                        <span>🕐 {appt.time}</span>
                      </div>
                    </div>
                    <StatusBadge status={appt.status} />
                  </div>

                  {/* Form Data */}
                  {appt.formData && Object.keys(appt.formData).length > 0 && (
                    <div className="mt-3 p-3 bg-[#0a0f1a] border border-[#1a2030] rounded-lg">
                      <p className="text-xs font-semibold text-gray-300 mb-2">📋 Form Details</p>
                      <div className="space-y-1">
                        {Object.entries(appt.formData).map(([key, value]) => {
                          const label = fieldLabelMaps[appt.appointmentServiceId]?.[key] || key;
                          return (
                            <div key={key} className="text-xs text-gray-400">
                              <span className="font-medium text-gray-300">{label}:</span>{' '}
                              {String(value)}
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )}

                  {/* Action buttons (only for pending) */}
                  {appt.status === 'pending' && (
                    <div className="flex gap-2 mt-3 pt-3 border-t border-[#1a2030]">
                      <button
                        disabled={updatingId === appt.id}
                        onClick={() => handleUpdateStatus(appt.id, 'approved')}
                        className="flex items-center gap-1.5 px-3 py-1.5 bg-green-500/15 text-green-400 text-xs font-medium rounded-lg hover:bg-green-500/25 disabled:opacity-50 transition-colors"
                      >
                        {updatingId === appt.id ? (
                          <RefreshCw className="w-3 h-3 animate-spin" />
                        ) : (
                          <CheckCircle className="w-3 h-3" />
                        )}
                        Approve
                      </button>
                      <button
                        disabled={updatingId === appt.id}
                        onClick={() => handleUpdateStatus(appt.id, 'rejected')}
                        className="flex items-center gap-1.5 px-3 py-1.5 bg-red-500/15 text-red-400 text-xs font-medium rounded-lg hover:bg-red-500/25 disabled:opacity-50 transition-colors"
                      >
                        {updatingId === appt.id ? (
                          <RefreshCw className="w-3 h-3 animate-spin" />
                        ) : (
                          <XCircle className="w-3 h-3" />
                        )}
                        Reject
                      </button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
