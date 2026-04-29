import { create } from 'zustand'
import { persist, subscribeWithSelector } from 'zustand/middleware'
import { api } from '@/api/client'
import type { ImageProject, Layer, BlendMode, LayerType, TextEffects, LayerEffects } from '@/apps/imageeditor/types'
import { createLayer, createProject, generateId } from '@/apps/imageeditor/types'
import { generateThumbnail, getMediaUrl } from './utils/imageHelpers'

function csrfToken(): string {
  const match = document.cookie.match(/(?:^|;\s*)csrftoken=([^;]+)/)
  return match ? match[1] : ''
}
import { useConfirmStore } from '@/stores/confirmStore'
import { useHistoryStore } from './historyStore'
import { useCanvasStore } from './canvasStore'

// Text Style Favorite for saving and reusing text styles
export interface TextStyleFavorite {
  id: number  // Backend DB id
  name: string
  fontFamily: string
  fontSize: number
  fontWeight: number
  fontColor: string
  textAlign: 'left' | 'center' | 'right'
  textEffects: TextEffects
  createdAt: string | number
}

export interface LayerAsset {
  id: number
  name: string
  imageUrl: string
  thumbnailUrl: string
  width: number
  height: number
  category: string
  createdAt: string | number
}

type ViewMode = 'projects' | 'editor'

interface LayerState {
  // View mode
  viewMode: ViewMode
  setViewMode: (mode: ViewMode) => void

  // Project state
  currentProject: ImageProject | null
  projects: { id: string; name: string; updatedAt: number; thumbnailUrl?: string; width?: number; height?: number }[]
  savedProjects: Record<string, ImageProject>
  isDirty: boolean
  isLoading: boolean

  // Layers
  selectedLayerId: string | null

  // Recent colors
  recentColors: string[]
  addRecentColor: (color: string) => void

  // Project operations
  newProject: (name: string, width: number, height: number) => void
  openProject: (projectId: string) => Promise<void>
  saveProject: () => Promise<void>
  saveProjectToBackend: () => Promise<void>
  loadProjectsFromBackend: () => Promise<void>
  closeProject: () => void
  deleteProject: (projectId: string) => Promise<void>
  updateProjectName: (name: string) => void

  // Project Export/Import
  exportProject: () => void
  importProject: (file: File) => Promise<void>

  // Layer operations
  addLayer: (layer: Layer | LayerType, name?: string) => void
  deleteLayer: (layerId: string) => void
  duplicateLayer: (layerId: string) => void
  selectLayer: (layerId: string | null) => void
  reorderLayer: (layerId: string, newIndex: number) => void
  toggleLayerVisibility: (layerId: string) => void
  toggleLayerLock: (layerId: string) => void
  setLayerOpacity: (layerId: string, opacity: number) => void
  setLayerBlendMode: (layerId: string, blendMode: BlendMode) => void
  updateLayerImage: (layerId: string, imageData: string) => void
  updateLayerText: (layerId: string, text: string) => void
  updateLayerTextProperties: (
    layerId: string,
    props: {
      fontFamily?: string
      fontSize?: number
      fontColor?: string
      fontWeight?: number
      textAlign?: 'left' | 'center' | 'right'
    }
  ) => void
  updateLayerTextEffects: (layerId: string, effects: TextEffects) => void
  updateLayerEffects: (layerId: string, effects: LayerEffects) => void
  setLayerPosition: (layerId: string, x: number, y: number) => void
  resizeLayer: (layerId: string, width: number, height: number) => void
  setLayerTransform: (layerId: string, x: number, y: number, width: number, height: number) => void
  renameLayer: (layerId: string, name: string) => void
  rotateLayer: (layerId: string, degrees: number) => void
  setLayerRotation: (layerId: string, degrees: number) => void
  flipLayerHorizontal: (layerId: string) => void
  flipLayerVertical: (layerId: string) => void
  mergeLayerDown: (layerId: string) => Promise<void>
  flattenLayers: () => Promise<void>

  // Image import
  importImage: (file: File) => Promise<void>
  importImageToLayer: (file: File, layerId: string) => Promise<void>
  addImageAsLayer: (file: File) => Promise<void>

  // Background color
  setBackgroundColor: (color: string) => void

  // Layer trimming
  trimLayer: (layerId: string, effectPadding?: number) => void

  // Layer cropping
  cropLayerToBounds: (layerId: string, originalBounds?: { x: number; y: number; width: number; height: number }, cropBounds?: { x: number; y: number; width: number; height: number }) => void

  // Text Style Favorites
  textStyleFavorites: TextStyleFavorite[]
  fetchTextStyleFavorites: () => Promise<void>
  saveTextStyleFavorite: (name: string) => Promise<void>
  applyTextStyleFavorite: (styleId: number) => void
  deleteTextStyleFavorite: (styleId: number) => Promise<void>
  renameTextStyleFavorite: (styleId: number, name: string) => Promise<void>

  // Layer Assets (Library)
  layerAssets: LayerAsset[]
  fetchLayerAssets: () => Promise<void>
  saveLayerToLibrary: (layerId: string, name: string, category?: string) => Promise<void>
  insertLayerFromLibrary: (assetId: number) => Promise<void>
  deleteLayerAsset: (assetId: number) => Promise<void>
  renameLayerAsset: (assetId: number, name: string) => Promise<void>
  updateLayerAssetCategory: (assetId: number, category: string) => Promise<void>

  // Helpers
  getSelectedLayer: () => Layer | null
  getLayerById: (layerId: string) => Layer | null
}

