/* eslint-disable react-hooks/preserve-manual-memoization */
import { memo, useState, useRef, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Plus, Eye, EyeOff, Lock, Unlock, Trash2, Copy,
  ChevronUp, ChevronDown, Image as ImageIcon, Type,
  GripVertical, Merge, Layers, RotateCw, FlipHorizontal,
  FlipVertical, Scissors, Download, MoreHorizontal,
  Eraser, Sparkles,
} from 'lucide-react'
import { useShallow } from 'zustand/react/shallow'
import { useLayerStore, useCanwaAIStore } from '@/stores/canwa'
import type { BlendMode } from '@/apps/imageeditor/types'
import { DEFAULT_TEXT_EFFECTS } from '@/apps/imageeditor/types'
import type { Layer } from '@/apps/imageeditor/types'

// ---------- Blend Mode List ----------
const BLEND_MODES: { value: BlendMode; label: string }[] = [
  { value: 'normal', label: 'Normal' },
  { value: 'multiply', label: 'Multiply' },
  { value: 'screen', label: 'Screen' },
  { value: 'overlay', label: 'Overlay' },
  { value: 'darken', label: 'Darken' },
  { value: 'lighten', label: 'Lighten' },
  { value: 'color-dodge', label: 'Color Dodge' },
  { value: 'color-burn', label: 'Color Burn' },
  { value: 'hard-light', label: 'Hard Light' },
  { value: 'soft-light', label: 'Soft Light' },
  { value: 'difference', label: 'Difference' },
  { value: 'exclusion', label: 'Exclusion' },
]

// ---------- Export Single Layer Helper ----------
function exportSingleLayer(layer: Layer) {
  const canvas = document.createElement('canvas')
  canvas.width = layer.width
  canvas.height = layer.height
  const ctx = canvas.getContext('2d')
  if (!ctx) return

  if (layer.type === 'text' && layer.text) {
    const effects = layer.textEffects || DEFAULT_TEXT_EFFECTS
    const fontSize = layer.fontSize || 48
    const fontFamily = layer.fontFamily || 'Arial'
    const fontWeight = layer.fontWeight || 400
    const textAlign = layer.textAlign || 'left'
    const fontColor = layer.fontColor || '#ffffff'

    ctx.font = `${fontWeight} ${fontSize}px ${fontFamily}`
    ctx.textAlign = textAlign
    ctx.textBaseline = 'top'

    let textX = 0
    if (textAlign === 'center') textX = layer.width / 2
    else if (textAlign === 'right') textX = layer.width

    if (effects.glow.enabled) {
      ctx.save()
      ctx.shadowColor = effects.glow.color
      ctx.shadowBlur = effects.glow.intensity
      ctx.fillStyle = effects.glow.color
      for (let i = 0; i < 3; i++) ctx.fillText(layer.text, textX, fontSize / 2)
      ctx.restore()
    }

    if (effects.shadow.enabled) {
      ctx.save()
      ctx.shadowColor = effects.shadow.color
      ctx.shadowBlur = effects.shadow.blur
      ctx.shadowOffsetX = effects.shadow.offsetX
      ctx.shadowOffsetY = effects.shadow.offsetY
      ctx.fillStyle = fontColor
      ctx.fillText(layer.text, textX, fontSize / 2)
      ctx.restore()
    }

    if (effects.outline.enabled) {
      ctx.save()
      ctx.strokeStyle = effects.outline.color
      ctx.lineWidth = effects.outline.width * 2
      ctx.lineJoin = 'round'
      ctx.strokeText(layer.text, textX, fontSize / 2)
      ctx.restore()
    }

    ctx.fillStyle = fontColor
    ctx.fillText(layer.text, textX, fontSize / 2)
  } else if (layer.imageData) {
    const img = new Image()
    img.onload = () => {
      ctx.drawImage(img, 0, 0, layer.width, layer.height)
      downloadCanvas(canvas, layer.name)
    }
    img.src = layer.imageData
    return
  }

  downloadCanvas(canvas, layer.name)
}

function downloadCanvas(canvas: HTMLCanvasElement, name: string) {
  canvas.toBlob((blob) => {
    if (!blob) return
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `${name}.png`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }, 'image/png')
}

