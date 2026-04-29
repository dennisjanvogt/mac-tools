import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import type { CropArea, Selection, Tool } from '@/apps/imageeditor/types'
import { DEFAULT_CROP, DEFAULT_SELECTION } from '@/apps/imageeditor/types'

// Sidebar panel IDs
export type SidebarPanel = 'design' | 'uploads' | 'text' | 'ai' | 'adjust' | 'shadow' | 'layers' | 'library' | 'properties' | null

interface CanvasState {
  // Viewport
  zoom: number
  projectZoomLevels: Record<string, number>
  panX: number
  panY: number
  fitToViewTrigger: number

  // Tools
  activeTool: Tool

  // Grid
  showGrid: boolean
  gridSize: number
  gridColor: string
  snapToGrid: boolean

  // Snapping
  snapEnabled: boolean
  snapThreshold: number

  // Custom guidelines (persistent, user-placed)
  guidelines: { id: string; orientation: 'h' | 'v'; position: number }[]

  // Selection
  selection: Selection

  // Crop
  crop: CropArea

  // Workspace
  workspaceBg: string

  // UI state
  activePanel: SidebarPanel
  showExportDialog: boolean

  // Toast notifications
  toasts: { id: string; message: string; type: 'success' | 'info' | 'error' }[]

  // Actions
  setZoom: (zoom: number, projectId?: string) => void
  setPan: (x: number, y: number) => void
  triggerFitToView: () => void
  setActiveTool: (tool: Tool) => void
  setShowGrid: (show: boolean) => void
  setGridSize: (size: number) => void
  setGridColor: (color: string) => void
  setSnapToGrid: (snap: boolean) => void
  setSnapEnabled: (snap: boolean) => void
  addGuideline: (orientation: 'h' | 'v', position: number) => void
  removeGuideline: (id: string) => void
  clearGuidelines: () => void
  setSelection: (selection: Partial<Selection>) => void
  clearSelection: () => void
  setCrop: (crop: Partial<CropArea>) => void
  applyCrop: () => void
  cancelCrop: () => void
  setWorkspaceBg: (color: string) => void
  setActivePanel: (panel: SidebarPanel) => void
  setShowExportDialog: (show: boolean) => void
  showToast: (message: string, type?: 'success' | 'info' | 'error') => void
  dismissToast: (id: string) => void
}

export const useCanvasStore = create<CanvasState>()(
  persist(
    (set, get) => ({
      zoom: 100,
      projectZoomLevels: {},
      panX: 0,
      panY: 0,
      fitToViewTrigger: 0,
      activeTool: 'move' as Tool,
      showGrid: false,
      gridSize: 20,
      gridColor: 'rgba(128, 128, 128, 0.3)',
      snapToGrid: false,
      snapEnabled: true,
      snapThreshold: 8,
      guidelines: [],
      selection: { ...DEFAULT_SELECTION },
      crop: { ...DEFAULT_CROP },
      workspaceBg: '',
      activePanel: 'properties' as SidebarPanel,
      showExportDialog: false,
      toasts: [],

      setZoom: (zoom: number, projectId?: string) => {
        const clamped = Math.max(10, Math.min(400, zoom))
        const updates: Partial<CanvasState> = { zoom: clamped }
        if (projectId) {
          updates.projectZoomLevels = { ...get().projectZoomLevels, [projectId]: clamped }
        }
        set(updates as CanvasState)
      },

      setPan: (x: number, y: number) => set({ panX: x, panY: y }),
      triggerFitToView: () => set((s: CanvasState) => ({ fitToViewTrigger: s.fitToViewTrigger + 1 })),
      setActiveTool: (tool: Tool) => set({ activeTool: tool }),
      setShowGrid: (show: boolean) => set({ showGrid: show }),
      setGridSize: (size: number) => set({ gridSize: size }),
      setGridColor: (color: string) => set({ gridColor: color }),
      setSnapToGrid: (snap: boolean) => set({ snapToGrid: snap }),
      setSnapEnabled: (snap: boolean) => set({ snapEnabled: snap }),

      addGuideline: (orientation: 'h' | 'v', position: number) => {
        const id = `guide-${Date.now()}-${Math.random().toString(36).slice(2, 5)}`
        set((s: CanvasState) => ({ guidelines: [...s.guidelines, { id, orientation, position }] }))
      },
      removeGuideline: (id: string) => set((s: CanvasState) => ({ guidelines: s.guidelines.filter(g => g.id !== id) })),
      clearGuidelines: () => set({ guidelines: [] }),

      setSelection: (selection: Partial<Selection>) => set((s: CanvasState) => ({ selection: { ...s.selection, ...selection } })),
      clearSelection: () => set({ selection: { ...DEFAULT_SELECTION } }),

      setCrop: (crop: Partial<CropArea>) => set((s: CanvasState) => ({ crop: { ...s.crop, ...crop } })),
      applyCrop: () => {
        const { crop } = get()
        if (!crop.active) return
        // The actual crop logic is in layerStore.applyCrop()
        // This just resets the crop UI state
        set({ crop: { ...DEFAULT_CROP } })
      },
      cancelCrop: () => set({ crop: { ...DEFAULT_CROP } }),

      setWorkspaceBg: (color: string) => set({ workspaceBg: color }),
      setActivePanel: (panel: SidebarPanel) => set({ activePanel: panel }),
      setShowExportDialog: (show: boolean) => set({ showExportDialog: show }),

      showToast: (message: string, type: 'success' | 'info' | 'error' = 'info') => {
        const id = `${Date.now()}-${Math.random().toString(36).slice(2, 5)}`
        set((s: CanvasState) => ({ toasts: [...s.toasts, { id, message, type }] }))
        setTimeout(() => {
          set((s: CanvasState) => ({ toasts: s.toasts.filter((t: { id: string }) => t.id !== id) }))
        }, 3000)
      },

      dismissToast: (id: string) => set((s: CanvasState) => ({ toasts: s.toasts.filter((t: { id: string }) => t.id !== id) })),
    }),
    {
      name: 'canwaCanvasStore',
      partialize: (s) => ({
        projectZoomLevels: s.projectZoomLevels,
        showGrid: s.showGrid,
        gridSize: s.gridSize,
        gridColor: s.gridColor,
        snapToGrid: s.snapToGrid,
        snapEnabled: s.snapEnabled,
        guidelines: s.guidelines,
        activeTool: s.activeTool,
        activePanel: s.activePanel,
        workspaceBg: s.workspaceBg,
      }),
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      merge: (persisted: any, current: any) => {
        const merged = { ...current, ...persisted }
        // Ensure a panel is always active
        if (!merged.activePanel) merged.activePanel = 'properties'
        return merged
      },
    }
  )
)
