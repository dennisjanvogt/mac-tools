import { useState, useMemo } from 'react'

import { X, Search, Keyboard } from 'lucide-react'

interface ShortcutHelpDialogProps {
  isOpen: boolean
  onClose: () => void
}

interface ShortcutItem {
  key: string
  action: string
  category: string
}

const SHORTCUTS: ShortcutItem[] = [
  // Selection Tools
  { key: 'V', action: 'Select Tool', category: 'Selection' },
  { key: 'Q', action: 'Rectangle Select', category: 'Selection' },
  { key: 'W', action: 'Ellipse Select', category: 'Selection' },
  { key: 'A', action: 'Lasso Select', category: 'Selection' },
  { key: 'F', action: 'Magic Wand', category: 'Selection' },
  { key: 'M', action: 'Move Tool', category: 'Selection' },
  // Drawing Tools
  { key: 'B', action: 'Brush', category: 'Drawing' },
  { key: 'P', action: 'Pencil', category: 'Drawing' },
  { key: 'E', action: 'Eraser', category: 'Drawing' },
  // Shape Tools
  { key: 'L', action: 'Line', category: 'Shapes' },
  { key: 'R', action: 'Rectangle', category: 'Shapes' },
  { key: 'O', action: 'Ellipse', category: 'Shapes' },
  // Fill Tools
  { key: 'K', action: 'Bucket Fill', category: 'Fill' },
  { key: 'G', action: 'Gradient', category: 'Fill' },
  // Retouch Tools
  { key: 'J', action: 'Blur Brush', category: 'Retouch' },
  { key: 'D', action: 'Dodge (Lighten)', category: 'Retouch' },
  { key: 'N', action: 'Burn (Darken)', category: 'Retouch' },
  { key: 'S', action: 'Clone Stamp', category: 'Retouch' },
  // Other Tools
  { key: 'T', action: 'Text', category: 'Other' },
  { key: 'C', action: 'Crop', category: 'Other' },
  { key: 'I', action: 'Eyedropper', category: 'Other' },
  // General
  { key: 'Cmd+Z', action: 'Undo', category: 'General' },
  { key: 'Cmd+Shift+Z', action: 'Redo', category: 'General' },
  { key: 'Cmd+E', action: 'Export', category: 'General' },
  { key: 'Cmd+G', action: 'Toggle Grid', category: 'General' },
  { key: 'Space', action: 'Pan Canvas (hold)', category: 'General' },
  { key: 'Delete', action: 'Delete Layer/Selection', category: 'General' },
  { key: 'Escape', action: 'Clear Selection', category: 'General' },
  // Modifiers
  { key: 'Shift', action: 'Constrain to square/circle', category: 'Modifiers' },
  { key: 'Alt+Click', action: 'Set Clone Source', category: 'Modifiers' },
  { key: '[ / ]', action: 'Decrease/Increase Brush Size', category: 'Modifiers' },
]

export function ShortcutHelpDialog({ isOpen, onClose }: ShortcutHelpDialogProps) {
  const [searchQuery, setSearchQuery] = useState('')

  const filteredShortcuts = useMemo(() => {
    if (!searchQuery.trim()) return SHORTCUTS
    const query = searchQuery.toLowerCase()
    return SHORTCUTS.filter(
      (s) =>
        s.key.toLowerCase().includes(query) ||
        s.action.toLowerCase().includes(query) ||
        s.category.toLowerCase().includes(query)
    )
  }, [searchQuery])

  const groupedShortcuts = useMemo(() => {
    const groups: Record<string, ShortcutItem[]> = {}
    filteredShortcuts.forEach((shortcut) => {
      if (!groups[shortcut.category]) {
        groups[shortcut.category] = []
      }
      groups[shortcut.category].push(shortcut)
    })
    return groups
  }, [filteredShortcuts])

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
      <div className="bg-gray-800 w-full max-w-lg max-h-[80vh] flex flex-col shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-700">
          <div className="flex items-center gap-2">
            <Keyboard className="w-5 h-5 text-accent-400" />
            <h2 className="text-lg font-semibold">Keyboard Shortcuts</h2>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-gray-700 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Search */}
        <div className="p-3 border-b border-gray-700">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search shortcuts..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => e.stopPropagation()}
              className="w-full pl-10 pr-4 py-2 bg-gray-900 border border-gray-700 text-sm focus:outline-none focus:ring-2 focus:ring-accent-500 focus:border-transparent"
              autoFocus
            />
          </div>
        </div>

        {/* Shortcuts List */}
        <div className="flex-1 overflow-y-auto p-4">
          {Object.keys(groupedShortcuts).length === 0 ? (
            <p className="text-center text-gray-500 py-8">No shortcuts found</p>
          ) : (
            Object.entries(groupedShortcuts).map(([category, shortcuts]) => (
              <div key={category} className="mb-4 last:mb-0">
                <h3 className="text-xs font-semibold text-gray-400 uppercase mb-2">
                  {category}
                </h3>
                <div className="space-y-1">
                  {shortcuts.map((shortcut, index) => (
                    <div
                      key={`${shortcut.key}-${index}`}
                      className="flex items-center justify-between py-1.5 px-2 hover:bg-gray-700/50"
                    >
                      <span className="text-sm text-gray-300">{shortcut.action}</span>
                      <kbd className="px-2 py-0.5 bg-gray-900 border border-gray-600 text-xs font-mono text-gray-300">
                        {shortcut.key}
                      </kbd>
                    </div>
                  ))}
                </div>
              </div>
            ))
          )}
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-gray-700 text-center">
          <p className="text-xs text-gray-500">
            Press <kbd className="px-1.5 py-0.5 bg-gray-900 border border-gray-600 text-xs">Cmd+?</kbd> to toggle this dialog
          </p>
        </div>
      </div>
    </div>
  )
}