// ---------- Component ----------
export const LayersPanel = memo(function LayersPanel() {
  const { i18n } = useTranslation()
  const isGerman = i18n.language === 'de'

  const {
    currentProject,
    selectedLayerId,
    selectLayer,
    addLayer,
    deleteLayer,
    duplicateLayer,
    toggleLayerVisibility,
    toggleLayerLock,
    setLayerOpacity,
    setLayerBlendMode,
    reorderLayer,
    rotateLayer,
    flipLayerHorizontal,
    flipLayerVertical,
    mergeLayerDown,
    flattenLayers,
    trimLayer,
    renameLayer,
  } = useLayerStore(useShallow(s => ({
    currentProject: s.currentProject,
    selectedLayerId: s.selectedLayerId,
    selectLayer: s.selectLayer,
    addLayer: s.addLayer,
    deleteLayer: s.deleteLayer,
    duplicateLayer: s.duplicateLayer,
    toggleLayerVisibility: s.toggleLayerVisibility,
    toggleLayerLock: s.toggleLayerLock,
    setLayerOpacity: s.setLayerOpacity,
    setLayerBlendMode: s.setLayerBlendMode,
    reorderLayer: s.reorderLayer,
    rotateLayer: s.rotateLayer,
    flipLayerHorizontal: s.flipLayerHorizontal,
    flipLayerVertical: s.flipLayerVertical,
    mergeLayerDown: s.mergeLayerDown,
    flattenLayers: s.flattenLayers,
    trimLayer: s.trimLayer,
    renameLayer: s.renameLayer,
  })))

  const [editingLayerId, setEditingLayerId] = useState<string | null>(null)
  const [editingName, setEditingName] = useState('')
  const [draggedLayerId, setDraggedLayerId] = useState<string | null>(null)
  const [dragOverIndex, setDragOverIndex] = useState<number | null>(null)
  const [showMoreActions, setShowMoreActions] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const layers = currentProject?.layers ?? [] // eslint-disable-line react-hooks/exhaustive-deps
  // Show top layer first (reversed)
  const reversedLayers = [...layers].reverse()

  // ---------- Rename ----------
  const startRename = useCallback((layerId: string, currentName: string) => {
    setEditingLayerId(layerId)
    setEditingName(currentName)
    setTimeout(() => inputRef.current?.select(), 50)
  }, [])

  const commitRename = useCallback(() => {
    if (editingLayerId && editingName.trim()) {
      renameLayer(editingLayerId, editingName.trim())
    }
    setEditingLayerId(null)
  }, [editingLayerId, editingName, renameLayer])

  // ---------- Drag Reorder ----------
  const handleDragStart = useCallback((e: React.DragEvent, layerId: string) => {
    setDraggedLayerId(layerId)
    e.dataTransfer.effectAllowed = 'move'
  }, [])

  const handleDragOver = useCallback((e: React.DragEvent, index: number) => {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'move'
    setDragOverIndex(index)
  }, [])

  const handleDrop = useCallback((e: React.DragEvent, targetIndex: number) => {
    e.preventDefault()
    if (draggedLayerId) {
      // targetIndex is in reversed order, convert to actual index
      const actualIndex = layers.length - 1 - targetIndex
      reorderLayer(draggedLayerId, actualIndex)
    }
    setDraggedLayerId(null)
    setDragOverIndex(null)
  }, [draggedLayerId, layers.length, reorderLayer])

  const handleDragEnd = useCallback(() => {
    setDraggedLayerId(null)
    setDragOverIndex(null)
  }, [])

  // ---------- Move Up/Down ----------
  const moveLayerUp = useCallback((layerId: string) => {
    const idx = layers.findIndex(l => l.id === layerId)
    if (idx < layers.length - 1) {
      reorderLayer(layerId, idx + 1)
    }
  }, [layers, reorderLayer])

  const moveLayerDown = useCallback((layerId: string) => {
    const idx = layers.findIndex(l => l.id === layerId)
    if (idx > 0) {
      reorderLayer(layerId, idx - 1)
    }
  }, [layers, reorderLayer])

  // ---------- Add new layer ----------
  const handleAddLayer = useCallback(() => {
    addLayer('image', 'New Layer')
  }, [addLayer])

  if (!currentProject) {
    return (
      <div className="p-4 text-center text-sm text-gray-400">
        {isGerman ? 'Kein Projekt geoeffnet' : 'No project open'}
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-2 border-b border-gray-200 dark:border-gray-700">
        <div className="flex items-center gap-1.5">
          <Layers className="w-4 h-4 text-gray-500 dark:text-gray-400" />
          <span className="text-xs font-semibold text-gray-600 dark:text-gray-300 uppercase tracking-wider">
            {isGerman ? 'Ebenen' : 'Layers'}
          </span>
          <span className="text-[10px] text-gray-400 ml-1">({layers.length})</span>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => flattenLayers()}
            title={isGerman ? 'Alle zusammenfugen' : 'Flatten all'}
            className="p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
          >
            <Merge className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={handleAddLayer}
            title={isGerman ? 'Ebene hinzufugen' : 'Add layer'}
            className="p-1 text-gray-400 hover:text-violet-500 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Layer list */}
      <div className="flex-1 overflow-y-auto">
        {reversedLayers.map((layer, rIdx) => {
          const isSelected = layer.id === selectedLayerId
          const isDragging = layer.id === draggedLayerId
          const isDragTarget = rIdx === dragOverIndex && draggedLayerId !== layer.id

          return (
            <div
              key={layer.id}
              onDragOver={e => handleDragOver(e, rIdx)}
              onDrop={e => handleDrop(e, rIdx)}
              onDragLeave={e => {
                // Only clear if actually leaving this element (not entering a child)
                if (!e.currentTarget.contains(e.relatedTarget as Node)) {
                  setDragOverIndex(null)
                }
              }}
            >
              {/* Layer row */}
              <div
                draggable
                onDragStart={e => handleDragStart(e, layer.id)}
                onDragEnd={handleDragEnd}
                onClick={() => selectLayer(layer.id)}
                className={`flex items-center gap-1 h-11 px-1 cursor-pointer transition-colors border-l-2 ${
                  isSelected
                    ? 'bg-violet-50 dark:bg-violet-500/10 border-l-violet-500'
                    : 'bg-white dark:bg-gray-900 border-l-transparent hover:bg-gray-50 dark:hover:bg-gray-800/50'
                } ${isDragging ? 'opacity-40' : ''} ${isDragTarget ? 'border-t-2 border-t-violet-500' : ''}`}
              >
                {/* Grip handle */}
                <div className="flex-shrink-0 cursor-grab active:cursor-grabbing text-gray-300 dark:text-gray-600 hover:text-gray-500">
                  <GripVertical className="w-3 h-3" />
                </div>

                {/* Thumbnail */}
                <div className="flex-shrink-0 w-8 h-8 border border-gray-200 dark:border-gray-700 flex items-center justify-center overflow-hidden checkerboard">
                  {layer.type === 'text' ? (
                    <Type className="w-4 h-4 text-gray-400" />
                  ) : layer.imageData ? (
                    <img
                      src={layer.imageData}
                      alt={layer.name}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <ImageIcon className="w-4 h-4 text-gray-400" />
                  )}
                </div>

                {/* Layer name */}
                <div className="flex-1 min-w-0 px-1">
                  {editingLayerId === layer.id ? (
                    <input
                      ref={inputRef}
                      value={editingName}
                      onChange={e => setEditingName(e.target.value)}
                      onBlur={commitRename}
                      onKeyDown={e => {
                        e.stopPropagation()
                        if (e.key === 'Enter') commitRename()
                        if (e.key === 'Escape') setEditingLayerId(null)
                      }}
                      className="w-full text-xs bg-white dark:bg-gray-800 border border-violet-400 px-1 py-0.5 text-gray-800 dark:text-gray-200 focus:outline-none"
                    />
                  ) : (
                    <div
                      className="text-xs text-gray-700 dark:text-gray-300 truncate"
                      onDoubleClick={() => startRename(layer.id, layer.name)}
                    >
                      {layer.name}
                    </div>
                  )}
                </div>

                {/* Visibility toggle */}
                <button
                  onClick={e => { e.stopPropagation(); toggleLayerVisibility(layer.id) }}
                  className="flex-shrink-0 p-0.5 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors"
                  title={layer.visible ? 'Hide' : 'Show'}
                >
                  {layer.visible ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5 text-gray-300 dark:text-gray-600" />}
                </button>

                {/* Lock toggle */}
                <button
                  onClick={e => { e.stopPropagation(); toggleLayerLock(layer.id) }}
                  className="flex-shrink-0 p-0.5 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors"
                  title={layer.locked ? 'Unlock' : 'Lock'}
                >
                  {layer.locked ? <Lock className="w-3.5 h-3.5 text-amber-500" /> : <Unlock className="w-3.5 h-3.5" />}
                </button>
              </div>

              {/* Expanded controls for selected layer */}
              {isSelected && (
                <div
                  className="bg-gray-50 dark:bg-gray-800/50 border-b border-gray-200 dark:border-gray-700 px-3 py-2 space-y-2"
                  onClick={e => e.stopPropagation()}
                  onMouseDown={e => e.stopPropagation()}
                >
                  {/* Opacity slider */}
                  <div className="flex items-center gap-2">
                    <label className="text-[10px] text-gray-500 dark:text-gray-400 w-12">
                      {isGerman ? 'Deckkr.' : 'Opacity'}
                    </label>
                    <input
                      type="range"
                      min={0}
                      max={100}
                      value={layer.opacity}
                      onChange={e => setLayerOpacity(layer.id, Number(e.target.value))}
                      className="flex-1 h-1 accent-violet-500"
                    />
                    <span className="text-[10px] text-gray-500 w-7 text-right">{layer.opacity}%</span>
                  </div>

                  {/* Blend mode */}
                  <div className="flex items-center gap-2">
                    <label className="text-[10px] text-gray-500 dark:text-gray-400 w-12">
                      {isGerman ? 'Modus' : 'Blend'}
                    </label>
                    <select
                      value={layer.blendMode}
                      onChange={e => setLayerBlendMode(layer.id, e.target.value as BlendMode)}
                      className="flex-1 text-[11px] bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 px-1.5 py-1 text-gray-700 dark:text-gray-300 focus:outline-none focus:border-violet-500"
                    >
                      {BLEND_MODES.map(bm => (
                        <option key={bm.value} value={bm.value}>{bm.label}</option>
                      ))}
                    </select>
                  </div>

                  {/* Action buttons — primary actions visible, rest in dropdown */}
                  <div className="flex items-center gap-1 pt-1" onClick={e => e.stopPropagation()}>
                    <button
                      onClick={() => duplicateLayer(layer.id)}
                      title={isGerman ? 'Duplizieren' : 'Duplicate'}
                      className="p-1.5 text-gray-500 dark:text-gray-400 hover:text-violet-500 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                    >
                      <Copy className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => moveLayerUp(layer.id)}
                      title={isGerman ? 'Nach oben' : 'Move up'}
                      className="p-1.5 text-gray-500 dark:text-gray-400 hover:text-violet-500 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                    >
                      <ChevronUp className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => moveLayerDown(layer.id)}
                      title={isGerman ? 'Nach unten' : 'Move down'}
                      className="p-1.5 text-gray-500 dark:text-gray-400 hover:text-violet-500 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                    >
                      <ChevronDown className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => deleteLayer(layer.id)}
                      title={isGerman ? 'Loeschen' : 'Delete'}
                      className="p-1.5 text-gray-500 dark:text-gray-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                    <div className="relative ml-auto">
                      <button
                        onClick={() => setShowMoreActions(showMoreActions === layer.id ? null : layer.id)}
                        title={isGerman ? 'Mehr Aktionen' : 'More actions'}
                        className={`p-1.5 transition-colors ${showMoreActions === layer.id ? 'bg-violet-100 dark:bg-violet-500/20 text-violet-600' : 'text-gray-500 dark:text-gray-400 hover:text-violet-500 hover:bg-gray-100 dark:hover:bg-gray-700'}`}
                      >
                        <MoreHorizontal className="w-3.5 h-3.5" />
                      </button>
                      {showMoreActions === layer.id && (
                        <div className="absolute right-0 top-full mt-1 bg-white dark:bg-gray-800 shadow-xl border border-gray-200 dark:border-gray-700 py-1 z-30 min-w-[140px]">
                          {[
                            { icon: RotateCw, label: isGerman ? 'Drehen 90°' : 'Rotate 90°', onClick: () => rotateLayer(layer.id, 90) },
                            { icon: FlipHorizontal, label: isGerman ? 'H spiegeln' : 'Flip H', onClick: () => flipLayerHorizontal(layer.id) },
                            { icon: FlipVertical, label: isGerman ? 'V spiegeln' : 'Flip V', onClick: () => flipLayerVertical(layer.id) },
                            { icon: Merge, label: isGerman ? 'Zusammenfügen' : 'Merge down', onClick: () => mergeLayerDown(layer.id) },
                            { icon: Scissors, label: isGerman ? 'Zuschneiden' : 'Trim', onClick: () => trimLayer(layer.id) },
                            { icon: Download, label: isGerman ? 'Exportieren' : 'Export layer', onClick: () => exportSingleLayer(layer) },
                            ...(layer.type === 'image' && layer.imageData ? [
                              { icon: Eraser, label: isGerman ? 'Hintergrund entf.' : 'Remove BG', onClick: () => useCanwaAIStore.getState().removeBackground(layer.id) },
                              { icon: Sparkles, label: isGerman ? 'Auto-Verbessern' : 'Auto Enhance', onClick: () => useCanwaAIStore.getState().autoEnhance(layer.id) },
                            ] : []),
                          ].map(({ icon: Icon, label, onClick }) => (
                            <button
                              key={label}
                              onClick={() => { onClick(); setShowMoreActions(null) }}
                              className="w-full flex items-center gap-2 px-3 py-1.5 text-xs text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
                            >
                              <Icon className="w-3.5 h-3.5" />
                              {label}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Bottom: Add layer button */}
      <div className="border-t border-gray-200 dark:border-gray-700 p-2">
        <button
          onClick={handleAddLayer}
          className="w-full flex items-center justify-center gap-1.5 py-2 text-xs font-medium text-gray-500 dark:text-gray-400 hover:text-violet-500 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
        >
          <Plus className="w-3.5 h-3.5" />
          {isGerman ? 'Ebene hinzufugen' : 'Add Layer'}
        </button>
      </div>
    </div>
  )
})
