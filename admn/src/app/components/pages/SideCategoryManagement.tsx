import { useState, useEffect, useRef } from 'react';
import { Plus, Edit, Trash2, Layers, X, ChevronDown, ChevronUp, FolderTree } from 'lucide-react';
import { sideCategoryService, categoryService, SideCategory, ServiceCategory } from '../../../services/categoryService';

export default function SideCategoryManagement() {
  const [sideCategories, setSideCategories] = useState<SideCategory[]>([]);
  const [loading, setLoading] = useState(true);

  // ── Add form state ─────────────────────────────────────────────────────────
  const [showAdd, setShowAdd] = useState(false);
  const [addName, setAddName] = useState('');
  const [addLogoFile, setAddLogoFile] = useState<File | null>(null);
  const [addLogoPreview, setAddLogoPreview] = useState<string | null>(null);
  const [addSaving, setAddSaving] = useState(false);
  const addLogoRef = useRef<HTMLInputElement>(null);

  // ── Edit form state ────────────────────────────────────────────────────────
  const [editItem, setEditItem] = useState<SideCategory | null>(null);
  const [editName, setEditName] = useState('');
  const [editLogoFile, setEditLogoFile] = useState<File | null>(null);
  const [editLogoPreview, setEditLogoPreview] = useState<string | null>(null);
  const [editSaving, setEditSaving] = useState(false);
  const editLogoRef = useRef<HTMLInputElement>(null);

  // ── Expanded side category + its child categories ────────────────────────
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [childCategories, setChildCategories] = useState<ServiceCategory[]>([]);
  const [childLoading, setChildLoading] = useState(false);
  const [allCategories, setAllCategories] = useState<ServiceCategory[]>([]);

  // ── Add child category state ───────────────────────────────────────────────
  const [showAddChild, setShowAddChild] = useState(false);
  const [selectedChildId, setSelectedChildId] = useState('');
  const [addChildSaving, setAddChildSaving] = useState(false);

  // ── Subscriptions ──────────────────────────────────────────────────────────
  useEffect(() => {
    setLoading(true);
    const unsub = sideCategoryService.subscribeToSideCategories(
      (items) => { setSideCategories(items); setLoading(false); },
      (err) => { console.error(err); setLoading(false); }
    );
    return () => unsub();
  }, []);

  // Subscribe to ALL active categories once
  useEffect(() => {
    const unsub = categoryService.subscribeToCategories(
      (all) => setAllCategories(all.filter(c => c.isActive)),
      (err) => console.error(err)
    );
    return () => unsub();
  }, []);

  // Subscribe to child categories whenever a side category is expanded
  useEffect(() => {
    if (!expandedId) { setChildCategories([]); return; }
    setChildLoading(true);
    const unsub = categoryService.subscribeToCategories(
      (all) => {
        setChildCategories(all.filter(c => c.isActive && c.sideCategoryId === expandedId));
        setChildLoading(false);
      },
      (err) => { console.error(err); setChildLoading(false); }
    );
    return () => unsub();
  }, [expandedId]);

  const toggleExpand = (id: string) => {
    if (expandedId === id) {
      setExpandedId(null);
      setShowAddChild(false);
      setSelectedChildId('');
    } else {
      setExpandedId(id);
      setShowAddChild(false);
      setSelectedChildId('');
    }
  };

  const handleAddChild = async (sideCategoryId: string) => {
    if (!selectedChildId) return;
    setAddChildSaving(true);
    try {
      await categoryService.updateCategory(selectedChildId, { sideCategoryId });
      setSelectedChildId('');
      setShowAddChild(false);
    } catch (err) {
      console.error(err);
      alert('Failed to assign category.');
    } finally {
      setAddChildSaving(false);
    }
  };

  const handleDeleteChild = async (id: string, name: string) => {
    if (!confirm(`Remove category "${name}" from this group?`)) return;
    try {
      await categoryService.updateCategory(id, { sideCategoryId: '' });
    } catch (err) {
      console.error(err);
      alert('Failed to remove.');
    }
  };

  // ── Helpers ────────────────────────────────────────────────────────────────
  const handleLogoFile = (
    file: File,
    setFile: (f: File) => void,
    setPreview: (s: string) => void
  ) => {
    const allowed = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    if (!allowed.includes(file.type)) { alert('Only PNG/JPG/WEBP allowed.'); return; }
    setFile(file);
    const reader = new FileReader();
    reader.onloadend = () => setPreview(reader.result as string);
    reader.readAsDataURL(file);
  };

  // ── Add ────────────────────────────────────────────────────────────────────
  const handleAdd = async () => {
    if (!addName.trim()) return;
    setAddSaving(true);
    try {
      const id = await sideCategoryService.addSideCategory(addName.trim());
      if (addLogoFile) {
        await sideCategoryService.uploadLogo(id, addLogoFile);
      }
      setAddName(''); setAddLogoFile(null); setAddLogoPreview(null);
      setShowAdd(false);
    } catch (err) {
      console.error(err);
      alert('Failed to save. Please try again.');
    } finally {
      setAddSaving(false);
    }
  };

  // ── Edit ───────────────────────────────────────────────────────────────────
  const openEdit = (sc: SideCategory) => {
    setEditItem(sc);
    setEditName(sc.name);
    setEditLogoFile(null);
    setEditLogoPreview(null);
  };

  const handleEdit = async () => {
    if (!editItem || !editName.trim()) return;
    setEditSaving(true);
    try {
      await sideCategoryService.updateSideCategory(editItem.id, { name: editName.trim() });
      if (editLogoFile) {
        await sideCategoryService.uploadLogo(editItem.id, editLogoFile);
      }
      setEditItem(null); setEditLogoFile(null); setEditLogoPreview(null);
    } catch (err) {
      console.error(err);
      alert('Failed to update. Please try again.');
    } finally {
      setEditSaving(false);
    }
  };

  // ── Delete ─────────────────────────────────────────────────────────────────
  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Delete side category "${name}"? This will hide it from the app.`)) return;
    try {
      await sideCategoryService.deleteSideCategory(id);
    } catch (err) {
      console.error(err);
      alert('Failed to delete.');
    }
  };

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl text-gray-100 flex items-center gap-2">
            <Layers className="w-6 h-6 text-[#243BFF]" />
            Side Categories
          </h1>
          <p className="text-sm text-gray-400 mt-1">
            Parent categories shown in the app drawer. Each side category groups
            multiple main categories.
          </p>
        </div>
        <button
          onClick={() => setShowAdd(true)}
          className="flex items-center gap-2 px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] transition-colors text-sm"
        >
          <Plus className="w-4 h-4" />
          Add Side Category
        </button>
      </div>

      {/* Add form */}
      {showAdd && (
        <div className="bg-[#071018] border border-[#111318] rounded p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-base text-gray-100">New Side Category</h3>
            <button onClick={() => { setShowAdd(false); setAddName(''); setAddLogoFile(null); setAddLogoPreview(null); }}>
              <X className="w-5 h-5 text-gray-400 hover:text-gray-200" />
            </button>
          </div>
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-gray-300 mb-1">Name *</label>
              <input
                type="text"
                value={addName}
                onChange={(e) => setAddName(e.target.value)}
                className="w-full px-3 py-2 bg-[#0a0f1a] border border-[#1a2030] rounded text-gray-100 focus:outline-none focus:border-[#243BFF]"
                placeholder="e.g. Finance, Government Services"
              />
            </div>

            {/* Logo upload */}
            <div>
              <label className="block text-sm text-gray-300 mb-1">Logo (optional)</label>
              {addLogoPreview ? (
                <div className="flex items-center gap-3">
                  <img src={addLogoPreview} alt="preview" className="w-16 h-16 object-cover rounded border border-[#1a2030]" />
                  <button
                    type="button"
                    onClick={() => { setAddLogoFile(null); setAddLogoPreview(null); if (addLogoRef.current) addLogoRef.current.value = ''; }}
                    className="text-xs text-red-400 hover:text-red-300"
                  >Remove</button>
                </div>
              ) : (
                <>
                  <input
                    ref={addLogoRef}
                    type="file"
                    accept="image/png,image/jpeg,image/jpg,image/webp"
                    className="hidden"
                    id="add-sc-logo"
                    onChange={(e) => { const f = e.target.files?.[0]; if (f) handleLogoFile(f, setAddLogoFile, setAddLogoPreview); }}
                  />
                  <label htmlFor="add-sc-logo" className="inline-flex items-center gap-2 px-3 py-2 border border-[#1a2030] text-gray-400 rounded hover:bg-[#0f1518] cursor-pointer text-sm">
                    <Plus className="w-4 h-4" /> Choose Image
                  </label>
                </>
              )}
            </div>

            <div className="flex gap-2">
              <button
                onClick={handleAdd}
                disabled={addSaving || !addName.trim()}
                className="px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] disabled:opacity-50 text-sm"
              >
                {addSaving ? 'Saving...' : 'Save'}
              </button>
              <button
                onClick={() => { setShowAdd(false); setAddName(''); setAddLogoFile(null); setAddLogoPreview(null); }}
                className="px-4 py-2 border border-[#1a2030] text-gray-400 rounded hover:bg-[#0f1518] text-sm"
              >Cancel</button>
            </div>
          </div>
        </div>
      )}

      {/* Edit form */}
      {editItem && (
        <div className="bg-[#071018] border border-[#243BFF]/30 rounded p-5">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-base text-gray-100">Edit: {editItem.name}</h3>
            <button onClick={() => setEditItem(null)}>
              <X className="w-5 h-5 text-gray-400 hover:text-gray-200" />
            </button>
          </div>
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-gray-300 mb-1">Name *</label>
              <input
                type="text"
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                className="w-full px-3 py-2 bg-[#0a0f1a] border border-[#1a2030] rounded text-gray-100 focus:outline-none focus:border-[#243BFF]"
              />
            </div>

            {/* Logo upload for edit */}
            <div>
              <label className="block text-sm text-gray-300 mb-1">Replace Logo (optional)</label>
              {editItem.customLogoUrl && !editLogoPreview && (
                <div className="mb-2">
                  <p className="text-xs text-gray-400 mb-1">Current logo:</p>
                  <img src={editItem.customLogoUrl} alt="current" className="w-16 h-16 object-cover rounded border border-[#1a2030]" />
                </div>
              )}
              {editLogoPreview ? (
                <div className="flex items-center gap-3">
                  <img src={editLogoPreview} alt="new preview" className="w-16 h-16 object-cover rounded border border-[#1a2030]" />
                  <button
                    type="button"
                    onClick={() => { setEditLogoFile(null); setEditLogoPreview(null); if (editLogoRef.current) editLogoRef.current.value = ''; }}
                    className="text-xs text-red-400 hover:text-red-300"
                  >Remove new</button>
                </div>
              ) : (
                <>
                  <input
                    ref={editLogoRef}
                    type="file"
                    accept="image/png,image/jpeg,image/jpg,image/webp"
                    className="hidden"
                    id="edit-sc-logo"
                    onChange={(e) => { const f = e.target.files?.[0]; if (f) handleLogoFile(f, setEditLogoFile, setEditLogoPreview); }}
                  />
                  <label htmlFor="edit-sc-logo" className="inline-flex items-center gap-2 px-3 py-2 border border-[#1a2030] text-gray-400 rounded hover:bg-[#0f1518] cursor-pointer text-sm">
                    <Plus className="w-4 h-4" /> Choose New Image
                  </label>
                </>
              )}
            </div>

            <div className="flex gap-2">
              <button
                onClick={handleEdit}
                disabled={editSaving || !editName.trim()}
                className="px-4 py-2 bg-[#243BFF] text-white rounded hover:bg-[#1f33d6] disabled:opacity-50 text-sm"
              >
                {editSaving ? 'Saving...' : 'Update'}
              </button>
              <button
                onClick={() => setEditItem(null)}
                className="px-4 py-2 border border-[#1a2030] text-gray-400 rounded hover:bg-[#0f1518] text-sm"
              >Cancel</button>
            </div>
          </div>
        </div>
      )}

      {/* List */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="w-8 h-8 border-4 border-[#243BFF]/30 border-t-[#243BFF] rounded-full animate-spin" />
        </div>
      ) : sideCategories.length === 0 ? (
        <div className="text-center py-12 bg-[#071018] border border-[#111318] rounded">
          <Layers className="w-12 h-12 text-gray-600 mx-auto mb-3" />
          <p className="text-gray-400">No side categories yet. Add one to get started.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {sideCategories.map((sc) => (
            <div
              key={sc.id}
              className="bg-[#071018] border border-[#111318] rounded-lg overflow-hidden"
            >
              {/* ── Card header ── */}
              <div className="flex items-center gap-4 p-4">
                {/* Logo / icon */}
                <div className="w-10 h-10 rounded-full bg-[#0f243b] flex-shrink-0 overflow-hidden flex items-center justify-center border border-[#1a2030]">
                  {sc.customLogoUrl ? (
                    <img src={sc.customLogoUrl} alt={sc.name} className="w-full h-full object-cover" />
                  ) : (
                    <Layers className="w-5 h-5 text-[#243BFF]" />
                  )}
                </div>

                <div className="flex-1 min-w-0">
                  <p className="text-gray-100 font-medium truncate">{sc.name}</p>
                  <p className="text-xs text-gray-500">
                    {expandedId === sc.id ? `${childCategories.length} categories` : 'Click to manage categories'}
                  </p>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-1 flex-shrink-0">
                  <button
                    onClick={() => openEdit(sc)}
                    className="p-1.5 text-gray-400 hover:text-[#243BFF] hover:bg-[#0f243b] rounded transition-colors"
                    title="Edit side category"
                  >
                    <Edit className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleDelete(sc.id, sc.name)}
                    className="p-1.5 text-gray-400 hover:text-red-400 hover:bg-red-900/20 rounded transition-colors"
                    title="Delete"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => toggleExpand(sc.id)}
                    className="p-1.5 text-gray-400 hover:text-gray-200 hover:bg-[#0f1518] rounded transition-colors"
                    title={expandedId === sc.id ? 'Collapse' : 'Manage categories'}
                  >
                    {expandedId === sc.id
                      ? <ChevronUp className="w-4 h-4" />
                      : <ChevronDown className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {/* ── Expanded: child categories ── */}
              {expandedId === sc.id && (
                <div className="border-t border-[#111318] px-4 pb-4 pt-3 space-y-3">
                  <div className="flex items-center justify-between">
                    <p className="text-xs text-gray-400 uppercase tracking-wider">Categories inside "{sc.name}"</p>
                    <button
                      onClick={() => { setShowAddChild(true); setSelectedChildId(''); }}
                      className="flex items-center gap-1 px-3 py-1 bg-[#243BFF] text-white rounded text-xs hover:bg-[#1f33d6] transition-colors"
                    >
                      <Plus className="w-3 h-3" /> Add Category
                    </button>
                  </div>

                  {/* Add child form */}
                  {showAddChild && (
                    <div className="flex items-center gap-2 bg-[#0a0f1a] border border-[#1a2030] rounded p-3">
                      <select
                        value={selectedChildId}
                        onChange={(e) => setSelectedChildId(e.target.value)}
                        autoFocus
                        className="flex-1 bg-[#0a0f1a] text-gray-100 text-sm focus:outline-none border-none"
                      >
                        <option value="">-- Select a category --</option>
                        {allCategories
                          .filter(c => !c.sideCategoryId || c.sideCategoryId === '')
                          .map(c => (
                            <option key={c.id} value={c.id}>{c.name}</option>
                          ))}
                      </select>
                      <button
                        onClick={() => handleAddChild(sc.id)}
                        disabled={addChildSaving || !selectedChildId}
                        className="px-3 py-1 bg-[#243BFF] text-white rounded text-xs hover:bg-[#1f33d6] disabled:opacity-50"
                      >
                        {addChildSaving ? 'Saving…' : 'Add'}
                      </button>
                      <button
                        onClick={() => { setShowAddChild(false); setSelectedChildId(''); }}
                        className="p-1 text-gray-400 hover:text-gray-200"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  )}

                  {/* Child list */}
                  {childLoading ? (
                    <div className="flex items-center justify-center py-4">
                      <div className="w-5 h-5 border-2 border-[#243BFF]/30 border-t-[#243BFF] rounded-full animate-spin" />
                    </div>
                  ) : childCategories.length === 0 ? (
                    <p className="text-sm text-gray-500 py-2">No categories yet. Add one above.</p>
                  ) : (
                    <div className="space-y-1">
                      {childCategories.map((cat) => (
                        <div key={cat.id} className="flex items-center gap-3 px-3 py-2 bg-[#0a0f1a] rounded border border-[#1a2030]">
                          {cat.customLogoUrl ? (
                            <img src={cat.customLogoUrl} alt={cat.name} className="w-6 h-6 rounded object-cover" />
                          ) : (
                            <FolderTree className="w-4 h-4 text-gray-500 flex-shrink-0" />
                          )}
                          <span className="flex-1 text-sm text-gray-200 truncate">{cat.name}</span>
                          <button
                            onClick={() => handleDeleteChild(cat.id, cat.name)}
                            className="p-1 text-gray-600 hover:text-red-400 rounded transition-colors"
                            title="Remove from this group"
                          >
                            <X className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
