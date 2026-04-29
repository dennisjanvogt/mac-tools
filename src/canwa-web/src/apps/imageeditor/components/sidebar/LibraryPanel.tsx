import { useState, useMemo, useRef, useEffect } from 'react'
import { Search, Trash2, Pencil, FolderOpen, X, ChevronDown, Check } from 'lucide-react'
import { useLayerStore } from '@/stores/canwa'
import type { LayerAsset } from '@/stores/canwa'

// Relative paths are proxied by the canwa:// scheme handler.
const getMediaUrl = (path: string) => {
  if (!path) return ''
  if (path.startsWith('http') || path.startsWith('data:') || path.startsWith('canwa:')) return path
  if (path.startsWith('/')) return path
  return `/${path}`
}

export function LibraryPanel() {
  const {
    layerAssets,
    fetchLayerAssets,
    insertLayerFromLibrary,
    deleteLayerAsset,
    renameLayerAsset,
    updateLayerAssetCategory,
  } = useLayerStore()

  const [search, setSearch] = useState('')
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null)
  const [showCategoryPicker, setShowCategoryPicker] = useState(false)
  const [editingId, setEditingId] = useState<number | null>(null)
  const [editName, setEditName] = useState('')
  const [editCategoryId, setEditCategoryId] = useState<number | null>(null)
  const [editCategoryValue, setEditCategoryValue] = useState('')
  const editInputRef = useRef<HTMLInputElement>(null)
  const categoryInputRef = useRef<HTMLInputElement>(null)
  const pickerRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    fetchLayerAssets()
  }, [fetchLayerAssets])

  useEffect(() => {
    if (editingId !== null) editInputRef.current?.focus()
  }, [editingId])
  useEffect(() => {
    if (editCategoryId !== null) categoryInputRef.current?.focus()
  }, [editCategoryId])

  // Close picker on outside click
  useEffect(() => {
    if (!showCategoryPicker) return
    const handler = (e: MouseEvent) => {
      if (pickerRef.current && !pickerRef.current.contains(e.target as Node)) {
        setShowCategoryPicker(false)
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [showCategoryPicker])

  // Derive categories with counts
  const categoriesWithCounts = useMemo(() => {
    const counts = new Map<string, number>()
    layerAssets.forEach((a) => {
      const cat = a.category || 'Uncategorized'
      counts.set(cat, (counts.get(cat) || 0) + 1)
    })
    return Array.from(counts.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([name, count]) => ({ name, count }))
  }, [layerAssets])

  // Filtered assets
  const filtered = useMemo(() => {
    let list = layerAssets
    if (selectedCategory) {
      if (selectedCategory === 'Uncategorized') {
        list = list.filter((a) => !a.category)
      } else {
        list = list.filter((a) => a.category === selectedCategory)
      }
    }
    if (search.trim()) {
      const q = search.toLowerCase()
      list = list.filter(
        (a) =>
          a.name.toLowerCase().includes(q) ||
          (a.category || '').toLowerCase().includes(q)
      )
    }
    return list
  }, [layerAssets, selectedCategory, search])

  const handleInsert = (assetId: number) => {
    insertLayerFromLibrary(assetId)
  }

  const handleRename = async (asset: LayerAsset) => {
    if (editName.trim() && editName.trim() !== asset.name) {
      await renameLayerAsset(asset.id, editName.trim())
    }
    setEditingId(null)
    setEditName('')
  }

  const handleCategoryChange = async (asset: LayerAsset) => {
    if (editCategoryValue.trim() !== asset.category) {
      await updateLayerAssetCategory(asset.id, editCategoryValue.trim())
    }
    setEditCategoryId(null)
    setEditCategoryValue('')
  }

  const handleDelete = async (assetId: number) => {
    await deleteLayerAsset(assetId)
  }

  return (
    <div className="flex flex-col overflow-hidden h-full">
      {/* Search + Category filter row */}
      <div className="px-3 pt-3 pb-2 space-y-2">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search assets..."
            className="w-full pl-8 pr-8 py-1.5 text-xs border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-800 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-violet-500"
          />
          {search && (
            <button
              onClick={() => setSearch('')}
              className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
        </div>

        {/* Category picker button */}
        <div className="relative" ref={pickerRef}>
          <button
            onClick={() => setShowCategoryPicker(!showCategoryPicker)}
            className={`w-full flex items-center justify-between px-2.5 py-1.5 text-xs border transition-colors ${
              selectedCategory
                ? 'border-violet-400 dark:border-violet-500 bg-violet-50 dark:bg-violet-500/10 text-violet-700 dark:text-violet-300'
                : 'border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300'
            }`}
          >
            <span className="truncate">
              {selectedCategory
                ? `${selectedCategory} (${categoriesWithCounts.find(c => c.name === selectedCategory)?.count ?? 0})`
                : `All (${layerAssets.length})`}
            </span>
            <ChevronDown className={`w-3.5 h-3.5 flex-shrink-0 ml-1 transition-transform ${showCategoryPicker ? 'rotate-180' : ''}`} />
          </button>

          {/* Dropdown */}
          {showCategoryPicker && (
            <div className="absolute left-0 right-0 top-full mt-1 bg-white dark:bg-gray-800 shadow-xl border border-gray-200 dark:border-gray-700 py-1 z-30 max-h-[240px] overflow-y-auto">
              <button
                onClick={() => { setSelectedCategory(null); setShowCategoryPicker(false) }}
                className="w-full flex items-center justify-between px-3 py-1.5 text-xs text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
              >
                <span>All</span>
                <span className="flex items-center gap-1.5">
                  <span className="text-gray-400">{layerAssets.length}</span>
                  {selectedCategory === null && <Check className="w-3.5 h-3.5 text-violet-500" />}
                </span>
              </button>
              {categoriesWithCounts.map(({ name, count }) => (
                <button
                  key={name}
                  onClick={() => { setSelectedCategory(name); setShowCategoryPicker(false) }}
                  className="w-full flex items-center justify-between px-3 py-1.5 text-xs text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
                >
                  <span className="truncate">{name}</span>
                  <span className="flex items-center gap-1.5 flex-shrink-0">
                    <span className="text-gray-400">{count}</span>
                    {selectedCategory === name && <Check className="w-3.5 h-3.5 text-violet-500" />}
                  </span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Result count */}
      <div className="px-3 pb-1">
        <span className="text-[10px] text-gray-400">
          {filtered.length} asset{filtered.length !== 1 ? 's' : ''}
        </span>
      </div>

      {/* Asset grid */}
      <div className="flex-1 overflow-y-auto px-3 pb-3">
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-32 text-gray-400 dark:text-gray-500">
            <FolderOpen className="w-8 h-8 mb-2 opacity-50" />
            <p className="text-xs">
              {layerAssets.length === 0
                ? 'No assets yet'
                : 'No matching assets'}
            </p>
          </div>
        ) : (
          <div className="grid gap-2" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(110px, 1fr))' }}>
            {filtered.map((asset) => (
              <div
                key={asset.id}
                className="group relative border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800/50 overflow-hidden hover:border-violet-400 dark:hover:border-violet-500 transition-colors"
              >
                {/* Thumbnail */}
                <button
                  onClick={() => handleInsert(asset.id)}
                  className="w-full aspect-square bg-gray-50 dark:bg-gray-900/50 flex items-center justify-center overflow-hidden"
                  title={`Insert "${asset.name}"`}
                >
                  <img
                    src={getMediaUrl(asset.thumbnailUrl || asset.imageUrl)}
                    alt={asset.name}
                    className="max-w-full max-h-full object-contain"
                    loading="lazy"
                  />
                </button>

                {/* Name / Category */}
                <div className="px-2 py-1.5">
                  {editingId === asset.id ? (
                    <input
                      ref={editInputRef}
                      type="text"
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      onBlur={() => handleRename(asset)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handleRename(asset)
                        if (e.key === 'Escape') {
                          setEditingId(null)
                          setEditName('')
                        }
                      }}
                      className="w-full px-1 py-0.5 text-[11px] border border-violet-400 bg-white dark:bg-gray-800 text-gray-800 dark:text-gray-200 focus:outline-none"
                    />
                  ) : (
                    <p className="text-[11px] font-medium text-gray-700 dark:text-gray-300 truncate">
                      {asset.name}
                    </p>
                  )}

                  {editCategoryId === asset.id ? (
                    <input
                      ref={categoryInputRef}
                      type="text"
                      value={editCategoryValue}
                      onChange={(e) => setEditCategoryValue(e.target.value)}
                      onBlur={() => handleCategoryChange(asset)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handleCategoryChange(asset)
                        if (e.key === 'Escape') {
                          setEditCategoryId(null)
                          setEditCategoryValue('')
                        }
                      }}
                      placeholder="Category..."
                      className="w-full px-1 py-0.5 text-[10px] border border-violet-400 bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 focus:outline-none mt-0.5"
                    />
                  ) : (
                    asset.category && (
                      <p className="text-[10px] text-gray-400 dark:text-gray-500 truncate">
                        {asset.category}
                      </p>
                    )
                  )}
                </div>

                {/* Admin controls overlay */}
                <div className="absolute top-1 right-1 flex gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      setEditingId(asset.id)
                      setEditName(asset.name)
                    }}
                    title="Rename"
                    className="p-1 bg-black/60 text-white hover:bg-black/80 transition-colors"
                  >
                    <Pencil className="w-3 h-3" />
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      setEditCategoryId(asset.id)
                      setEditCategoryValue(asset.category || '')
                    }}
                    title="Change category"
                    className="p-1 bg-black/60 text-white hover:bg-black/80 transition-colors"
                  >
                    <FolderOpen className="w-3 h-3" />
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      handleDelete(asset.id)
                    }}
                    title="Delete"
                    className="p-1 bg-red-600/80 text-white hover:bg-red-600 transition-colors"
                  >
                    <Trash2 className="w-3 h-3" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
