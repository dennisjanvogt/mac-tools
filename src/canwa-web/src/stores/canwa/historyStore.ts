import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import type { Layer, HistoryEntry } from '@/apps/imageeditor/types'
import { generateId } from '@/apps/imageeditor/types'
import { MAX_HISTORY_SIZE } from './utils/constants'

// Safe JSON parse helper
function safeJsonParse<T>(json: string, fallback: T): T {
  try { return JSON.parse(json) as T } catch { return fallback }
}

// Lazy accessor to avoid circular dependency with layerStore
// Uses dynamic import() which Vite handles correctly for ESM
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let _layerStore: any = null
let _loadPromise: Promise<void> | null = null

function loadLayerStore(): Promise<void> {
  if (_layerStore) return Promise.resolve()
  if (!_loadPromise) {
    _loadPromise = import('./layerStore').then(mod => {
      _layerStore = mod.useLayerStore
    })
  }
  return _loadPromise
}

// Initialize immediately — by the time any action runs, the import will be resolved
loadLayerStore()

function getLayerStore() {
  return _layerStore
}

interface HistoryState {
  history: HistoryEntry[]
  historyIndex: number
  redoStack: string[]

  pushHistory: (name: string) => void
  undo: () => void
  redo: () => void
  canUndo: () => boolean
  canRedo: () => boolean
  clearHistory: () => void
}

export const useHistoryStore = create<HistoryState>()(
  persist(
    (set, get) => ({
      history: [],
      historyIndex: -1,
      redoStack: [],

      pushHistory: (name: string) => {
        try {
          const store = getLayerStore()
          if (!store) return
          const { currentProject } = store.getState()
          if (!currentProject) return

          // Exclude non-serializable 'canvas' property from snapshot
          const snapshot = JSON.stringify(currentProject.layers, (key, value) => {
            if (key === 'canvas' && value instanceof HTMLCanvasElement) return undefined
            return value
          })

          const entry: HistoryEntry = {
            id: generateId(),
            name,
            timestamp: Date.now(),
            snapshot,
          }

          const { history, historyIndex } = get()
          const newHistory = history.slice(0, historyIndex + 1)
          newHistory.push(entry)
          if (newHistory.length > MAX_HISTORY_SIZE) newHistory.shift()

          set({
            history: newHistory,
            historyIndex: newHistory.length - 1,
            redoStack: [],
          })
        } catch (err) {
          console.warn('[Canwa] Failed to push history:', err)
        }
      },

      undo: () => {
        const { history, historyIndex, redoStack } = get()
        const store = getLayerStore()
        if (!store) return
        const { currentProject } = store.getState()
        if (historyIndex < 0 || !currentProject || history.length === 0) return

        const currentSnapshot = JSON.stringify(currentProject.layers)
        const newRedoStack = [...redoStack, currentSnapshot]

        const currentEntry = history[historyIndex]
        if (currentEntry) {
          const layers = safeJsonParse<Layer[]>(currentEntry.snapshot, currentProject.layers)
          store.setState({
            currentProject: { ...currentProject, layers },
          })
          set({
            historyIndex: historyIndex - 1,
            redoStack: newRedoStack,
          })
        }
      },

      redo: () => {
        const { redoStack, historyIndex } = get()
        const store = getLayerStore()
        if (!store) return
        const { currentProject } = store.getState()
        if (redoStack.length === 0 || !currentProject) return

        const newRedoStack = [...redoStack]
        const snapshot = newRedoStack.pop()
        if (!snapshot) return

        const layers = safeJsonParse<Layer[]>(snapshot, currentProject.layers)
        store.setState({
          currentProject: { ...currentProject, layers },
        })
        set({
          historyIndex: historyIndex + 1,
          redoStack: newRedoStack,
        })
      },

      canUndo: () => get().historyIndex >= 0,
      canRedo: () => get().redoStack.length > 0,

      clearHistory: () => set({ history: [], historyIndex: -1, redoStack: [] }),
    }),
    {
      name: 'canwaHistoryStore',
      storage: {
        getItem: (name: string) => {
          const str = sessionStorage.getItem(name)
          return str ? JSON.parse(str) : null
        },
        setItem: (name: string, value: unknown) => {
          try {
            sessionStorage.setItem(name, JSON.stringify(value))
          } catch {
            // sessionStorage full — silently drop oldest entries
            sessionStorage.removeItem(name)
          }
        },
        removeItem: (name: string) => sessionStorage.removeItem(name),
      },
      partialize: (s: HistoryState) => ({
        history: s.history,
        historyIndex: s.historyIndex,
        redoStack: s.redoStack,
      }),
    }
  )
)