export const useLayerStore = create<LayerState>()(
  subscribeWithSelector(
    persist(
      (set, get) => ({
        // Initial state
        viewMode: 'projects',
        currentProject: null,
        projects: [],
        savedProjects: {},
        isDirty: false,
        isLoading: false,
        selectedLayerId: null,
        recentColors: ['#000000', '#ffffff', '#ff0000', '#00ff00', '#0000ff'],
        textStyleFavorites: [],
        layerAssets: [],

        // View mode
        setViewMode: (mode) => set({ viewMode: mode }),

        addRecentColor: (color) =>
          set((state) => {
            const normalizedColor = color.toLowerCase()
            const filtered = state.recentColors.filter((c) => c.toLowerCase() !== normalizedColor)
            return {
              recentColors: [normalizedColor, ...filtered].slice(0, 10),
            }
          }),

        // Project operations
        newProject: (name, width, height) => {
          const project = createProject(generateId(), name, width, height)

          set((state) => ({
            currentProject: project,
            projects: [
              { id: project.id, name: project.name, updatedAt: project.updatedAt, width: project.width, height: project.height },
              ...state.projects,
            ],
            savedProjects: {
              ...state.savedProjects,
              [project.id]: project,
            },
            viewMode: 'editor',
            selectedLayerId: project.layers[0]?.id || null,
            isDirty: false,
          }))

          // Save to backend immediately
          setTimeout(() => {
            get().saveProjectToBackend()
          }, 100)
        },

        openProject: async (projectId) => {
          set({ isLoading: true })
          try {
            // Try to fetch from backend first
            const response = await fetch(`/api/imageeditor/projects/${projectId}`, {
              credentials: 'include',
            })

            if (response.ok) {
              const data = await response.json()
              const project: ImageProject = {
                id: data.project_id,
                name: data.name,
                width: data.width,
                height: data.height,
                layers: data.project_data.layers || [],
                backgroundColor: data.project_data.backgroundColor || 'transparent',
                createdAt: new Date(data.created_at).getTime(),
                updatedAt: new Date(data.updated_at).getTime(),
              }

              set({
                currentProject: project,
                viewMode: 'editor',
                selectedLayerId: project.layers[0]?.id || null,
                isDirty: false,
                isLoading: false,
              })
            } else {
              // Fallback to local storage
              const { savedProjects } = get()
              const project = savedProjects[projectId]
              if (project) {
                set({
                  currentProject: project,
                  viewMode: 'editor',
                  selectedLayerId: project.layers[0]?.id || null,
                  isDirty: false,
                  isLoading: false,
                })
              } else {
                // No project found - go back to projects view
                set({ isLoading: false, viewMode: 'projects', currentProject: null })
              }
            }
          } catch (error) {
            console.error('Failed to open project:', error)
            set({ isLoading: false, viewMode: 'projects', currentProject: null })
          }
        },

        saveProject: async () => {
          const { currentProject, saveProjectToBackend } = get()
          if (!currentProject) return

          // Update locally first
          const updatedProject = {
            ...currentProject,
            updatedAt: Date.now(),
          }

          set((state) => ({
            currentProject: updatedProject,
            projects: state.projects.map((p) =>
              p.id === currentProject.id
                ? { ...p, updatedAt: Date.now() }
                : p
            ),
            savedProjects: {
              ...state.savedProjects,
              [currentProject.id]: updatedProject,
            },
            isDirty: false,
          }))

          // Save to backend
          await saveProjectToBackend()
        },

        saveProjectToBackend: async () => {
          const { currentProject } = get()
          if (!currentProject) return

          try {
            // Generate thumbnail
            const thumbnail = await generateThumbnail(currentProject)

            const response = await fetch('/api/imageeditor/projects', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'X-CSRFToken': csrfToken(),
              },
              credentials: 'include',
              body: JSON.stringify({
                project_id: currentProject.id,
                name: currentProject.name,
                width: currentProject.width,
                height: currentProject.height,
                project_data: {
                  layers: currentProject.layers,
                  backgroundColor: currentProject.backgroundColor,
                },
                thumbnail,
              }),
            })

            if (response.ok) {
              // Update project list with new thumbnail
              set((state) => ({
                projects: state.projects.map((p) =>
                  p.id === currentProject.id
                    ? { ...p, thumbnailUrl: thumbnail, updatedAt: Date.now() }
                    : p
                ),
              }))
              useCanvasStore.getState().showToast('Projekt gespeichert', 'success')
            } else {
              useCanvasStore.getState().showToast('Fehler beim Speichern', 'error')
            }
          } catch (error) {
            console.error('Failed to save project to backend:', error)
            useCanvasStore.getState().showToast('Fehler beim Speichern', 'error')
          }
        },

        loadProjectsFromBackend: async () => {
          set({ isLoading: true })
          try {
            const response = await fetch('/api/imageeditor/projects', {
              credentials: 'include',
            })

            if (response.ok) {
              const data = await response.json()
              const projects = data.map((p: { project_id: string; name: string; width: number; height: number; thumbnail: string; updated_at: string }) => ({
                id: p.project_id,
                name: p.name,
                updatedAt: new Date(p.updated_at).getTime(),
                thumbnailUrl: p.thumbnail || undefined,
                width: p.width,
                height: p.height,
              }))

              set({ projects, isLoading: false })
            } else {
              set({ isLoading: false })
            }
          } catch (error) {
            console.error('Failed to load projects from backend:', error)
            set({ isLoading: false })
          }
        },

        closeProject: () => {
          const { currentProject, saveProjectToBackend } = get()

          // Save current project to backend before closing
          if (currentProject) {
            saveProjectToBackend()
          }

          set({
            currentProject: null,
            viewMode: 'projects',
            selectedLayerId: null,
          })
        },

        deleteProject: async (projectId) => {
          const project = get().projects.find(p => p.id === projectId)
          const confirmed = await useConfirmStore.getState().confirm({
            title: 'Projekt löschen',
            message: `"${project?.name || 'Untitled'}" wirklich löschen? Das kann nicht rückgängig gemacht werden.`,
            confirmLabel: 'Löschen',
            variant: 'danger',
          })
          if (!confirmed) return

          try {
            await fetch(`/api/imageeditor/projects/${projectId}`, {
              method: 'DELETE',
              credentials: 'include',
              headers: { 'X-CSRFToken': csrfToken() },
            })
          } catch (error) {
            console.error('Failed to delete project from backend:', error)
          }

          set((state) => ({
            projects: state.projects.filter((p) => p.id !== projectId),
            savedProjects: Object.fromEntries(
              Object.entries(state.savedProjects).filter(([key]) => key !== projectId)
            ),
          }))
        },

        updateProjectName: (name) =>
          set((state) => ({
            currentProject: state.currentProject
              ? { ...state.currentProject, name, updatedAt: Date.now() }
              : null,
            projects: state.projects.map((p) =>
              p.id === state.currentProject?.id ? { ...p, name } : p
            ),
            isDirty: true,
          })),

        // Project Export/Import
        exportProject: () => {
          const { currentProject } = get()
          if (!currentProject) {
            useCanvasStore.getState().showToast('Kein Projekt zum Exportieren vorhanden', 'error')
            return
          }

          try {
            // Create export data with version info
            const exportData = {
              version: '1.0',
              exportedAt: new Date().toISOString(),
              project: {
                ...currentProject,
                id: currentProject.id,
                name: currentProject.name,
                width: currentProject.width,
                height: currentProject.height,
                backgroundColor: currentProject.backgroundColor,
                layers: currentProject.layers,
                createdAt: currentProject.createdAt,
                updatedAt: currentProject.updatedAt,
              },
            }

            // Convert to JSON string with formatting
            const jsonString = JSON.stringify(exportData, null, 2)
            const blob = new Blob([jsonString], { type: 'application/json' })

            // Create download link
            const url = URL.createObjectURL(blob)
            const link = document.createElement('a')
            link.href = url
            link.download = `${currentProject.name.replace(/[^a-zA-Z0-9-_]/g, '_')}.imgeditor`
            document.body.appendChild(link)
            link.click()
            document.body.removeChild(link)
            URL.revokeObjectURL(url)

            useCanvasStore.getState().showToast(`Projekt "${currentProject.name}" exportiert`, 'success')
          } catch (error) {
            console.error('Export failed:', error)
            useCanvasStore.getState().showToast('Export fehlgeschlagen', 'error')
          }
        },

        importProject: async (file: File) => {
          try {
            // Read file content
            const text = await file.text()
            const data = JSON.parse(text)

            // Validate file structure
            if (!data.project || !data.project.layers) {
              throw new Error('Ungültiges Projektformat')
            }

            // Check version compatibility
            const version = data.version || '1.0'
            if (version !== '1.0') {
              console.warn(`Project version ${version} may not be fully compatible`)
            }

            const importedProject = data.project

            // Generate new ID to avoid conflicts
            const newId = generateId()

            // Create project with imported data
            const project: ImageProject = {
              id: newId,
              name: importedProject.name + ' (Import)',
              width: importedProject.width || 1920,
              height: importedProject.height || 1080,
              backgroundColor: importedProject.backgroundColor || 'transparent',
              layers: importedProject.layers.map((layer: Layer) => ({
                ...layer,
                id: generateId(), // Generate new layer IDs to avoid conflicts
              })),
              createdAt: Date.now(),
              updatedAt: Date.now(),
            }

            // Set as current project
            set({
              currentProject: project,
              selectedLayerId: project.layers[0]?.id || null,
              viewMode: 'editor',
              isDirty: true,
            })

            // Save to backend
            await get().saveProjectToBackend()

            // Reload project list
            await get().loadProjectsFromBackend()

            useCanvasStore.getState().showToast(`Projekt "${importedProject.name}" importiert`, 'success')
          } catch (error) {
            console.error('Import failed:', error)
            useCanvasStore.getState().showToast(error instanceof Error ? error.message : 'Import fehlgeschlagen', 'error')
          }
        },

        // Layer operations
        addLayer: (layerOrType, name) => {
          const { currentProject } = get()
          if (!currentProject) return

          // Check if first arg is a full Layer object or just a LayerType
          let newLayer: Layer
          if (typeof layerOrType === 'string') {
            // It's a LayerType
            const layerCount = currentProject.layers.length
            newLayer = createLayer(
              generateId(),
              name || `Layer ${layerCount + 1}`,
              layerOrType as LayerType,
              currentProject.width,
              currentProject.height
            )
          } else {
            // It's a full Layer object
            newLayer = layerOrType as Layer
          }

          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: [...state.currentProject.layers, newLayer],
                  updatedAt: Date.now(),
                }
              : null,
            selectedLayerId: newLayer.id,
            isDirty: true,
          }))
        },

        deleteLayer: (layerId) => {
          const { currentProject, selectedLayerId } = get()
          if (!currentProject || currentProject.layers.length <= 1) return

          useHistoryStore.getState().pushHistory('Delete Layer')

          const layerIndex = currentProject.layers.findIndex((l) => l.id === layerId)
          const newLayers = currentProject.layers.filter((l) => l.id !== layerId)
          const newSelectedId =
            selectedLayerId === layerId
              ? newLayers[Math.max(0, layerIndex - 1)]?.id || null
              : selectedLayerId

          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: newLayers,
                  updatedAt: Date.now(),
                }
              : null,
            selectedLayerId: newSelectedId,
            isDirty: true,
          }))
        },

        duplicateLayer: (layerId) => {
          const { currentProject } = get()
          if (!currentProject) return

          const layer = currentProject.layers.find((l) => l.id === layerId)
          if (!layer) return

          useHistoryStore.getState().pushHistory('Duplicate Layer')

          const newLayer: Layer = {
            ...layer,
            id: generateId(),
            name: `${layer.name} Copy`,
          }

          const layerIndex = currentProject.layers.findIndex((l) => l.id === layerId)

          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: [
                    ...state.currentProject.layers.slice(0, layerIndex + 1),
                    newLayer,
                    ...state.currentProject.layers.slice(layerIndex + 1),
                  ],
                  updatedAt: Date.now(),
                }
              : null,
            selectedLayerId: newLayer.id,
            isDirty: true,
          }))

          useCanvasStore.getState().showToast('Layer duplicated', 'success')
        },

        selectLayer: (layerId) => set({ selectedLayerId: layerId }),

        reorderLayer: (layerId, newIndex) => {
          const { currentProject } = get()
          if (!currentProject) return

          const layers = [...currentProject.layers]
          const currentIndex = layers.findIndex((l) => l.id === layerId)
          if (currentIndex === -1 || newIndex === currentIndex) return

          useHistoryStore.getState().pushHistory('Reorder Layer')

          const [layer] = layers.splice(currentIndex, 1)
          layers.splice(newIndex, 0, layer)

          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers,
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          }))
        },

        toggleLayerVisibility: (layerId) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, visible: !l.visible } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
          })),

        toggleLayerLock: (layerId) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, locked: !l.locked } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
          })),

        setLayerOpacity: (layerId, opacity) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, opacity: Math.max(0, Math.min(100, opacity)) } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        setLayerBlendMode: (layerId, blendMode) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, blendMode } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        updateLayerImage: (layerId, imageData) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, imageData } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        updateLayerText: (layerId, text) =>
          set((state) => {
            if (!state.currentProject) return { currentProject: null, isDirty: true }

            const layer = state.currentProject.layers.find((l) => l.id === layerId)
            if (!layer) return state

            // Measure text to calculate new dimensions
            const canvas = document.createElement('canvas')
            const ctx = canvas.getContext('2d')
            if (!ctx) return state

            const fontSize = layer.fontSize || 48
            const fontFamily = layer.fontFamily || 'Arial'
            const fontWeight = layer.fontWeight || 400

            ctx.font = `${fontWeight} ${fontSize}px "${fontFamily}"`

            const lines = text.split('\n')
            let maxWidth = 0
            for (const line of lines) {
              const metrics = ctx.measureText(line)
              maxWidth = Math.max(maxWidth, metrics.width)
            }

            // Extra padding for effects (shadow, glow, outline)
            const effectPadding = 40
            const newWidth = Math.max(100, Math.ceil(maxWidth) + effectPadding)
            const newHeight = Math.max(50, Math.ceil(fontSize * 1.3 * lines.length) + effectPadding)

            return {
              currentProject: {
                ...state.currentProject,
                layers: state.currentProject.layers.map((l) =>
                  l.id === layerId
                    ? {
                        ...l,
                        text,
                        width: newWidth,
                        height: newHeight,
                        name: `Text: ${text.slice(0, 15)}${text.length > 15 ? '...' : ''}`,
                      }
                    : l
                ),
                updatedAt: Date.now(),
              },
              isDirty: true,
            }
          }),

        updateLayerTextProperties: (layerId, props) =>
          set((state) => {
            if (!state.currentProject) return { currentProject: null, isDirty: true }

            const layer = state.currentProject.layers.find((l) => l.id === layerId)
            if (!layer || layer.type !== 'text') return state

            // Only recalculate dimensions if fontSize or fontFamily changed
            const needsResize = props.fontSize !== undefined || props.fontFamily !== undefined

            let newWidth = layer.width
            let newHeight = layer.height

            if (needsResize) {
              const fontSize = props.fontSize ?? layer.fontSize ?? 48
              const fontFamily = props.fontFamily ?? layer.fontFamily ?? 'Arial'
              const fontWeight = props.fontWeight ?? layer.fontWeight ?? 400
              const text = layer.text || ''

              const canvas = document.createElement('canvas')
              const ctx = canvas.getContext('2d')
              if (ctx) {
                ctx.font = `${fontWeight} ${fontSize}px "${fontFamily}"`

                const lines = text.split('\n')
                let maxWidth = 0
                for (const line of lines) {
                  const metrics = ctx.measureText(line)
                  maxWidth = Math.max(maxWidth, metrics.width)
                }

                const effectPadding = 40
                newWidth = Math.max(100, Math.ceil(maxWidth) + effectPadding)
                newHeight = Math.max(50, Math.ceil(fontSize * 1.3 * lines.length) + effectPadding)
              }
            }

            return {
              currentProject: {
                ...state.currentProject,
                layers: state.currentProject.layers.map((l) =>
                  l.id === layerId
                    ? {
                        ...l,
                        ...props,
                        width: newWidth,
                        height: newHeight,
                      }
                    : l
                ),
                updatedAt: Date.now(),
              },
              isDirty: true,
            }
          }),

        updateLayerTextEffects: (layerId, textEffects) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, textEffects } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        updateLayerEffects: (layerId, layerEffects) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, layerEffects } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        setLayerPosition: (layerId, x, y) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, x, y } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        resizeLayer: (layerId, width, height) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, width: Math.max(1, width), height: Math.max(1, height) } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        setLayerTransform: (layerId, x, y, width, height) =>
          set((state) => {
            if (!state.currentProject) return { currentProject: null }

            const layer = state.currentProject.layers.find((l) => l.id === layerId)
            if (!layer) return {}

            // For text layers, scale fontSize proportionally
            let newFontSize = layer.fontSize
            if (layer.type === 'text' && layer.fontSize && layer.height > 0) {
              const scaleFactor = height / layer.height
              newFontSize = Math.max(8, Math.round(layer.fontSize * scaleFactor))
            }

            return {
              currentProject: {
                ...state.currentProject,
                layers: state.currentProject.layers.map((l) =>
                  l.id === layerId
                    ? {
                        ...l,
                        x,
                        y,
                        width: Math.max(1, width),
                        height: Math.max(1, height),
                        ...(l.type === 'text' ? { fontSize: newFontSize } : {}),
                      }
                    : l
                ),
                updatedAt: Date.now(),
              },
              isDirty: true,
            }
          }),

        setBackgroundColor: (color) =>
          set((state) => ({
            currentProject: state.currentProject
              ? { ...state.currentProject, backgroundColor: color, updatedAt: Date.now() }
              : null,
            isDirty: true,
          })),

        renameLayer: (layerId, name) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, name } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        rotateLayer: (layerId, degrees) => {
          const { currentProject } = get()
          if (!currentProject) return

          const layer = currentProject.layers.find((l) => l.id === layerId)
          if (!layer || layer.locked) return

          useHistoryStore.getState().pushHistory('Rotate')

          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId ? { ...l, rotation: (l.rotation + degrees) % 360 } : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          }))
        },

        // Absolute rotation — used by canvas drag handle where we compute the
        // target angle each mousemove and can't go through the delta-based
        // rotateLayer (which would compound every frame).
        setLayerRotation: (layerId, degrees) =>
          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === layerId && !l.locked
                      ? { ...l, rotation: ((degrees % 360) + 360) % 360 }
                      : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          })),

        flipLayerHorizontal: (layerId) => {
          const { currentProject } = get()
          if (!currentProject) return

          const layer = currentProject.layers.find((l) => l.id === layerId)
          if (!layer || layer.locked || !layer.imageData) return

          useHistoryStore.getState().pushHistory('Flip Horizontal')

          const img = new Image()
          img.onload = () => {
            // Use the image's natural resolution, not the layer's display size —
            // otherwise high-res images get cropped/downscaled on every flip.
            const canvas = document.createElement('canvas')
            canvas.width = img.naturalWidth || img.width
            canvas.height = img.naturalHeight || img.height
            const ctx = canvas.getContext('2d')
            if (!ctx) return

            ctx.translate(canvas.width, 0)
            ctx.scale(-1, 1)
            ctx.drawImage(img, 0, 0)

            set((state) => ({
              currentProject: state.currentProject
                ? {
                    ...state.currentProject,
                    layers: state.currentProject.layers.map((l) =>
                      l.id === layerId ? { ...l, imageData: canvas.toDataURL('image/png') } : l
                    ),
                    updatedAt: Date.now(),
                  }
                : null,
              isDirty: true,
            }))
          }
          img.src = layer.imageData
        },

        flipLayerVertical: (layerId) => {
          const { currentProject } = get()
          if (!currentProject) return

          const layer = currentProject.layers.find((l) => l.id === layerId)
          if (!layer || layer.locked || !layer.imageData) return

          useHistoryStore.getState().pushHistory('Flip Vertical')

          const img = new Image()
          img.onload = () => {
            const canvas = document.createElement('canvas')
            canvas.width = img.naturalWidth || img.width
            canvas.height = img.naturalHeight || img.height
            const ctx = canvas.getContext('2d')
            if (!ctx) return

            ctx.translate(0, canvas.height)
            ctx.scale(1, -1)
            ctx.drawImage(img, 0, 0)

            set((state) => ({
              currentProject: state.currentProject
                ? {
                    ...state.currentProject,
                    layers: state.currentProject.layers.map((l) =>
                      l.id === layerId ? { ...l, imageData: canvas.toDataURL('image/png') } : l
                    ),
                    updatedAt: Date.now(),
                  }
                : null,
              isDirty: true,
            }))
          }
          img.src = layer.imageData
        },

        mergeLayerDown: async (layerId) => {
          const { currentProject, selectedLayerId } = get()
          if (!currentProject) return

          const layerIndex = currentProject.layers.findIndex((l) => l.id === layerId)
          if (layerIndex <= 0) return // Can't merge first layer

          const topLayer = currentProject.layers[layerIndex]
          const bottomLayer = currentProject.layers[layerIndex - 1]

          if (bottomLayer.locked) return // Can't merge into locked layer

          useHistoryStore.getState().pushHistory('Merge Down')

          // Create a canvas to composite the layers
          const canvas = document.createElement('canvas')
          canvas.width = currentProject.width
          canvas.height = currentProject.height
          const ctx = canvas.getContext('2d')
          if (!ctx) return

          // Helper to load image and wait for it
          const loadImage = (src: string): Promise<HTMLImageElement> => {
            return new Promise((resolve, reject) => {
              const img = new Image()
              img.onload = () => resolve(img)
              img.onerror = reject
              img.src = src
            })
          }

          // Helper to draw a layer with proper position, rotation, and scale
          const drawLayer = (ctx: CanvasRenderingContext2D, layer: Layer, img: HTMLImageElement) => {
            ctx.save()
            ctx.globalAlpha = layer.opacity / 100
            if (layer.blendMode && layer.blendMode !== 'normal') {
              ctx.globalCompositeOperation = layer.blendMode as GlobalCompositeOperation
            }
            // Translate to layer center
            ctx.translate(layer.x + layer.width / 2, layer.y + layer.height / 2)
            // Apply rotation
            ctx.rotate((layer.rotation * Math.PI) / 180)
            // Draw image scaled to layer dimensions, centered at origin
            ctx.drawImage(img, -layer.width / 2, -layer.height / 2, layer.width, layer.height)
            ctx.restore()
          }

          try {
            // Draw bottom layer first (wait for image to load)
            if (bottomLayer.imageData) {
              const bottomImg = await loadImage(bottomLayer.imageData)
              drawLayer(ctx, bottomLayer, bottomImg)
            }

            // Draw top layer on top (wait for image to load)
            if (topLayer.imageData) {
              const topImg = await loadImage(topLayer.imageData)
              drawLayer(ctx, topLayer, topImg)
            }

            const mergedImageData = canvas.toDataURL('image/png')

            // Update the bottom layer with merged content and remove top layer
            const newLayers = currentProject.layers.filter((l) => l.id !== layerId)
            const bottomLayerIndex = newLayers.findIndex((l) => l.id === bottomLayer.id)
            newLayers[bottomLayerIndex] = {
              ...bottomLayer,
              imageData: mergedImageData,
              opacity: 100,
              blendMode: 'normal',
              x: 0,
              y: 0,
              width: currentProject.width,
              height: currentProject.height,
              rotation: 0,
            }

            set((state) => ({
              currentProject: state.currentProject
                ? {
                    ...state.currentProject,
                    layers: newLayers,
                    updatedAt: Date.now(),
                  }
                : null,
              selectedLayerId: selectedLayerId === layerId ? bottomLayer.id : selectedLayerId,
              isDirty: true,
            }))

            useCanvasStore.getState().showToast('Layers merged', 'success')
          } catch (error) {
            console.error('Failed to merge layers:', error)
            useCanvasStore.getState().showToast('Failed to merge layers', 'error')
          }
        },

        flattenLayers: async () => {
          const { currentProject } = get()
          if (!currentProject) return
          if (currentProject.layers.length <= 1) return // Nothing to flatten

          useHistoryStore.getState().pushHistory('Flatten')

          // Create a canvas to composite all layers
          const canvas = document.createElement('canvas')
          canvas.width = currentProject.width
          canvas.height = currentProject.height
          const ctx = canvas.getContext('2d')
          if (!ctx) return

          // Fill with background color
          ctx.fillStyle = currentProject.backgroundColor
          ctx.fillRect(0, 0, canvas.width, canvas.height)

          // Helper to load image and wait for it
          const loadImage = (src: string): Promise<HTMLImageElement> => {
            return new Promise((resolve, reject) => {
              const img = new Image()
              img.onload = () => resolve(img)
              img.onerror = reject
              img.src = src
            })
          }

          try {
            // Draw all visible layers in order (with proper async loading)
            for (const layer of currentProject.layers) {
              if (!layer.visible || !layer.imageData) continue

              const img = await loadImage(layer.imageData)

              ctx.save()
              ctx.globalAlpha = layer.opacity / 100
              if (layer.blendMode && layer.blendMode !== 'normal') {
                ctx.globalCompositeOperation = layer.blendMode as GlobalCompositeOperation
              }
              ctx.translate(layer.x + layer.width / 2, layer.y + layer.height / 2)
              ctx.rotate((layer.rotation * Math.PI) / 180)
              // Draw image scaled to layer dimensions
              ctx.drawImage(img, -layer.width / 2, -layer.height / 2, layer.width, layer.height)
              ctx.restore()
            }

            const flattenedImageData = canvas.toDataURL('image/png')

            // Create a single flattened layer
            const flattenedLayer: Layer = {
              id: generateId(),
              name: 'Flattened',
              type: 'image',
              visible: true,
              locked: false,
              opacity: 100,
              blendMode: 'normal',
              x: 0,
              y: 0,
              width: currentProject.width,
              height: currentProject.height,
              rotation: 0,
              imageData: flattenedImageData,
            }

            set((state) => ({
              currentProject: state.currentProject
                ? {
                    ...state.currentProject,
                    layers: [flattenedLayer],
                    updatedAt: Date.now(),
                  }
                : null,
              selectedLayerId: flattenedLayer.id,
              isDirty: true,
            }))

            useCanvasStore.getState().showToast('All layers flattened', 'success')
          } catch (error) {
            console.error('Failed to flatten layers:', error)
            useCanvasStore.getState().showToast('Failed to flatten layers', 'error')
          }
        },

        // Image import
        importImage: async (file) => {
          const { newProject } = get()

          return new Promise((resolve, reject) => {
            const reader = new FileReader()
            reader.onload = (e) => {
              const img = new Image()
              img.onload = () => {
                // Create new project with image dimensions
                newProject(file.name.replace(/\.[^/.]+$/, ''), img.width, img.height)

                // Update the background layer with the image
                const canvas = document.createElement('canvas')
                canvas.width = img.width
                canvas.height = img.height
                const ctx = canvas.getContext('2d')
                if (ctx) {
                  ctx.drawImage(img, 0, 0)
                  const imageData = canvas.toDataURL('image/png')

                  set((state) => ({
                    currentProject: state.currentProject
                      ? {
                          ...state.currentProject,
                          layers: state.currentProject.layers.map((l, i) =>
                            i === 0 ? { ...l, imageData, name: file.name } : l
                          ),
                        }
                      : null,
                  }))

                  // Auto-save to backend after import
                  setTimeout(() => {
                    get().saveProjectToBackend()
                  }, 100)
                }
                resolve()
              }
              img.onerror = reject
              img.src = e.target?.result as string
            }
            reader.onerror = reject
            reader.readAsDataURL(file)
          })
        },

        importImageToLayer: async (file, layerId) => {
          const { currentProject } = get()
          if (!currentProject) return

          useHistoryStore.getState().pushHistory('Import Image')

          return new Promise((resolve, reject) => {
            const reader = new FileReader()
            reader.onload = (e) => {
              const img = new Image()
              img.onload = () => {
                const canvas = document.createElement('canvas')
                canvas.width = img.width
                canvas.height = img.height
                const ctx = canvas.getContext('2d')
                if (ctx) {
                  ctx.drawImage(img, 0, 0)
                  const imageData = canvas.toDataURL('image/png')

                  set((state) => ({
                    currentProject: state.currentProject
                      ? {
                          ...state.currentProject,
                          layers: state.currentProject.layers.map((l) =>
                            l.id === layerId
                              ? { ...l, imageData, width: img.width, height: img.height }
                              : l
                          ),
                          updatedAt: Date.now(),
                        }
                      : null,
                    isDirty: true,
                  }))

                  // Auto-save to backend after import
                  setTimeout(() => {
                    get().saveProjectToBackend()
                  }, 100)
                }
                resolve()
              }
              img.onerror = reject
              img.src = e.target?.result as string
            }
            reader.onerror = reject
            reader.readAsDataURL(file)
          })
        },

        addImageAsLayer: async (file) => {
          const { currentProject } = get()
          if (!currentProject) return

          return new Promise((resolve, reject) => {
            const reader = new FileReader()
            reader.onload = (e) => {
              const img = new Image()
              img.onload = () => {
                useHistoryStore.getState().pushHistory('Add Image Layer')

                const canvas = document.createElement('canvas')
                canvas.width = img.width
                canvas.height = img.height
                const ctx = canvas.getContext('2d')
                if (ctx) {
                  ctx.drawImage(img, 0, 0)
                  const imageData = canvas.toDataURL('image/png')

                  const newLayer: Layer = {
                    id: generateId(),
                    name: file.name.replace(/\.[^/.]+$/, ''),
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
                  }

                  set((state) => ({
                    currentProject: state.currentProject
                      ? {
                          ...state.currentProject,
                          layers: [...state.currentProject.layers, newLayer],
                          updatedAt: Date.now(),
                        }
                      : null,
                    selectedLayerId: newLayer.id,
                    isDirty: true,
                  }))

                  // Auto-save to backend after adding image layer
                  setTimeout(() => {
                    get().saveProjectToBackend()
                  }, 100)
                }
                resolve()
              }
              img.onerror = reject
              img.src = e.target?.result as string
            }
            reader.onerror = reject
            reader.readAsDataURL(file)
          })
        },

        // Trim layer - remove transparent areas with padding for effects
        trimLayer: (layerId, effectPadding = 30) => {
          const { currentProject } = get()
          if (!currentProject) return

          const layer = currentProject.layers.find((l) => l.id === layerId)
          if (!layer || !layer.imageData) return

          // Load the image and analyze pixel data
          const img = new Image()
          img.onload = () => {
            const canvas = document.createElement('canvas')
            canvas.width = img.width
            canvas.height = img.height
            const ctx = canvas.getContext('2d')
            if (!ctx) return

            ctx.drawImage(img, 0, 0)
            const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
            const data = imageData.data

            // Find bounding box of non-transparent pixels
            let minX = canvas.width
            let minY = canvas.height
            let maxX = 0
            let maxY = 0
            let hasContent = false

            for (let y = 0; y < canvas.height; y++) {
              for (let x = 0; x < canvas.width; x++) {
                const alpha = data[(y * canvas.width + x) * 4 + 3]
                if (alpha > 10) { // Threshold for "not transparent"
                  hasContent = true
                  minX = Math.min(minX, x)
                  minY = Math.min(minY, y)
                  maxX = Math.max(maxX, x)
                  maxY = Math.max(maxY, y)
                }
              }
            }

            if (!hasContent) return // Layer is fully transparent

            // Add padding for effects (blur, shadow, glow)
            minX = Math.max(0, minX - effectPadding)
            minY = Math.max(0, minY - effectPadding)
            maxX = Math.min(canvas.width - 1, maxX + effectPadding)
            maxY = Math.min(canvas.height - 1, maxY + effectPadding)

            const newWidth = maxX - minX + 1
            const newHeight = maxY - minY + 1

            // Skip if trimming wouldn't save much space
            if (newWidth >= canvas.width * 0.9 && newHeight >= canvas.height * 0.9) {
              return
            }

            // Create new cropped canvas
            const croppedCanvas = document.createElement('canvas')
            croppedCanvas.width = newWidth
            croppedCanvas.height = newHeight
            const croppedCtx = croppedCanvas.getContext('2d')
            if (!croppedCtx) return

            croppedCtx.drawImage(
              canvas,
              minX, minY, newWidth, newHeight,
              0, 0, newWidth, newHeight
            )

            useHistoryStore.getState().pushHistory('Trim Layer')

            // Update layer with new position, size, and image data
            set((state) => ({
              currentProject: state.currentProject
                ? {
                    ...state.currentProject,
                    layers: state.currentProject.layers.map((l) =>
                      l.id === layerId
                        ? {
                            ...l,
                            x: l.x + minX,
                            y: l.y + minY,
                            width: newWidth,
                            height: newHeight,
                            imageData: croppedCanvas.toDataURL('image/png'),
                          }
                        : l
                    ),
                    updatedAt: Date.now(),
                  }
                : null,
              isDirty: true,
            }))
          }
          img.src = layer.imageData
        },

        // Crop layer to current bounds (apply resize as actual crop)
        cropLayerToBounds: (layerId, originalBounds, cropBounds) => {
          const { currentProject } = get()
          if (!currentProject) return

          const layer = currentProject.layers.find((l) => l.id === layerId)
          if (!layer || !layer.imageData) {
            useCanvasStore.getState().showToast('Layer hat keine Bilddaten zum Zuschneiden', 'error')
            return
          }

          const img = new Image()
          img.onload = () => {
            // Use cropBounds if provided (new crop box), otherwise use layer bounds
            const targetWidth = cropBounds?.width ?? layer.width
            const targetHeight = cropBounds?.height ?? layer.height
            const targetX = cropBounds?.x ?? layer.x
            const targetY = cropBounds?.y ?? layer.y

            // Create canvas at the target crop size
            const canvas = document.createElement('canvas')
            canvas.width = targetWidth
            canvas.height = targetHeight
            const ctx = canvas.getContext('2d')
            if (!ctx) return

            if (originalBounds) {
              // True crop: extract portion of original image
              // Calculate the crop region in the original image coordinates
              const scaleX = img.width / originalBounds.width
              const scaleY = img.height / originalBounds.height

              // Offset from original position (how much was cropped from left/top)
              const offsetX = targetX - originalBounds.x
              const offsetY = targetY - originalBounds.y

              // Source rect in the original image
              const srcX = offsetX * scaleX
              const srcY = offsetY * scaleY
              const srcW = targetWidth * scaleX
              const srcH = targetHeight * scaleY

              // Draw the cropped portion
              ctx.drawImage(
                img,
                srcX, srcY, srcW, srcH,  // Source rect (from original image)
                0, 0, targetWidth, targetHeight  // Destination (full canvas)
              )
            } else {
              // Scale mode: just scale the image to fit current bounds
              ctx.drawImage(img, 0, 0, targetWidth, targetHeight)
            }

            useHistoryStore.getState().pushHistory('Crop Layer')

            // Update layer with new image data AND new position/size
            set((state) => ({
              currentProject: state.currentProject
                ? {
                    ...state.currentProject,
                    layers: state.currentProject.layers.map((l) =>
                      l.id === layerId
                        ? {
                            ...l,
                            x: targetX,
                            y: targetY,
                            width: targetWidth,
                            height: targetHeight,
                            imageData: canvas.toDataURL('image/png'),
                          }
                        : l
                    ),
                    updatedAt: Date.now(),
                  }
                : null,
              isDirty: true,
            }))

            useCanvasStore.getState().showToast('Layer zugeschnitten', 'success')
          }
          img.src = layer.imageData
        },

        // Text Style Favorites
        fetchTextStyleFavorites: async () => {
          try {
            const styles = await api.get<TextStyleFavorite[]>('/documents/text-styles/')
            set({ textStyleFavorites: styles })
          } catch (error) {
            console.error('Failed to fetch text styles:', error)
          }
        },

        saveTextStyleFavorite: async (name) => {
          const { currentProject, selectedLayerId, fetchTextStyleFavorites } = get()
          if (!currentProject) return

          const layer = currentProject.layers.find((l) => l.id === selectedLayerId)
          if (!layer || layer.type !== 'text') {
            useCanvasStore.getState().showToast('Kein Text-Layer ausgewählt', 'error')
            return
          }

          try {
            const styleData = {
              name: name || `Style ${get().textStyleFavorites.length + 1}`,
              fontFamily: layer.fontFamily || 'SF Pro Display',
              fontSize: layer.fontSize || 48,
              fontWeight: layer.fontWeight || 400,
              fontColor: layer.fontColor || '#ffffff',
              textAlign: layer.textAlign || 'center',
              textEffects: layer.textEffects || {
                shadow: { enabled: false, offsetX: 4, offsetY: 4, blur: 8, color: '#000000' },
                outline: { enabled: false, width: 2, color: '#000000' },
                glow: { enabled: false, color: '#ff00ff', intensity: 20 },
                curve: 0,
              },
            }

            await api.post('/documents/text-styles/', styleData)
            await fetchTextStyleFavorites()
            useCanvasStore.getState().showToast(`Style "${name}" gespeichert`, 'success')
          } catch (error) {
            console.error('Failed to save text style:', error)
            useCanvasStore.getState().showToast('Fehler beim Speichern des Stils', 'error')
          }
        },

        applyTextStyleFavorite: (styleId) => {
          const { currentProject, selectedLayerId, textStyleFavorites } = get()
          if (!currentProject || !selectedLayerId) return

          const layer = currentProject.layers.find((l) => l.id === selectedLayerId)
          if (!layer || layer.type !== 'text') {
            useCanvasStore.getState().showToast('Kein Text-Layer ausgewählt', 'error')
            return
          }

          const style = textStyleFavorites.find((s) => s.id === styleId)
          if (!style) return

          useHistoryStore.getState().pushHistory('Apply Text Style')

          set((state) => ({
            currentProject: state.currentProject
              ? {
                  ...state.currentProject,
                  layers: state.currentProject.layers.map((l) =>
                    l.id === selectedLayerId
                      ? {
                          ...l,
                          fontFamily: style.fontFamily,
                          fontSize: style.fontSize,
                          fontWeight: style.fontWeight,
                          fontColor: style.fontColor,
                          textAlign: style.textAlign,
                          textEffects: { ...style.textEffects },
                        }
                      : l
                  ),
                  updatedAt: Date.now(),
                }
              : null,
            isDirty: true,
          }))

          useCanvasStore.getState().showToast(`Style "${style.name}" angewendet`, 'success')
        },

        deleteTextStyleFavorite: async (styleId) => {
          const { fetchTextStyleFavorites } = get()
          try {
            await api.delete(`/documents/text-styles/${styleId}`)
            await fetchTextStyleFavorites()
          } catch (error) {
            console.error('Failed to delete text style:', error)
            useCanvasStore.getState().showToast('Fehler beim Löschen des Stils', 'error')
          }
        },

        renameTextStyleFavorite: async (styleId, name) => {
          const { fetchTextStyleFavorites } = get()
          try {
            await api.patch(`/documents/text-styles/${styleId}`, { name })
            await fetchTextStyleFavorites()
          } catch (error) {
            console.error('Failed to rename text style:', error)
            useCanvasStore.getState().showToast('Fehler beim Umbenennen des Stils', 'error')
          }
        },

        // Layer Assets (Library)
        fetchLayerAssets: async () => {
          try {
            const assets = await api.get<LayerAsset[]>('/documents/layer-assets/')
            const list = Array.isArray(assets) ? assets : []
            set({ layerAssets: list })
          } catch (error) {
            console.error('[Canwa] Failed to fetch layer assets:', error)
            const msg = error instanceof Error ? error.message : String(error)
            useCanvasStore.getState().showToast(`Bibliothek konnte nicht geladen werden: ${msg}`, 'error')
          }
        },

        saveLayerToLibrary: async (layerId, name, category = '') => {
          const { currentProject, fetchLayerAssets } = get()
          if (!currentProject) return

          const layer = currentProject.layers.find((l) => l.id === layerId)
          if (!layer || !layer.imageData) {
            useCanvasStore.getState().showToast('Layer hat keine Bilddaten', 'error')
            return
          }

          try {
            // Convert base64 to Blob for file upload
            const base64ToBlob = (dataUrl: string): Blob => {
              const arr = dataUrl.split(',')
              const mime = arr[0].match(/:(.*?);/)?.[1] || 'image/png'
              const bstr = atob(arr[1])
              let n = bstr.length
              const u8arr = new Uint8Array(n)
              while (n--) {
                u8arr[n] = bstr.charCodeAt(n)
              }
              return new Blob([u8arr], { type: mime })
            }

            // Create thumbnail (max 150px)
            const img = new Image()
            await new Promise<void>((resolve, reject) => {
              img.onload = () => resolve()
              img.onerror = reject
              img.src = layer.imageData!
            })

            const maxThumbSize = 150
            const scale = Math.min(maxThumbSize / img.width, maxThumbSize / img.height, 1)
            const thumbWidth = Math.round(img.width * scale)
            const thumbHeight = Math.round(img.height * scale)

            const thumbCanvas = document.createElement('canvas')
            thumbCanvas.width = thumbWidth
            thumbCanvas.height = thumbHeight
            const thumbCtx = thumbCanvas.getContext('2d')
            if (thumbCtx) {
              thumbCtx.drawImage(img, 0, 0, thumbWidth, thumbHeight)
            }
            const thumbnailDataUrl = thumbCanvas.toDataURL('image/png')

            // Create FormData for file upload
            const formData = new FormData()
            const imageBlob = base64ToBlob(layer.imageData!)
            const thumbnailBlob = base64ToBlob(thumbnailDataUrl)

            formData.append('image', imageBlob, `${name || 'asset'}.png`)
            formData.append('thumbnail', thumbnailBlob, `${name || 'asset'}_thumb.png`)
            formData.append('name', name || `Asset ${get().layerAssets.length + 1}`)
            formData.append('width', String(layer.width))
            formData.append('height', String(layer.height))
            formData.append('category', category)

            await api.postFormData('/documents/layer-assets/', formData)
            await fetchLayerAssets()
            useCanvasStore.getState().showToast(`"${name}" in Bibliothek gespeichert`, 'success')
          } catch (error) {
            console.error('Failed to save layer asset:', error)
            useCanvasStore.getState().showToast('Fehler beim Speichern in Bibliothek', 'error')
          }
        },

        insertLayerFromLibrary: async (assetId) => {
          const { currentProject, layerAssets } = get()
          if (!currentProject) return

          const asset = layerAssets.find((a) => a.id === assetId)
          if (!asset) return

          try {
            // Fetch the image from URL and convert to base64 for canvas
            const response = await fetch(getMediaUrl(asset.imageUrl), { credentials: 'include' })
            const blob = await response.blob()
            const imageData = await new Promise<string>((resolve, reject) => {
              const reader = new FileReader()
              reader.onload = () => resolve(reader.result as string)
              reader.onerror = reject
              reader.readAsDataURL(blob)
            })

            useHistoryStore.getState().pushHistory('Insert from Library')

            // Create a new layer with the fetched image data
            const newLayer: Layer = {
              id: generateId(),
              name: asset.name,
              type: 'image',
              visible: true,
              locked: false,
              opacity: 100,
              blendMode: 'normal',
              x: Math.round((currentProject.width - asset.width) / 2),
              y: Math.round((currentProject.height - asset.height) / 2),
              width: asset.width,
              height: asset.height,
              rotation: 0,
              imageData,
            }

            // Add layer directly to avoid the addLayer logic which creates empty layers
            set((state) => ({
              currentProject: state.currentProject
                ? {
                    ...state.currentProject,
                    layers: [...state.currentProject.layers, newLayer],
                    updatedAt: Date.now(),
                  }
                : null,
              selectedLayerId: newLayer.id,
              isDirty: true,
            }))

            useCanvasStore.getState().showToast(`"${asset.name}" eingefügt`, 'success')
          } catch (error) {
            console.error('Failed to load asset image:', error)
            useCanvasStore.getState().showToast('Fehler beim Laden des Assets', 'error')
          }
        },

        deleteLayerAsset: async (assetId) => {
          const { fetchLayerAssets } = get()
          try {
            await api.delete(`/documents/layer-assets/${assetId}`)
            await fetchLayerAssets()
          } catch (error) {
            console.error('Failed to delete layer asset:', error)
            useCanvasStore.getState().showToast('Fehler beim Löschen', 'error')
          }
        },

        renameLayerAsset: async (assetId, name) => {
          const { fetchLayerAssets } = get()
          try {
            await api.patch(`/documents/layer-assets/${assetId}`, { name })
            await fetchLayerAssets()
          } catch (error) {
            console.error('Failed to rename layer asset:', error)
            useCanvasStore.getState().showToast('Fehler beim Umbenennen', 'error')
          }
        },

        updateLayerAssetCategory: async (assetId, category) => {
          const { fetchLayerAssets } = get()
          try {
            await api.patch(`/documents/layer-assets/${assetId}`, { category })
            await fetchLayerAssets()
          } catch (error) {
            console.error('Failed to update layer asset category:', error)
            useCanvasStore.getState().showToast('Fehler beim Aktualisieren der Kategorie', 'error')
          }
        },

        // Helpers
        getSelectedLayer: () => {
          const { currentProject, selectedLayerId } = get()
          if (!currentProject || !selectedLayerId) return null
          return currentProject.layers.find((l) => l.id === selectedLayerId) || null
        },

        getLayerById: (layerId) => {
          const { currentProject } = get()
          if (!currentProject) return null
          return currentProject.layers.find((l) => l.id === layerId) || null
        },
      }),
      {
        name: 'canwa-layerStore',
        partialize: (state) => ({
          viewMode: state.viewMode,
          // Store only the current project ID, not the full project data
          currentProjectId: state.currentProject?.id || null,
          // Note: thumbnailUrl intentionally excluded - too large for localStorage, loaded from server instead
          projects: state.projects.map(p => ({ id: p.id, name: p.name, updatedAt: p.updatedAt, width: p.width, height: p.height })),
          selectedLayerId: state.selectedLayerId,
          recentColors: state.recentColors,
        }),
        onRehydrateStorage: () => (state) => {
          // After rehydration, restore the current project from backend if there was one open
          if (state) {
            const persistedState = state as unknown as { currentProjectId?: string }
            if (persistedState.currentProjectId && state.viewMode === 'editor') {
              // Restore the project from backend, fallback to projects view on failure
              state.openProject(persistedState.currentProjectId).catch(() => {
                state.closeProject()
              })
            }
            // Always load projects from backend to get fresh data + thumbnails
            state.loadProjectsFromBackend()
            // Fetch text styles and layer assets from backend
            state.fetchTextStyleFavorites()
            state.fetchLayerAssets()
          }
        },
        storage: {
          getItem: (name) => {
            try {
              const str = localStorage.getItem(name)
              return str ? JSON.parse(str) : null
            } catch {
              return null
            }
          },
          setItem: (name, value) => {
            try {
              localStorage.setItem(name, JSON.stringify(value))
            } catch {
              // Quota exceeded - clear storage and try again
              console.warn('localStorage quota exceeded, clearing canwa-layerStore')
              localStorage.removeItem(name)
              try {
                localStorage.setItem(name, JSON.stringify(value))
              } catch {
                console.error('Failed to save to localStorage even after clearing')
              }
            }
          },
          removeItem: (name) => localStorage.removeItem(name),
        },
      }
    )
  )
)

// Auto-save subscription: save to backend on every change (debounced 1s)
let autoSaveTimer: ReturnType<typeof setTimeout> | null = null

useLayerStore.subscribe(
  (state) => ({ dirty: state.isDirty, updatedAt: state.currentProject?.updatedAt }),
  ({ dirty }) => {
    if (!dirty) return

    if (autoSaveTimer) {
      clearTimeout(autoSaveTimer)
    }

    autoSaveTimer = setTimeout(() => {
      const state = useLayerStore.getState()
      if (state.currentProject && state.isDirty) {
        state.saveProjectToBackend()
        useLayerStore.setState({ isDirty: false })
      }
    }, 1000)
  },
  { equalityFn: (a, b) => a.dirty === b.dirty && a.updatedAt === b.updatedAt }
)
