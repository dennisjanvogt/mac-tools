import {
  Trash2, Copy, RotateCw, FlipHorizontal, FlipVertical,
  Sparkles, Eraser, Scissors,
  Bold, AlignLeft, AlignCenter, AlignRight,
} from 'lucide-react'
import { PersistentSection } from '../sidebar/PersistentSection'
import { useLayerStore, useCanwaAIStore } from '@/stores/canwa'
import type { BlendMode } from '@/apps/imageeditor/types'

const BLEND_MODES: BlendMode[] = [
  'normal', 'multiply', 'screen', 'overlay', 'darken', 'lighten',
  'color-dodge', 'color-burn', 'hard-light', 'soft-light', 'difference', 'exclusion',
]

export function PropertiesPanel() {
  const selectedLayerId = useLayerStore(s => s.selectedLayerId)
  const currentProject = useLayerStore(s => s.currentProject)
  const layer = currentProject?.layers.find(l => l.id === selectedLayerId)

  if (!layer) {
    return (
      <div className="px-3 py-6 text-center text-xs text-gray-400">
        Select a layer to edit properties
      </div>
    )
  }

  return (
    <div className="flex flex-col">
      {/* Layer name */}
      <div className="px-3 py-2 mb-1">
        <div className="text-xs text-gray-700 dark:text-gray-300 truncate font-medium">
          {layer.name}
        </div>
      </div>

      {/* Type-specific controls */}
      {layer.type === 'image' && <ImageProperties layerId={layer.id} />}
      {layer.type === 'text' && <TextProperties layerId={layer.id} />}

      {/* Transform */}
      <Section id="prop-transform" title="Transform" defaultOpen>
        <PositionInputs layerId={layer.id} />
      </Section>

      {/* Appearance */}
      <Section id="prop-appearance" title="Appearance" defaultOpen>
        <OpacityControl layerId={layer.id} />
        <BlendModeSelect layerId={layer.id} />
      </Section>

      {/* Actions */}
      <Section id="prop-actions" title="Actions" defaultOpen>
        <div className="grid grid-cols-4 gap-1">
          <ActionButton icon={Copy} label="Duplicate" onClick={() => useLayerStore.getState().duplicateLayer(layer.id)} />
          <ActionButton icon={RotateCw} label="Rotate" onClick={() => useLayerStore.getState().rotateLayer(layer.id, 90)} />
          <ActionButton icon={FlipHorizontal} label="Flip H" onClick={() => useLayerStore.getState().flipLayerHorizontal(layer.id)} />
          <ActionButton icon={FlipVertical} label="Flip V" onClick={() => useLayerStore.getState().flipLayerVertical(layer.id)} />
          <ActionButton icon={Scissors} label="Trim" onClick={() => useLayerStore.getState().trimLayer(layer.id)} />
          <ActionButton icon={Trash2} label="Delete" onClick={() => useLayerStore.getState().deleteLayer(layer.id)} className="text-red-500 hover:bg-red-50 dark:hover:bg-red-500/10" />
        </div>
      </Section>

      {/* AI tools for images */}
      {layer.type === 'image' && (
        <Section id="prop-ai" title="AI Tools">
          <div className="grid grid-cols-2 gap-1">
            <ActionButton icon={Eraser} label="Remove BG" onClick={() => useCanwaAIStore.getState().removeBackground(layer.id)} />
            <ActionButton icon={Sparkles} label="Enhance" onClick={() => useCanwaAIStore.getState().autoEnhance(layer.id)} />
          </div>
        </Section>
      )}
    </div>
  )
}

// ---------- Collapsible Section ----------
function Section({ id, title, defaultOpen = false, children }: { id: string; title: string; defaultOpen?: boolean; children: React.ReactNode }) {
  return (
    <PersistentSection id={id} title={title} defaultOpen={defaultOpen}>
      {children}
    </PersistentSection>
  )
}

