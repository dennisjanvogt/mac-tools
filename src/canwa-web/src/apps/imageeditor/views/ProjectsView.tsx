import { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import {
  Plus, Upload, Trash2, Image as ImageIcon, Instagram, Youtube, Monitor,
  FileText, Square, Smartphone, Twitter, Facebook, Linkedin,
  Music2, Layers, Printer, LayoutGrid, Clapperboard, CircleUser, ImagePlay,
  PanelTop, Megaphone, BookOpen, Globe, Sparkles, GalleryHorizontalEnd,
} from 'lucide-react'
import { useLayerStore } from '@/stores/canwa'
import { PROJECT_PRESETS, TEMPLATE_CATEGORIES, type TemplateCategory } from '@/stores/canwa/utils/constants'

// Category icons
const CATEGORY_ICONS: Record<TemplateCategory, React.ReactNode> = {
  all: <LayoutGrid className="w-3.5 h-3.5" />,
  instagram: <Instagram className="w-3.5 h-3.5" />,
  youtube: <Youtube className="w-3.5 h-3.5" />,
  facebook: <Facebook className="w-3.5 h-3.5" />,
  twitter: <Twitter className="w-3.5 h-3.5" />,
  linkedin: <Linkedin className="w-3.5 h-3.5" />,
  tiktok: <Music2 className="w-3.5 h-3.5" />,
  print: <Printer className="w-3.5 h-3.5" />,
  other: <Layers className="w-3.5 h-3.5" />,
}

// Preset-specific icons based on name keywords
function getPresetIcon(name: string, category: TemplateCategory): React.ReactNode {
  const n = name.toLowerCase()
  if (n.includes('profile')) return <CircleUser className="w-5 h-5" />
  if (n.includes('story') || n.includes('reel') || n.includes('shorts')) return <Smartphone className="w-5 h-5" />
  if (n.includes('banner') || n.includes('header') || n.includes('cover')) return <PanelTop className="w-5 h-5" />
  if (n.includes('thumbnail')) return <ImagePlay className="w-5 h-5" />
  if (n.includes('video') || n.includes('end screen')) return <Clapperboard className="w-5 h-5" />
  if (n.includes('ad')) return <Megaphone className="w-5 h-5" />
  if (n.includes('article')) return <BookOpen className="w-5 h-5" />
  if (n.includes('wallpaper')) return <Monitor className="w-5 h-5" />
  if (n.includes('logo') || n.includes('favicon')) return <Sparkles className="w-5 h-5" />
  if (n.includes('open graph')) return <Globe className="w-5 h-5" />
  if (n.includes('square')) return <Square className="w-5 h-5" />
  if (n.includes('flyer') || n.includes('poster')) return <GalleryHorizontalEnd className="w-5 h-5" />

  // Fallback by category
  if (category === 'instagram') return <Instagram className="w-5 h-5" />
  if (category === 'youtube') return <Youtube className="w-5 h-5" />
  if (category === 'facebook') return <Facebook className="w-5 h-5" />
  if (category === 'twitter') return <Twitter className="w-5 h-5" />
  if (category === 'linkedin') return <Linkedin className="w-5 h-5" />
  if (category === 'tiktok') return <Music2 className="w-5 h-5" />
  if (category === 'print') return <FileText className="w-5 h-5" />
  return <ImageIcon className="w-5 h-5" />
}

export function ProjectsView() {
  const projects = useLayerStore(s => s.projects)
  const isLoading = useLayerStore(s => s.isLoading)
  const openProject = useLayerStore(s => s.openProject)
  const deleteProject = useLayerStore(s => s.deleteProject)
  const newProject = useLayerStore(s => s.newProject)
  const importImage = useLayerStore(s => s.importImage)
  const loadProjectsFromBackend = useLayerStore(s => s.loadProjectsFromBackend)

  const [showNewDialog, setShowNewDialog] = useState(false)
  const [newName, setNewName] = useState('Untitled')
  const [newWidth, setNewWidth] = useState(1920)
  const [newHeight, setNewHeight] = useState(1080)
  const [activeCategory, setActiveCategory] = useState<TemplateCategory>('all')
  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    loadProjectsFromBackend()
  }, [loadProjectsFromBackend])

  const handleCreate = () => {
    newProject(newName, newWidth, newHeight)
    setShowNewDialog(false)
    setNewName('Untitled')
    setActiveCategory('all')
  }

  const handleImport = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0]
      if (file && file.type.startsWith('image/')) {
        await importImage(file)
      }
    },
    [importImage]
  )

  const filteredPresets = useMemo(() => {
    if (activeCategory === 'all') return PROJECT_PRESETS
    return PROJECT_PRESETS.filter(p => p.category === activeCategory)
  }, [activeCategory])

  return (
    <div className="h-full w-full overflow-auto px-6 py-5">
      <div className="w-full">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100">Canwa</h1>
          <div className="flex gap-2">
            <button
              onClick={() => fileInputRef.current?.click()}
              className="flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 text-sm text-gray-900 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800"
            >
              <Upload className="w-4 h-4" /> Import Image
            </button>
            <button
              onClick={() => setShowNewDialog(true)}
              className="flex items-center gap-2 px-4 py-2 bg-violet-500 text-white text-sm hover:bg-violet-600"
            >
              <Plus className="w-4 h-4" /> New Project
            </button>
          </div>
        </div>

        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handleImport}
        />

        {/* New Project Dialog */}
        {showNewDialog && (
          <div
            className="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
            onClick={() => setShowNewDialog(false)}
          >
            <div
              className="bg-white dark:bg-gray-800 shadow-2xl w-[880px] max-w-[calc(100vw-2rem)] max-h-[calc(100vh-4rem)] flex flex-col"
              onClick={e => e.stopPropagation()}
            >
              {/* Header */}
              <div className="p-6 pb-0">
                <h2 className="text-lg font-semibold mb-5 text-gray-800 dark:text-gray-200">
                  New Project
                </h2>

                {/* Name + Dimensions row */}
                <div className="flex gap-3 mb-4">
                  <input
                    value={newName}
                    onChange={e => setNewName(e.target.value)}
                    placeholder="Project name"
                    className="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 bg-transparent text-sm text-gray-800 dark:text-gray-200 focus:border-violet-400 focus:outline-none"
                    onKeyDown={e => e.key === 'Enter' && handleCreate()}
                    autoFocus
                  />
                  <div className="flex items-center gap-1.5">
                    <input
                      type="number"
                      value={newWidth}
                      onChange={e => setNewWidth(Number(e.target.value))}
                      className="w-20 px-2.5 py-2 border border-gray-300 dark:border-gray-600 bg-transparent text-sm text-center text-gray-800 dark:text-gray-200 focus:border-violet-400 focus:outline-none"
                    />
                    <span className="text-gray-400 text-xs font-medium">×</span>
                    <input
                      type="number"
                      value={newHeight}
                      onChange={e => setNewHeight(Number(e.target.value))}
                      className="w-20 px-2.5 py-2 border border-gray-300 dark:border-gray-600 bg-transparent text-sm text-center text-gray-800 dark:text-gray-200 focus:border-violet-400 focus:outline-none"
                    />
                  </div>
                </div>

                {/* Category filter tabs */}
                <div className="flex gap-1 justify-center overflow-x-auto pb-3 -mx-1 px-1">
                  {TEMPLATE_CATEGORIES.map(cat => (
                    <button
                      key={cat.id}
                      onClick={() => setActiveCategory(cat.id)}
                      className={`flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium whitespace-nowrap transition-all ${
                        activeCategory === cat.id
                          ? 'bg-violet-500 text-white shadow-sm'
                          : 'bg-gray-100 dark:bg-gray-700 text-gray-900 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
                      }`}
                    >
                      {CATEGORY_ICONS[cat.id]}
                      {cat.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Preset grid — scrollable if needed */}
              <div className="flex-1 overflow-y-auto px-6 py-3 min-h-0">
                <div className="grid grid-cols-5 gap-2">
                  {filteredPresets.map(p => {
                    const isSelected = newWidth === p.width && newHeight === p.height
                    return (
                      <button
                        key={`${p.category}-${p.name}`}
                        onClick={() => {
                          setNewWidth(p.width)
                          setNewHeight(p.height)
                          if (newName === 'Untitled') setNewName(p.name)
                        }}
                        className={`flex flex-col items-center gap-1.5 p-3 border text-center transition-all ${
                          isSelected
                            ? 'border-violet-400 bg-violet-50 dark:bg-violet-500/10 shadow-sm'
                            : 'border-gray-200 dark:border-gray-700 hover:border-violet-300 hover:bg-gray-50 dark:hover:bg-gray-750'
                        }`}
                      >
                        <div className={`${isSelected ? 'text-violet-500' : 'text-gray-500 dark:text-gray-400'}`}>
                          {getPresetIcon(p.name, p.category)}
                        </div>
                        <div className={`text-xs font-medium truncate w-full ${isSelected ? 'text-violet-700 dark:text-violet-300' : 'text-gray-700 dark:text-gray-300'}`}>
                          {p.name}
                        </div>
                        <div className="text-[10px] text-gray-400">
                          {p.width}×{p.height}
                        </div>
                      </button>
                    )
                  })}
                </div>
              </div>

              {/* Action buttons */}
              <div className="p-6 pt-3 flex gap-2">
                <button
                  onClick={() => { setShowNewDialog(false); setActiveCategory('all') }}
                  className="flex-1 px-4 py-2.5 border border-gray-300 dark:border-gray-600 text-sm text-gray-900 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-750"
                >
                  Cancel
                </button>
                <button
                  onClick={handleCreate}
                  className="flex-1 px-4 py-2.5 bg-violet-500 text-white text-sm font-medium hover:bg-violet-600 transition-colors"
                >
                  Create
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Project Grid */}
        {isLoading ? (
          <div className="text-center py-20 text-gray-400">Loading...</div>
        ) : projects.length === 0 ? (
          <div className="text-center py-20">
            <ImageIcon className="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
            <p className="text-gray-500 dark:text-gray-400">No projects yet</p>
            <p className="text-sm text-gray-400 mt-1">
              Create a new project or import an image to get started
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {projects.map(project => (
              <div
                key={project.id}
                onClick={() => openProject(project.id)}
                className="group cursor-pointer border border-gray-200 dark:border-gray-700 overflow-hidden hover:border-violet-400 dark:hover:border-violet-500 hover:shadow-lg transition-all"
              >
                <div className="aspect-video relative overflow-hidden">
                  {project.thumbnailUrl ? (
                    <img
                      src={project.thumbnailUrl}
                      alt={project.name}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="flex items-center justify-center h-full">
                      <ImageIcon className="w-10 h-10 text-gray-300 dark:text-gray-600" />
                    </div>
                  )}
                  <button
                    onClick={e => {
                      e.stopPropagation()
                      deleteProject(project.id)
                    }}
                    className="absolute top-2 right-2 p-1.5 bg-black/50 text-white opacity-0 group-hover:opacity-100 transition-opacity hover:bg-red-500"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
                <div className="p-3">
                  <div className="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">
                    {project.name}
                  </div>
                  <div className="text-xs text-gray-400 mt-0.5">
                    {project.width}x{project.height} ·{' '}
                    {new Date(project.updatedAt).toLocaleDateString()}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
