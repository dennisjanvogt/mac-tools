import { useState, useRef } from 'react'
import { ZoomIn, ZoomOut, Maximize2, Eraser, Crop, Ruler, X, Trash2, Plus, AlignCenter } from 'lucide-react'
import { useCanvasStore, useLayerStore, useCanwaAIStore } from '@/stores/canwa'
import { useHistoryStore } from '@/stores/canwa/historyStore'

// ── Workspace Background Color Picker ──
function BgColorPicker() {
  const workspaceBg = useCanvasStore((s) => s.workspaceBg)
  const setWorkspaceBg = useCanvasStore((s) => s.setWorkspaceBg)
  const colorInputRef = useRef<HTMLInputElement>(null)

  const displayColor = workspaceBg || '#e5e7eb'

  return (
    <button
      onClick={() => colorInputRef.current?.click()}
      className="relative w-9 h-9 flex items-center justify-center bg-white/90 dark:bg-gray-900/90 backdrop-blur-sm border border-gray-200 dark:border-gray-700/50 shadow-lg text-gray-700 dark:text-gray-400 hover:text-violet-500 transition-colors"
      title="Workspace Background"
    >
      <div
        className="w-4 h-4 border border-gray-300 dark:border-gray-600"
        style={{ backgroundColor: displayColor }}
      />
      <input
        ref={colorInputRef}
        type="color"
        value={displayColor}
        onChange={(e) => setWorkspaceBg(e.target.value)}
        className="absolute inset-0 opacity-0 cursor-pointer"
      />
    </button>
  )
}

// ── Preset guidelines ──

interface GuidelinePreset {
  label: string
  description: string
  guides: { orientation: 'h' | 'v'; position: number }[]
}

function getPresets(pw: number, ph: number): GuidelinePreset[] {
  return [
    {
      label: 'Mittelpunkt',
      description: 'Horizontale + vertikale Mitte',
      guides: [
        { orientation: 'h', position: ph / 2 },
        { orientation: 'v', position: pw / 2 },
      ],
    },
    {
      label: 'Drittel',
      description: 'Drittel-Raster (Rule of Thirds)',
      guides: [
        { orientation: 'v', position: pw / 3 },
        { orientation: 'v', position: (pw * 2) / 3 },
        { orientation: 'h', position: ph / 3 },
        { orientation: 'h', position: (ph * 2) / 3 },
      ],
    },
    {
      label: 'Goldener Schnitt',
      description: '~61.8% / 38.2% Aufteilung',
      guides: [
        { orientation: 'v', position: pw * 0.382 },
        { orientation: 'v', position: pw * 0.618 },
        { orientation: 'h', position: ph * 0.382 },
        { orientation: 'h', position: ph * 0.618 },
      ],
    },
    {
      label: 'Ränder 5%',
      description: '5% Abstand von allen Rändern',
      guides: [
        { orientation: 'v', position: pw * 0.05 },
        { orientation: 'v', position: pw * 0.95 },
        { orientation: 'h', position: ph * 0.05 },
        { orientation: 'h', position: ph * 0.95 },
      ],
    },
    {
      label: 'Ränder 10%',
      description: '10% Abstand von allen Rändern',
      guides: [
        { orientation: 'v', position: pw * 0.1 },
        { orientation: 'v', position: pw * 0.9 },
        { orientation: 'h', position: ph * 0.1 },
        { orientation: 'h', position: ph * 0.9 },
      ],
    },
    {
      label: 'Viertel',
      description: '25% / 50% / 75% Raster',
      guides: [
        { orientation: 'v', position: pw * 0.25 },
        { orientation: 'v', position: pw * 0.5 },
        { orientation: 'v', position: pw * 0.75 },
        { orientation: 'h', position: ph * 0.25 },
        { orientation: 'h', position: ph * 0.5 },
        { orientation: 'h', position: ph * 0.75 },
      ],
    },
  ]
}