// ---------- Image Properties ----------
function ImageProperties({ layerId }: { layerId: string }) {
  const layer = useLayerStore(s => s.currentProject?.layers.find(l => l.id === layerId))
  if (!layer) return null

  return (
    <Section id="prop-image" title="Image" defaultOpen>
      <div className="flex items-center gap-2">
        <span className="text-[10px] text-gray-700 dark:text-gray-400 w-10">Size</span>
        <span className="text-[11px] text-gray-900 dark:text-gray-400">
          {Math.round(layer.width)} × {Math.round(layer.height)}
        </span>
      </div>
    </Section>
  )
}

// ---------- Text Properties ----------
function TextProperties({ layerId }: { layerId: string }) {
  const layer = useLayerStore(s => s.currentProject?.layers.find(l => l.id === layerId))
  if (!layer) return null

  return (
    <Section id="prop-text" title="Text" defaultOpen>
      <div className="space-y-1.5">
        <label className="text-[10px] text-gray-700 dark:text-gray-400">Font</label>
        <select
          value={layer.fontFamily || 'Arial'}
          onChange={e => useLayerStore.getState().updateLayerTextProperties(layerId, { fontFamily: e.target.value })}
          className="w-full text-xs bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 px-2 py-1.5 text-gray-900 dark:text-gray-300 focus:outline-none focus:border-violet-500"
        >
          {['Arial', 'Helvetica', 'Georgia', 'Times New Roman', 'Courier New', 'Impact', 'Comic Sans MS', 'Verdana', 'Trebuchet MS'].map(f => (
            <option key={f} value={f}>{f}</option>
          ))}
        </select>
      </div>

      <div className="flex items-center gap-2">
        <div className="flex-1 space-y-1">
          <label className="text-[10px] text-gray-700 dark:text-gray-400">Size</label>
          <input
            type="number"
            value={layer.fontSize || 48}
            onChange={e => useLayerStore.getState().updateLayerTextProperties(layerId, { fontSize: Number(e.target.value) })}
            className="w-full text-xs bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 px-2 py-1.5 text-gray-900 dark:text-gray-300 focus:outline-none focus:border-violet-500"
            min={8} max={500}
          />
        </div>
        <div className="pt-4">
          <button
            onClick={() => useLayerStore.getState().updateLayerTextProperties(layerId, { fontWeight: (layer.fontWeight || 400) >= 700 ? 400 : 700 })}
            className={`p-1.5 transition-colors ${(layer.fontWeight || 400) >= 700 ? 'bg-violet-100 dark:bg-violet-500/20 text-violet-600 dark:text-violet-400' : 'text-gray-700 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'}`}
            title="Bold"
          >
            <Bold className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      <div className="space-y-1">
        <label className="text-[10px] text-gray-700 dark:text-gray-400">Align</label>
        <div className="flex gap-1">
          {([
            { align: 'left' as const, icon: AlignLeft },
            { align: 'center' as const, icon: AlignCenter },
            { align: 'right' as const, icon: AlignRight },
          ] as const).map(({ align, icon: Icon }) => (
            <button
              key={align}
              onClick={() => useLayerStore.getState().updateLayerTextProperties(layerId, { textAlign: align })}
              className={`p-1.5 transition-colors ${(layer.textAlign || 'center') === align ? 'bg-violet-100 dark:bg-violet-500/20 text-violet-600 dark:text-violet-400' : 'text-gray-700 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700'}`}
            >
              <Icon className="w-3.5 h-3.5" />
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-1">
        <label className="text-[10px] text-gray-700 dark:text-gray-400">Color</label>
        <div className="flex items-center gap-2">
          <input
            type="color"
            value={layer.fontColor || '#ffffff'}
            onChange={e => useLayerStore.getState().updateLayerTextProperties(layerId, { fontColor: e.target.value })}
            className="w-7 h-7 cursor-pointer border border-gray-300 dark:border-gray-700"
          />
          <span className="text-[11px] text-gray-700 dark:text-gray-400 font-mono">{layer.fontColor || '#ffffff'}</span>
        </div>
      </div>
    </Section>
  )
}

// ---------- Position / Size Inputs ----------
function PositionInputs({ layerId }: { layerId: string }) {
  const layer = useLayerStore(s => s.currentProject?.layers.find(l => l.id === layerId))
  if (!layer) return null
  const store = useLayerStore.getState

  return (
    <div className="grid grid-cols-2 gap-2">
      <div className="space-y-0.5">
        <label className="text-[10px] text-gray-700 dark:text-gray-400">X</label>
        <input type="number" value={Math.round(layer.x)}
          onChange={e => store().setLayerPosition(layerId, Number(e.target.value), layer.y)}
          className="w-full text-[11px] bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 px-1.5 py-1 text-gray-900 dark:text-gray-300 focus:outline-none focus:border-violet-500" />
      </div>
      <div className="space-y-0.5">
        <label className="text-[10px] text-gray-700 dark:text-gray-400">Y</label>
        <input type="number" value={Math.round(layer.y)}
          onChange={e => store().setLayerPosition(layerId, layer.x, Number(e.target.value))}
          className="w-full text-[11px] bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 px-1.5 py-1 text-gray-900 dark:text-gray-300 focus:outline-none focus:border-violet-500" />
      </div>
      <div className="space-y-0.5">
        <label className="text-[10px] text-gray-700 dark:text-gray-400">W</label>
        <input type="number" value={Math.round(layer.width)}
          onChange={e => store().resizeLayer(layerId, Number(e.target.value), layer.height)}
          className="w-full text-[11px] bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 px-1.5 py-1 text-gray-900 dark:text-gray-300 focus:outline-none focus:border-violet-500" />
      </div>
      <div className="space-y-0.5">
        <label className="text-[10px] text-gray-700 dark:text-gray-400">H</label>
        <input type="number" value={Math.round(layer.height)}
          onChange={e => store().resizeLayer(layerId, layer.width, Number(e.target.value))}
          className="w-full text-[11px] bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 px-1.5 py-1 text-gray-900 dark:text-gray-300 focus:outline-none focus:border-violet-500" />
      </div>
    </div>
  )
}

// ---------- Opacity ----------
function OpacityControl({ layerId }: { layerId: string }) {
  const layer = useLayerStore(s => s.currentProject?.layers.find(l => l.id === layerId))
  if (!layer) return null

  return (
    <div className="space-y-1">
      <div className="flex items-center justify-between">
        <label className="text-[10px] text-gray-700 dark:text-gray-400">Opacity</label>
        <span className="text-[10px] text-gray-600 dark:text-gray-400 tabular-nums">{layer.opacity}%</span>
      </div>
      <input type="range" min={0} max={100} value={layer.opacity}
        onChange={e => useLayerStore.getState().setLayerOpacity(layerId, Number(e.target.value))}
        className="w-full h-1 accent-violet-500" />
    </div>
  )
}

// ---------- Blend Mode ----------
function BlendModeSelect({ layerId }: { layerId: string }) {
  const layer = useLayerStore(s => s.currentProject?.layers.find(l => l.id === layerId))
  if (!layer) return null

  return (
    <div className="space-y-1">
      <label className="text-[10px] text-gray-700 dark:text-gray-400">Blend Mode</label>
      <select
        value={layer.blendMode}
        onChange={e => useLayerStore.getState().setLayerBlendMode(layerId, e.target.value as BlendMode)}
        className="w-full text-[11px] bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 px-1.5 py-1 text-gray-900 dark:text-gray-300 focus:outline-none focus:border-violet-500"
      >
        {BLEND_MODES.map(m => <option key={m} value={m}>{m}</option>)}
      </select>
    </div>
  )
}

// ---------- Action Button ----------
function ActionButton({ icon: Icon, label, onClick, className = '' }: {
  icon: React.ComponentType<{ className?: string }>; label: string; onClick: () => void; className?: string
}) {
  return (
    <button onClick={onClick} title={label}
      className={`flex flex-col items-center justify-center gap-0.5 py-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors text-gray-800 dark:text-gray-300 ${className}`}
    >
      <Icon className="w-3.5 h-3.5" />
      <span className="text-[9px] leading-tight">{label}</span>
    </button>
  )
}
