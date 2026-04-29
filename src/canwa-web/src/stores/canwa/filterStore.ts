import { create } from 'zustand'
import type { Filters } from '@/apps/imageeditor/types'
import { DEFAULT_FILTERS } from '@/apps/imageeditor/types'
import { useLayerStore } from './layerStore'
import { useHistoryStore } from './historyStore'

interface FilterState {
  filters: Filters
  filterMode: 'layer' | 'global'
  livePreview: boolean

  setFilters: (filters: Partial<Filters>) => void
  commitFilters: () => void
  setFilterMode: (mode: 'layer' | 'global') => void
  setLivePreview: (preview: boolean) => void
  setLayerFilters: (layerId: string, filters: Partial<Filters>) => void
  applyFilters: () => void
  resetFilters: () => void
  loadLayerFilters: (layerId: string) => void
}

export const useFilterStore = create<FilterState>()((set, get) => ({
  filters: { ...DEFAULT_FILTERS },
  filterMode: 'layer',
  livePreview: true,

  setFilters: (filters) => {
    const newFilters = { ...get().filters, ...filters }
    set({ filters: newFilters })

    // Auto-apply to layer(s) immediately (no history — use commitFilters for undo)
    const { filterMode } = get()
    const { currentProject, selectedLayerId } = useLayerStore.getState()
    if (!currentProject) return

    if (filterMode === 'layer' && selectedLayerId) {
      useLayerStore.setState(state => ({
        currentProject: state.currentProject ? {
          ...state.currentProject,
          layers: state.currentProject.layers.map(l =>
            l.id === selectedLayerId ? { ...l, filters: { ...newFilters } } : l
          ),
        } : null,
      }))
    } else if (filterMode === 'global') {
      useLayerStore.setState(state => ({
        currentProject: state.currentProject ? {
          ...state.currentProject,
          layers: state.currentProject.layers.map(l => ({
            ...l,
            filters: { ...(l.filters || DEFAULT_FILTERS), ...newFilters },
          })),
        } : null,
      }))
    }
  },

  commitFilters: () => {
    useHistoryStore.getState().pushHistory('Adjust Filters')
  },

  setFilterMode: (mode) => set({ filterMode: mode }),
  setLivePreview: (preview) => set({ livePreview: preview }),

  setLayerFilters: (layerId, filters) => {
    const { currentProject } = useLayerStore.getState()
    if (!currentProject) return

    useHistoryStore.getState().pushHistory('Set Layer Filters')

    useLayerStore.setState(state => ({
      currentProject: state.currentProject ? {
        ...state.currentProject,
        layers: state.currentProject.layers.map(l =>
          l.id === layerId
            ? { ...l, filters: { ...(l.filters || DEFAULT_FILTERS), ...filters } }
            : l
        ),
      } : null,
    }))
  },

  loadLayerFilters: (layerId) => {
    const { currentProject } = useLayerStore.getState()
    if (!currentProject) return
    const layer = currentProject.layers.find(l => l.id === layerId)
    if (layer?.filters) {
      set({ filters: { ...layer.filters } })
    } else {
      set({ filters: { ...DEFAULT_FILTERS } })
    }
  },

  applyFilters: () => {
    const { filters, filterMode } = get()
    const { currentProject } = useLayerStore.getState()
    const selectedLayerId = useLayerStore.getState().selectedLayerId
    if (!currentProject) return

    useHistoryStore.getState().pushHistory('Apply Filters')

    if (filterMode === 'layer' && selectedLayerId) {
      useLayerStore.setState(state => ({
        currentProject: state.currentProject ? {
          ...state.currentProject,
          layers: state.currentProject.layers.map(l =>
            l.id === selectedLayerId ? { ...l, filters: { ...filters } } : l
          ),
        } : null,
      }))
    } else {
      useLayerStore.setState(state => ({
        currentProject: state.currentProject ? {
          ...state.currentProject,
          layers: state.currentProject.layers.map(l => ({
            ...l,
            filters: { ...(l.filters || DEFAULT_FILTERS), ...filters },
          })),
        } : null,
      }))
      set({ filters: { ...DEFAULT_FILTERS } })
    }
  },

  resetFilters: () => {
    get().setFilters({ ...DEFAULT_FILTERS })
  },
}))
