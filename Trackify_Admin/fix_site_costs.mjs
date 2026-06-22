import fs from 'fs';

let content = fs.readFileSync('src/pages/SiteCosts.jsx', 'utf8');

// 1. Update imports
content = content.replace(
  `import { addMaterialPurchase, addSiteExpense } from '../lib/services/costs.service';`,
  `import { addMaterialPurchase, addSiteExpense, updateMaterialPurchase, deleteMaterialPurchase, updateSiteExpense, deleteSiteExpense } from '../lib/services/costs.service';`
);

// 2. Add Edit/Delete Icons
content = content.replace(
  `import { Plus, Search, Building2, Package, Banknote, Calendar } from 'lucide-react';`,
  `import { Plus, Search, Building2, Package, Banknote, Calendar, Pencil, Trash2 } from 'lucide-react';`
);

// 3. Update EMPTY_EXPENSE
content = content.replace(
  `const EMPTY_EXPENSE = {
  expenseType: 'Machinery', title: '', amount: '', date: new Date().toISOString().split('T')[0], siteId: '', paidTo: '', remarks: ''
};`,
  `const EMPTY_EXPENSE = {
  expenseType: 'machinery', description: '', amount: '', date: new Date().toISOString().split('T')[0], siteId: '', paidTo: '', remarks: ''
};`
);

// 4. Update component state for editing/deleting
const stateCode = `  const [addExpenseOpen, setAddExpenseOpen] = useState(false);
  const [formM, setFormM] = useState(EMPTY_MATERIAL);
  const [formE, setFormE] = useState(EMPTY_EXPENSE);
  const [saving, setSaving] = useState(false);

  const [editingIdM, setEditingIdM] = useState(null);
  const [editingIdE, setEditingIdE] = useState(null);
  const [deleteConfirm, setDeleteConfirm] = useState(null);`;

content = content.replace(
  `  const [addExpenseOpen, setAddExpenseOpen] = useState(false);
  const [formM, setFormM] = useState(EMPTY_MATERIAL);
  const [formE, setFormE] = useState(EMPTY_EXPENSE);
  const [saving, setSaving] = useState(false);`,
  stateCode
);

// 5. Update filteredExpenses condition from 'title' to 'description'
content = content.replace(
  `if (search && !e.title.toLowerCase().includes(search.toLowerCase())) return false;`,
  `if (search && !e.description.toLowerCase().includes(search.toLowerCase())) return false;`
);

// 6. Update handleSaveMaterial to handle updates
const saveMaterialCode = `  const handleSaveMaterial = async () => {
    if (!formM.materialName || !formM.quantity || !formM.pricePerUnit || !formM.siteId) {
      return toast.error("Please fill in required fields");
    }
    setSaving(true);
    try {
      const q = parseFloat(formM.quantity);
      const p = parseFloat(formM.pricePerUnit);
      const data = {
        ...formM,
        quantity: q,
        pricePerUnit: p,
        totalAmount: q * p,
      };
      if (editingIdM) {
        await updateMaterialPurchase(scopeId, editingIdM, data);
        toast.success("Material updated successfully!");
      } else {
        await addMaterialPurchase(scopeId, data);
        toast.success("Material added successfully!");
      }
      setAddMaterialOpen(false);
      setFormM(EMPTY_MATERIAL);
      setEditingIdM(null);
    } catch (err) {
      toast.error("Failed to save material");
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteMaterial = async (id) => {
    if (deleteConfirm !== id) return setDeleteConfirm(id);
    try {
      await deleteMaterialPurchase(scopeId, id);
      toast.success("Material deleted");
    } catch (e) {
      toast.error("Failed to delete material");
    }
    setDeleteConfirm(null);
  };`;

content = content.replace(
  /  const handleSaveMaterial = async \(\) => {[\s\S]*?  };/,
  saveMaterialCode
);

// 7. Update handleSaveExpense to handle updates
const saveExpenseCode = `  const handleSaveExpense = async () => {
    if (!formE.description || !formE.amount || !formE.siteId) {
      return toast.error("Please fill in required fields");
    }
    setSaving(true);
    try {
      const data = {
        ...formE,
        amount: parseFloat(formE.amount),
      };
      if (editingIdE) {
        await updateSiteExpense(scopeId, editingIdE, data);
        toast.success("Expense updated successfully!");
      } else {
        await addSiteExpense(scopeId, data);
        toast.success("Expense added successfully!");
      }
      setAddExpenseOpen(false);
      setFormE(EMPTY_EXPENSE);
      setEditingIdE(null);
    } catch (err) {
      toast.error("Failed to save expense");
    } finally {
      setSaving(false);
    }
  };

  const handleDeleteExpense = async (id) => {
    if (deleteConfirm !== id) return setDeleteConfirm(id);
    try {
      await deleteSiteExpense(scopeId, id);
      toast.success("Expense deleted");
    } catch (e) {
      toast.error("Failed to delete expense");
    }
    setDeleteConfirm(null);
  };`;

content = content.replace(
  /  const handleSaveExpense = async \(\) => {[\s\S]*?  };/,
  saveExpenseCode
);

