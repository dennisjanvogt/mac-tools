import { useTranslation } from 'react-i18next'
import { RotateCcw } from 'lucide-react'
import { PersistentSection } from './PersistentSection'
import { useLayerStore } from '@/stores/canwa'
import { useHistoryStore } from '@/stores/canwa/historyStore'
import { DEFAULT_LAYER_EFFECTS } from '@/apps/imageeditor/types'
import type { LayerEffects, DropShadow, InnerShadow, OuterGlow, InnerGlow } from '@/apps/imageeditor/types'

// ---------------------------------------------------------------------------
// Reusable helpers
// ---------------------------------------------------------------------------

function Slider({
  label,
  value,
  min,
  max,
  unit = '',
  onChange,
}: {
  label: string
  value: number
  min: number
  max: number
  unit?: string
  onChange: (v: number) => void
}) {
  return (
    <div className="space-y-0.5">
      <div className="flex justify-between text-[11px]">
        <span className="text-gray-800 dark:text-gray-400">{label}</span>
        <span className="text-violet-400 tabular-nums font-semibold">{value}{unit}</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="w-full h-1.5 bg-gray-300 dark:bg-gray-700 appearance-none cursor-pointer accent-violet-500"
      />
    </div>
  )
}

function ColorRow({
  label,
  value,
  onChange,
}: {
  label: string
  value: string
  onChange: (v: string) => void
}) {
  return (
    <div className="flex items-center gap-2">
      <span className="text-[11px] text-gray-800 dark:text-gray-400 flex-shrink-0">{label}</span>
      <input
        type="color"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-7 h-7 border border-gray-400 dark:border-gray-600 cursor-pointer bg-transparent p-0"
      />
      <span className="text-[10px] text-gray-600 dark:text-gray-400 font-mono">{value}</span>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------
export function ShadowPanel() {
  const { t } = useTranslation()
  const selectedLayerId = useLayerStore((s) => s.selectedLayerId)
  const currentProject = useLayerStore((s) => s.currentProject)
  const layer = currentProject?.layers.find((l) => l.id === selectedLayerId)
  const effects = layer?.layerEffects || DEFAULT_LAYER_EFFECTS

  const update = (newEffects: LayerEffects) => {
    if (!selectedLayerId) return
    useHistoryStore.getState().pushHistory('Update Effects')
    useLayerStore.getState().updateLayerEffects(selectedLayerId, newEffects)
  }

  const updateDrop = (patch: Partial<DropShadow>) => {
    update({ ...effects, dropShadow: { ...effects.dropShadow, ...patch } })
  }

  const updateInner = (patch: Partial<InnerShadow>) => {
    update({ ...effects, innerShadow: { ...effects.innerShadow, ...patch } })
  }

  const updateOuterGlow = (patch: Partial<OuterGlow>) => {
    update({ ...effects, outerGlow: { ...effects.outerGlow, ...patch } })
  }

  const updateInnerGlow = (patch: Partial<InnerGlow>) => {
    update({ ...effects, innerGlow: { ...effects.innerGlow, ...patch } })
  }

  if (!layer) {
    return (
      <div className="px-4 py-6 text-center text-xs text-gray-400">
        {t('imageeditor.selectLayerForEffects', 'Select a layer to edit effects')}
      </div>
    )
  }

  return (
    <div className="flex flex-col overflow-y-auto h-full">
      {/* Drop Shadow */}
      <PersistentSection
        id="shadow-drop"
        title={t('imageeditor.dropShadow', 'Drop Shadow')}
        enabled={effects.dropShadow.enabled}
        onToggle={(v) => updateDrop({ enabled: v })}
        defaultOpen
      >
        <ColorRow label={t('imageeditor.color', 'Color')} value={effects.dropShadow.color} onChange={(v) => updateDrop({ color: v })} />
        <Slider label={t('imageeditor.opacity', 'Opacity')} value={effects.dropShadow.opacity} min={0} max={100} unit="%" onChange={(v) => updateDrop({ opacity: v })} />
        <Slider label={t('imageeditor.offsetX', 'Offset X')} value={effects.dropShadow.offsetX} min={-50} max={50} unit="px" onChange={(v) => updateDrop({ offsetX: v })} />
        <Slider label={t('imageeditor.offsetY', 'Offset Y')} value={effects.dropShadow.offsetY} min={-50} max={50} unit="px" onChange={(v) => updateDrop({ offsetY: v })} />
        <Slider label={t('imageeditor.blur', 'Blur')} value={effects.dropShadow.blur} min={0} max={100} unit="px" onChange={(v) => updateDrop({ blur: v })} />
        <Slider label={t('imageeditor.spread', 'Spread')} value={effects.dropShadow.spread} min={0} max={50} unit="px" onChange={(v) => updateDrop({ spread: v })} />
      </PersistentSection>

      {/* Inner Shadow */}
      <PersistentSection
        id="shadow-inner"
        title={t('imageeditor.innerShadow', 'Inner Shadow')}
        enabled={effects.innerShadow.enabled}
        onToggle={(v) => updateInner({ enabled: v })}
      >
        <ColorRow label={t('imageeditor.color', 'Color')} value={effects.innerShadow.color} onChange={(v) => updateInner({ color: v })} />
        <Slider label={t('imageeditor.opacity', 'Opacity')} value={effects.innerShadow.opacity} min={0} max={100} unit="%" onChange={(v) => updateInner({ opacity: v })} />
        <Slider label={t('imageeditor.offsetX', 'Offset X')} value={effects.innerShadow.offsetX} min={-50} max={50} unit="px" onChange={(v) => updateInner({ offsetX: v })} />
        <Slider label={t('imageeditor.offsetY', 'Offset Y')} value={effects.innerShadow.offsetY} min={-50} max={50} unit="px" onChange={(v) => updateInner({ offsetY: v })} />
        <Slider label={t('imageeditor.blur', 'Blur')} value={effects.innerShadow.blur} min={0} max={100} unit="px" onChange={(v) => updateInner({ blur: v })} />
      </PersistentSection>

      {/* Outer Glow */}
      <PersistentSection
        id="shadow-outerglow"
        title={t('imageeditor.outerGlow', 'Outer Glow')}
        enabled={effects.outerGlow.enabled}
        onToggle={(v) => updateOuterGlow({ enabled: v })}
      >
        <ColorRow label={t('imageeditor.color', 'Color')} value={effects.outerGlow.color} onChange={(v) => updateOuterGlow({ color: v })} />
        <Slider label={t('imageeditor.opacity', 'Opacity')} value={effects.outerGlow.opacity} min={0} max={100} unit="%" onChange={(v) => updateOuterGlow({ opacity: v })} />
        <Slider label={t('imageeditor.blur', 'Blur')} value={effects.outerGlow.blur} min={0} max={100} unit="px" onChange={(v) => updateOuterGlow({ blur: v })} />
        <Slider label={t('imageeditor.spread', 'Spread')} value={effects.outerGlow.spread} min={0} max={50} unit="px" onChange={(v) => updateOuterGlow({ spread: v })} />
      </PersistentSection>

      {/* Inner Glow */}
      <PersistentSection
        id="shadow-innerglow"
        title={t('imageeditor.innerGlow', 'Inner Glow')}
        enabled={effects.innerGlow.enabled}
        onToggle={(v) => updateInnerGlow({ enabled: v })}
      >
        <ColorRow label={t('imageeditor.color', 'Color')} value={effects.innerGlow.color} onChange={(v) => updateInnerGlow({ color: v })} />
        <Slider label={t('imageeditor.opacity', 'Opacity')} value={effects.innerGlow.opacity} min={0} max={100} unit="%" onChange={(v) => updateInnerGlow({ opacity: v })} />
        <Slider label={t('imageeditor.blur', 'Blur')} value={effects.innerGlow.blur} min={0} max={100} unit="px" onChange={(v) => updateInnerGlow({ blur: v })} />
      </PersistentSection>

      {/* Reset all */}
      <div className="px-4 py-3">
        <button
          onClick={() => update({ ...DEFAULT_LAYER_EFFECTS })}
          className="w-full flex items-center justify-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-900 dark:text-gray-200 transition-colors"
        >
          <RotateCcw className="w-3.5 h-3.5" />
          {t('imageeditor.resetAll', 'Reset All')}
        </button>
      </div>
    </div>
  )
}