export function FloatingZoomBar() {
  const zoom = useCanvasStore(s => s.zoom)
  const setZoom = useCanvasStore(s => s.setZoom)
  const setPan = useCanvasStore(s => s.setPan)
  const triggerFitToView = useCanvasStore(s => s.triggerFitToView)
  const guidelines = useCanvasStore(s => s.guidelines)
  const addGuideline = useCanvasStore(s => s.addGuideline)
  const removeGuideline = useCanvasStore(s => s.removeGuideline)
  const clearGuidelines = useCanvasStore(s => s.clearGuidelines)

  const selectedLayerId = useLayerStore(s => s.selectedLayerId)
  const currentProject = useLayerStore(s => s.currentProject)
  const selectedLayer = currentProject?.layers.find(l => l.id === selectedLayerId)
  const hasImage = selectedLayer?.type === 'image' && !!selectedLayer.imageData

  const isRemovingBackground = useCanwaAIStore(s => s.isRemovingBackground)

  const [guidesOpen, setGuidesOpen] = useState(false)
  const [customOrientation, setCustomOrientation] = useState<'h' | 'v'>('h')
  const [customPosition, setCustomPosition] = useState('')

  const pw = currentProject?.width ?? 1920
  const ph = currentProject?.height ?? 1080

  const zoomTo = (newZoom: number) => {
    const clamped = Math.max(10, Math.min(400, newZoom))
    const canvas = document.querySelector('canvas')
    if (canvas) {
      const rect = canvas.getBoundingClientRect()
      const cx = rect.width / 2
      const cy = rect.height / 2
      const oldScale = zoom / 100
      const newScale = clamped / 100
      const { panX, panY } = useCanvasStore.getState()
      const newPanX = cx - (cx - panX) * (newScale / oldScale)
      const newPanY = cy - (cy - panY) * (newScale / oldScale)
      setZoom(clamped)
      setPan(newPanX, newPanY)
    } else {
      setZoom(clamped)
    }
  }

  const handleRemoveBg = () => {
    if (!selectedLayerId || !hasImage) return
    useCanwaAIStore.getState().removeBackground(selectedLayerId)
  }

  const handleCenterLayer = () => {
    if (!selectedLayerId || !selectedLayer) return
    useHistoryStore.getState().pushHistory('Center Layer')
    const cx = (pw - selectedLayer.width) / 2
    const cy = (ph - selectedLayer.height) / 2
    useLayerStore.getState().setLayerPosition(selectedLayerId, Math.round(cx), Math.round(cy))
  }

  const handleCrop = () => {
    if (!selectedLayerId) return
    useHistoryStore.getState().pushHistory('Trim Layer')
    useLayerStore.getState().trimLayer(selectedLayerId)
  }

  const handleAddCustom = () => {
    const pos = parseFloat(customPosition)
    if (isNaN(pos)) return
    addGuideline(customOrientation, pos)
    setCustomPosition('')
  }

  const handleApplyPreset = (preset: GuidelinePreset) => {
    for (const g of preset.guides) {
      addGuideline(g.orientation, Math.round(g.position))
    }
  }

  const btnClass = 'p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-400 hover:text-violet-500 transition-colors disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:text-gray-700 dark:disabled:hover:text-gray-400'

  return (
    <>
      <div className="absolute bottom-3 left-1/2 -translate-x-1/2 z-20 flex items-center gap-1.5">
        {/* Left floating button: Remove BG */}
        <button
          onClick={handleRemoveBg}
          disabled={!hasImage || isRemovingBackground}
          className={`${btnClass} bg-white/90 dark:bg-gray-900/90 backdrop-blur-sm border border-gray-200 dark:border-gray-700/50 shadow-lg`}
          title="Remove Background"
        >
          <Eraser className={`w-4 h-4 ${isRemovingBackground ? 'animate-pulse' : ''}`} />
        </button>

        {/* Center layer button */}
        <button
          onClick={handleCenterLayer}
          disabled={!selectedLayerId}
          className={`${btnClass} bg-white/90 dark:bg-gray-900/90 backdrop-blur-sm border border-gray-200 dark:border-gray-700/50 shadow-lg`}
          title="Ebene zentrieren"
        >
          <AlignCenter className="w-4 h-4" />
        </button>

        {/* Guidelines button — left of zoom */}
        <button
          onClick={() => setGuidesOpen(!guidesOpen)}
          className={`${btnClass} bg-white/90 dark:bg-gray-900/90 backdrop-blur-sm border border-gray-200 dark:border-gray-700/50 shadow-lg ${guidelines.length > 0 ? 'text-violet-500' : ''}`}
          title="Hilfslinien"
        >
          <Ruler className="w-4 h-4" />
        </button>

        {/* Center: Zoom bar */}
        <div className="flex items-center gap-1 px-2 py-1.5 bg-white/90 dark:bg-gray-900/90 backdrop-blur-sm border border-gray-200 dark:border-gray-700/50 shadow-lg">
          <button
            onClick={() => zoomTo(zoom - 10)}
            disabled={zoom <= 10}
            className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-400 disabled:opacity-30 disabled:cursor-not-allowed"
            title="Zoom out"
          >
            <ZoomOut className="w-3.5 h-3.5" />
          </button>
          <input
            type="range"
            min={10}
            max={400}
            value={zoom}
            onChange={e => zoomTo(Number(e.target.value))}
            className="w-24 h-1 accent-violet-500"
          />
          <button
            onClick={() => zoomTo(zoom + 10)}
            disabled={zoom >= 400}
            className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-400 disabled:opacity-30 disabled:cursor-not-allowed"
            title="Zoom in"
          >
            <ZoomIn className="w-3.5 h-3.5" />
          </button>
          <span className="text-[10px] text-gray-700 dark:text-gray-400 tabular-nums w-8 text-center">{Math.round(zoom)}%</span>
          <div className="w-px h-4 bg-gray-200 dark:bg-gray-700" />
          <button
            onClick={triggerFitToView}
            className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-400 hover:text-violet-500 transition-colors"
            title="Fit to view"
          >
            <Maximize2 className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Right floating buttons: BG Color + Crop/Trim */}
        <div className="flex items-center gap-1.5">
          <BgColorPicker />
          <button
            onClick={handleCrop}
            disabled={!selectedLayerId || !hasImage}
            className={`${btnClass} bg-white/90 dark:bg-gray-900/90 backdrop-blur-sm border border-gray-200 dark:border-gray-700/50 shadow-lg`}
            title="Crop / Trim"
          >
            <Crop className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Guidelines Modal */}
      {guidesOpen && (
        <div
          className="absolute bottom-14 left-1/2 -translate-x-1/2 z-30 w-80 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 shadow-2xl"
          onClick={e => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-center justify-between px-4 pt-3 pb-2">
            <h3 className="text-sm font-semibold">Hilfslinien</h3>
            <button onClick={() => setGuidesOpen(false)} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800">
              <X className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="px-4 pb-3 space-y-3 max-h-80 overflow-y-auto">
            {/* Presets */}
            <div>
              <p className="text-[10px] font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider mb-1.5">Vorlagen</p>
              <div className="grid grid-cols-2 gap-1.5">
                {getPresets(pw, ph).map(preset => (
                  <button
                    key={preset.label}
                    onClick={() => handleApplyPreset(preset)}
                    className="text-left px-2.5 py-2 border border-gray-100 dark:border-gray-700 hover:border-violet-300 dark:hover:border-violet-700 hover:bg-violet-50 dark:hover:bg-violet-900/20 transition-colors"
                  >
                    <span className="text-xs font-medium block">{preset.label}</span>
                    <span className="text-[10px] text-gray-500 dark:text-gray-400 block">{preset.description}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Custom guide */}
            <div>
              <p className="text-[10px] font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider mb-1.5">Eigene Linie</p>
              <div className="flex items-center gap-1.5">
                <select
                  value={customOrientation}
                  onChange={e => setCustomOrientation(e.target.value as 'h' | 'v')}
                  className="text-xs px-2 py-1.5 border border-gray-200 dark:border-gray-700 dark:bg-gray-800 outline-none"
                >
                  <option value="h">Horizontal</option>
                  <option value="v">Vertikal</option>
                </select>
                <input
                  type="number"
                  value={customPosition}
                  onChange={e => setCustomPosition(e.target.value)}
                  placeholder="px"
                  className="flex-1 text-xs px-2 py-1.5 border border-gray-200 dark:border-gray-700 dark:bg-gray-800 outline-none w-0"
                  onKeyDown={e => e.key === 'Enter' && handleAddCustom()}
                />
                <button
                  onClick={handleAddCustom}
                  className="p-1.5 bg-violet-500 text-white hover:bg-violet-600 transition-colors"
                >
                  <Plus className="w-3 h-3" />
                </button>
              </div>
            </div>

            {/* Active guidelines list */}
            {guidelines.length > 0 && (
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <p className="text-[10px] font-medium text-gray-600 dark:text-gray-400 uppercase tracking-wider">Aktiv ({guidelines.length})</p>
                  <button
                    onClick={clearGuidelines}
                    className="text-[10px] text-red-500 hover:text-red-600 flex items-center gap-0.5"
                  >
                    <Trash2 className="w-3 h-3" />
                    Alle löschen
                  </button>
                </div>
                <div className="space-y-1 max-h-32 overflow-y-auto">
                  {guidelines.map(g => (
                    <div key={g.id} className="flex items-center justify-between px-2 py-1 bg-gray-50 dark:bg-gray-800 text-xs">
                      <span className="flex items-center gap-1.5">
                        <span className={`inline-block w-4 h-0.5 ${g.orientation === 'h' ? 'bg-violet-500' : 'bg-violet-500 rotate-90'}`} />
                        <span className="text-gray-700 dark:text-gray-400">{g.orientation === 'h' ? 'H' : 'V'}</span>
                        <span className="tabular-nums">{Math.round(g.position)}px</span>
                      </span>
                      <button onClick={() => removeGuideline(g.id)} className="p-0.5 hover:bg-gray-200 dark:hover:bg-gray-700">
                        <X className="w-3 h-3 text-gray-600 dark:text-gray-400" />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  )
}
