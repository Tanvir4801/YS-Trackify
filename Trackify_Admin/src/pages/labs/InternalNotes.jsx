import React, { useState, useEffect } from 'react';
import { FileText, Plus, X, Save } from 'lucide-react';
import { db } from '../../lib/firebase';
import { collection, onSnapshot, doc, setDoc, updateDoc, serverTimestamp, deleteDoc } from 'firebase/firestore';

const INITIAL_NOTES = [
  { id: '1', title: 'Multi Site Attendance Logic', desc: 'Need to make sure we do not duplicate the labour document when assigning across two sites.' },
  { id: '2', title: 'Subscription Plans', desc: 'Tier 1: Free (1 Site). Tier 2: Pro (Unlimited). Stripe integration in progress.' },
  { id: '3', title: 'Future Modules', desc: 'Consider adding a simple petty cash module for supervisors to log daily tea/snack expenses.' },
  { id: '4', title: 'Known Bugs', desc: 'Sometimes the Firebase offline cache gets stuck on iOS. Need to clear cache on logout.' },
  { id: '5', title: 'Ideas', desc: 'AI-based site safety checks using photos.' },
];

export default function InternalNotes() {
  const [notes, setNotes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [currentNote, setCurrentNote] = useState({ id: null, title: '', desc: '' });

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'lab_internal_notes'), async (snap) => {
      try {
        if (snap.empty) {
          // Seed initial data
          for (const note of INITIAL_NOTES) {
            await setDoc(doc(db, 'lab_internal_notes', note.id), { ...note, createdAt: serverTimestamp() });
          }
          setNotes(INITIAL_NOTES);
        } else {
          setNotes(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        }
        setLoading(false);
      } catch (e) {
        console.error("InternalNotes fetch error:", e);
        setLoading(false);
      }
    }, (error) => {
      console.error("InternalNotes snapshot error:", error);
      setLoading(false);
    });

    return () => unsub();
  }, []);

  const openModal = (note = null) => {
    setCurrentNote(note || { id: null, title: '', desc: '' });
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setCurrentNote({ id: null, title: '', desc: '' });
  };

  const saveNote = async () => {
    if (!currentNote.title.trim()) return;
    try {
      if (currentNote.id) {
        await updateDoc(doc(db, 'lab_internal_notes', currentNote.id), {
          title: currentNote.title,
          desc: currentNote.desc,
          updatedAt: serverTimestamp()
        });
      } else {
        const newRef = doc(collection(db, 'lab_internal_notes'));
        await setDoc(newRef, {
          title: currentNote.title,
          desc: currentNote.desc,
          createdAt: serverTimestamp()
        });
      }
      closeModal();
    } catch (e) {
      console.error("Failed to save note:", e);
    }
  };

  const deleteNote = async (id) => {
    if(confirm('Delete this note?')) {
      try {
        await deleteDoc(doc(db, 'lab_internal_notes', id));
      } catch(e) {
        console.error("Failed to delete note:", e);
      }
    }
  };

  return (
    <div className="space-y-6 max-w-4xl relative">
      <div className="flex items-center justify-between border-b border-[#27272a] pb-4">
        <h1 className="text-2xl font-semibold tracking-wide text-white flex items-center">
          <FileText className="w-6 h-6 mr-3 text-cyan-400" />
          Product Notes
        </h1>
        <button onClick={() => openModal()} className="text-xs flex items-center px-4 py-2 bg-cyan-500/10 border border-cyan-500/30 rounded-lg text-cyan-400 hover:bg-cyan-500/20 transition-colors">
          <Plus className="w-4 h-4 mr-1" /> New Note
        </button>
      </div>

      {loading ? (
        <div className="p-8 text-center text-gray-500 font-mono">Loading notes...</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {notes.map((note) => (
            <div key={note.id} className="bg-[#121214] border border-[#27272a] p-5 rounded-xl group hover:border-[#3f3f46] transition-colors relative">
              <div className="absolute top-0 right-0 p-3 opacity-0 group-hover:opacity-100 transition-opacity flex space-x-2">
                <button onClick={() => openModal(note)} className="text-xs text-gray-500 hover:text-cyan-400">Edit</button>
                <button onClick={() => deleteNote(note.id)} className="text-xs text-gray-500 hover:text-red-400">Del</button>
              </div>
              <h3 className="text-gray-200 font-medium mb-2 pr-12">{note.title}</h3>
              <p className="text-sm text-gray-500 leading-relaxed whitespace-pre-wrap">
                {note.desc}
              </p>
            </div>
          ))}
          {notes.length === 0 && (
             <div className="col-span-1 md:col-span-2 p-8 text-center text-gray-500 font-mono">No notes found. Create one to get started.</div>
          )}
        </div>
      )}

      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
          <div className="bg-[#121214] border border-[#27272a] rounded-xl w-full max-w-lg shadow-2xl overflow-hidden flex flex-col">
            <div className="p-4 border-b border-[#27272a] flex justify-between items-center bg-[#09090b]">
              <h3 className="text-white font-medium">{currentNote.id ? 'Edit Note' : 'New Note'}</h3>
              <button onClick={closeModal} className="text-gray-500 hover:text-white"><X className="w-5 h-5"/></button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">Title</label>
                <input 
                  type="text" 
                  value={currentNote.title}
                  onChange={(e) => setCurrentNote({...currentNote, title: e.target.value})}
                  className="w-full bg-[#09090b] border border-[#27272a] rounded p-2 text-white text-sm focus:outline-none focus:border-cyan-500/50"
                  placeholder="Note Title"
                />
              </div>
              <div>
                <label className="block text-xs font-mono text-gray-400 mb-1">Description</label>
                <textarea 
                  value={currentNote.desc}
                  onChange={(e) => setCurrentNote({...currentNote, desc: e.target.value})}
                  className="w-full h-32 bg-[#09090b] border border-[#27272a] rounded p-2 text-white text-sm focus:outline-none focus:border-cyan-500/50 resize-none"
                  placeholder="Note content..."
                />
              </div>
            </div>
            <div className="p-4 border-t border-[#27272a] bg-[#09090b] flex justify-end">
              <button onClick={saveNote} className="flex items-center px-4 py-2 bg-cyan-500 text-black text-sm font-semibold rounded hover:bg-cyan-400 transition-colors">
                <Save className="w-4 h-4 mr-2" /> Save Note
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
