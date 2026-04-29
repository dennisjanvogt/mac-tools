import { useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { LeftSidebarPanel, RightLayersPanel } from '../components/sidebar/SidebarPanel'
import { Canvas } from '../components/canvas/Canvas'
import { FloatingZoomBar } from '../components/canvas/FloatingZoomBar'
import { ExportDialog } from '../components/ExportDialog'
import { useLayerStore, useCanvasStore, useHistoryStore } from '@/stores/canwa'
import type { SidebarPanel as SidebarPanelType } from '@/stores/canwa'
import { generateId, DEFAULT_FILTERS, DEFAULT_LAYER_EFFECTS } from '@/apps/imageeditor/types'
import type { Layer } from '@/apps/imageeditor/types'
import { ChevronLeft, Undo2, Redo2, Download, Settings2, Type, SlidersHorizontal, Eclipse, Sparkles, FolderOpen } from 'lucide-react'

const TAB_ITEMS: { id: SidebarPanelType; icon: React.ComponentType<{ className?: string }>; labelKey: string }[] = [
  { id: 'properties', icon: Settings2, labelKey: 'canwa.properties' },
  { id: 'text', icon: Type, labelKey: 'canwa.text' },
  { id: 'adjust', icon: SlidersHorizontal, labelKey: 'canwa.adjust' },
  { id: 'shadow', icon: Eclipse, labelKey: 'canwa.shadow' },
  { id: 'ai', icon: Sparkles, labelKey: 'canwa.ai' },
  { id: 'library', icon: FolderOpen, labelKey: 'canwa.library' },
]

export function EditorView() {
  const { t } = useTranslation()
  const currentProject = useLayerStore(s => s.currentProject)
  const closeProject = useLayerStore(s => s.closeProject)
  const updateProjectName = useLayerStore(s => s.updateProjectName)
  const showExportDialog = useCanvasStore(s => s.showExportDialog)
  const setShowExportDialog = useCanvasStore(s => s.setShowExportDialog)
  const activePanel = useCanvasStore(s => s.activePanel)
  const setActivePanel = useCanvasStore(s => s.setActivePanel)
  const undo = useHistoryStore(s => s.undo)
  const redo = useHistoryStore(s => s.redo)
  const canUndo = useHistoryStore(s => s.canUndo)
  const canRedo = useHistoryStore(s => s.canRedo)

  // Paste image from clipboard as new layer in the current project
  useEffect(() => {
    const handlePaste = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items
      if (!items) return
      const { currentProject, addLayer } = useLayerStore.getState()
      if (!currentProject) return

      for (const item of items) {
        if (item.type.startsWith('image/')) {
          e.preventDefault()
          const file = item.getAsFile()
          if (!file) return

          const reader = new FileReader()
          reader.onload = (ev) => {
            const img = new Image()
            img.onload = () => {
              const canvas = document.createElement('canvas')
              canvas.width = img.width
              canvas.height = img.height
              const ctx = canvas.getContext('2d')
              if (!ctx) return
              ctx.drawImage(img, 0, 0)
              const imageData = canvas.toDataURL('image/png')

              const newLayer: Layer = {
                id: generateId(),
                name: file.name || 'Pasted Image',
                type: 'image',
                visible: true,
                locked: false,
                opacity: 100,
                blendMode: 'normal',
                x: 0,
                y: 0,
                width: img.width,
                height: img.height,
                rotation: 0,
                imageData,
                filters: { ...DEFAULT_FILTERS },
                layerEffects: { ...DEFAULT_LAYER_EFFECTS },
              }
              addLayer(newLayer)
            }
            img.src = ev.target?.result as string
          }
          reader.readAsDataURL(file)
          return
        }
      }
    }
    window.addEventListener('paste', handlePaste)
    return () => window.removeEventListener('paste', handlePaste)
  }, [])

  if (!currentProject) {
    return (
      <div className="h-full flex items-center justify-center bg-gray-100 dark:bg-gray-950">
        <div className="flex flex-col items-center gap-3 text-gray-400">
          <div className="w-8 h-8 border-2 border-gray-300 border-t-violet-500 animate-spin" />
          <span className="text-sm">Loading project...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="h-full flex flex-col">
      {/* Top bar */}
      <div className="h-11 flex items-center px-3 border-b border-gray-200 dark:border-gray-700/50 gap-2 flex-shrink-0">
        <button
          onClick={closeProject}
          className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-700 dark:text-gray-400"
        >
          <ChevronLeft className="w-4 h-4" />
        </button>
        <span className="text-sm font-semibold text-violet-600 dark:text-violet-400">Canwa</span>
        <div className="w-px h-5 bg-gray-300 dark:bg-gray-600 mx-1" />
        <input
          value={currentProject.name}
          onChange={e => updateProjectName(e.target.value)}
          className="text-sm bg-transparent border-none outline-none text-gray-900 dark:text-gray-300 max-w-[200px]"
        />

        <div className="flex-1" />

        {/* Panel tabs (center) */}
        <div className="flex items-center gap-0.5 p-0.5">
          {TAB_ITEMS.map(({ id, icon: Icon, labelKey }) => {
            const isActive = activePanel === id
            return (
              <button
                key={id}
                onClick={() => setActivePanel(id)}
                className={`flex items-center gap-1 px-2.5 py-1 text-[11px] font-medium transition-colors ${
                  isActive
                    ? 'bg-accent-50 dark:bg-accent-900/20 text-accent-700 dark:text-accent-300 ring-1 ring-accent-400'
                    : 'text-gray-700 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-300'
                }`}
                title={t(labelKey)}
              >
                <Icon className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">{t(labelKey)}</span>
              </button>
            )
          })}
        </div>

        <div className="flex-1" />

        <button
          onClick={undo}
          disabled={!canUndo()}
          className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-700 dark:text-gray-400 disabled:opacity-30"
        >
          <Undo2 className="w-4 h-4" />
        </button>
        <button
          onClick={redo}
          disabled={!canRedo()}
          className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-700 dark:text-gray-400 disabled:opacity-30"
        >
          <Redo2 className="w-4 h-4" />
        </button>
        <button
          onClick={() => setShowExportDialog(true)}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-violet-500 text-white text-xs font-medium hover:bg-violet-600"
        >
          <Download className="w-3.5 h-3.5" /> Export
        </button>
      </div>

      {/* Main content */}
      <div className="flex-1 flex overflow-hidden">
        <LeftSidebarPanel />
        <div className="flex-1 relative">
          <Canvas />
          <FloatingZoomBar />
        </div>
        <RightLayersPanel />
      </div>

      {/* Dialogs */}
      {showExportDialog && <ExportDialog />}
    </div>
  )
}