// 8. Add table headers for Actions
content = content.replace(
  `<th className="px-4 py-3 text-right">Date</th>
                    </tr>
                  ) : (
                    <tr>
                      <th className="px-4 py-3">Title</th>`,
  `<th className="px-4 py-3 text-right">Date</th>
                      <th className="px-4 py-3 text-right">Actions</th>
                    </tr>
                  ) : (
                    <tr>
                      <th className="px-4 py-3">Title</th>`
);

content = content.replace(
  `<th className="px-4 py-3 text-right">Date</th>
                    </tr>
                  )}`,
  `<th className="px-4 py-3 text-right">Date</th>
                      <th className="px-4 py-3 text-right">Actions</th>
                    </tr>
                  )}`
);

// 9. Update row rendering for Materials
content = content.replace(
  `<td className="px-4 py-3 text-right text-slate-500">{item.purchaseDate}</td>
                        </>`,
  `<td className="px-4 py-3 text-right text-slate-500">{item.purchaseDate}</td>
                          <td className="px-4 py-3 text-right">
                            <div className="flex items-center justify-end gap-2">
                              <button onClick={() => { setFormM(item); setEditingIdM(item.id); setAddMaterialOpen(true); }} className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"><Pencil className="h-3.5 w-3.5" /></button>
                              <button onClick={() => handleDeleteMaterial(item.id)} className={\`rounded-lg p-1.5 transition \${deleteConfirm === item.id ? 'bg-red-600 text-white' : 'text-red-400 hover:bg-red-50 hover:text-red-600'}\`}><Trash2 className="h-3.5 w-3.5" /></button>
                              {deleteConfirm === item.id && <button onClick={() => setDeleteConfirm(null)} className="rounded-lg px-2 py-1 text-xs text-slate-400 hover:bg-slate-100">Cancel</button>}
                            </div>
                          </td>
                        </>`
);

// 10. Update row rendering for Expenses and update 'title' to 'description'
content = content.replace(
  `<td className="px-4 py-3 font-medium text-slate-900">{item.title}</td>`,
  `<td className="px-4 py-3 font-medium text-slate-900">{item.description}</td>`
);

// Handle the expenseType display capitalized
content = content.replace(
  `<td className="px-4 py-3 text-slate-600">{item.expenseType}</td>`,
  `<td className="px-4 py-3 text-slate-600 capitalize">{item.expenseType}</td>`
);

content = content.replace(
  `<td className="px-4 py-3 text-right text-slate-500">{item.date}</td>
                        </>`,
  `<td className="px-4 py-3 text-right text-slate-500">{item.date}</td>
                          <td className="px-4 py-3 text-right">
                            <div className="flex items-center justify-end gap-2">
                              <button onClick={() => { setFormE(item); setEditingIdE(item.id); setAddExpenseOpen(true); }} className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-slate-700"><Pencil className="h-3.5 w-3.5" /></button>
                              <button onClick={() => handleDeleteExpense(item.id)} className={\`rounded-lg p-1.5 transition \${deleteConfirm === item.id ? 'bg-red-600 text-white' : 'text-red-400 hover:bg-red-50 hover:text-red-600'}\`}><Trash2 className="h-3.5 w-3.5" /></button>
                              {deleteConfirm === item.id && <button onClick={() => setDeleteConfirm(null)} className="rounded-lg px-2 py-1 text-xs text-slate-400 hover:bg-slate-100">Cancel</button>}
                            </div>
                          </td>
                        </>`
);

// 11. Update Modals closing logic
content = content.replace(
  `onClose={() => !saving && setAddMaterialOpen(false)}`,
  `onClose={() => { if (!saving) { setAddMaterialOpen(false); setEditingIdM(null); setFormM(EMPTY_MATERIAL); } }}`
);

content = content.replace(
  `onClose={() => !saving && setAddExpenseOpen(false)}`,
  `onClose={() => { if (!saving) { setAddExpenseOpen(false); setEditingIdE(null); setFormE(EMPTY_EXPENSE); } }}`
);

// 12. Update Add Expense Modal fields (title -> description)
content = content.replace(
  `<Label>Expense Title *</Label>
            <Input value={formE.title} onChange={(e) => setFormE({ ...formE, title: e.target.value })} placeholder="e.g. JCB Rental" />`,
  `<Label>Expense Description *</Label>
            <Input value={formE.description} onChange={(e) => setFormE({ ...formE, description: e.target.value })} placeholder="e.g. JCB Rental" />`
);

// 13. Update expenseType dropdown options
content = content.replace(
  `{['Machinery', 'Transport', 'Food', 'Miscellaneous', 'Consultation', 'Legal'].map(c => <option key={c} value={c}>{c}</option>)}`,
  `{[{k: 'machinery', v: 'Machinery'}, {k: 'transport', v: 'Transport'}, {k: 'food', v: 'Food'}, {k: 'misc', v: 'Miscellaneous'}, {k: 'consultation', v: 'Consultation'}, {k: 'legal', v: 'Legal'}].map(c => <option key={c.k} value={c.k}>{c.v}</option>)}`
);

fs.writeFileSync('src/pages/SiteCosts.jsx', content);
