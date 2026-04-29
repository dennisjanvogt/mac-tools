import { useRef, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { RotateCcw, Layers, Globe } from 'lucide-react'
import { useFilterStore, useLayerStore } from '@/stores/canwa'
import { FILTER_PRESETS } from '@/stores/canwa/utils/constants'
import { DEFAULT_FILTERS } from '@/apps/imageeditor/types'
import type { Filters } from '@/apps/imageeditor/types'
import { PersistentSection } from './PersistentSection'

// ---------------------------------------------------------------------------
// Reusable slider
// ---------------------------------------------------------------------------
function FilterSlider({
  label,
  value,
  min,
  max,
  unit = '',
  onChange,
  onReset,
  onCommit,
}: {
  label: string
  value: number
  min: number
  max: number
  unit?: string
  onChange: (v: number) => void
  onReset: () => void
  onCommit?: () => void
}) {
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined)
  const debouncedOnChange = useCallback((v: number) => {
    clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => onChange(v), 50)
  }, [onChange])

  return (
    <div className="space-y-1">
      <div className="flex justify-between text-[11px]">
        <span
          className="text-gray-800 dark:text-gray-200 cursor-pointer hover:text-gray-600 dark:hover:text-gray-400"
          onDoubleClick={() => { onReset(); onCommit?.() }}
          title="Double-click to reset"
        >
          {label}
        </span>
        <span className="text-violet-400 tabular-nums font-semibold">
          {value}
          {unit}
        </span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        value={value}
        onChange={(e) => debouncedOnChange(Number(e.target.value))}
        onPointerUp={() => onCommit?.()}
        className="w-full h-1.5 bg-gray-300 dark:bg-gray-700 appearance-none cursor-pointer accent-violet-500"
      />
    </div>
  )
}

// ---------------------------------------------------------------------------
// Toggle button for boolean filters
// ---------------------------------------------------------------------------
function FilterToggle({
  label,
  active,
  onChange,
}: {
  label: string
  active: boolean
  onChange: (v: boolean) => void
}) {
  return (
    <button
      onClick={() => onChange(!active)}
      className={`px-2.5 py-1.5 text-[11px] font-medium transition-colors ${
        active
          ? 'bg-violet-600 text-white'
          : 'bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600'
      }`}
    >
      {label}
    </button>
  )
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------
export function AdjustPanel() {
  const { t } = useTranslation()

  const {
    filters,
    filterMode,
    setFilters,
    commitFilters,
    setFilterMode,
    resetFilters,
    loadLayerFilters,
  } = useFilterStore()

  const selectedLayerId = useLayerStore((s) => s.selectedLayerId)

  const handleModeChange = (mode: 'layer' | 'global') => {
    setFilterMode(mode)
    if (mode === 'layer' && selectedLayerId) {
      loadLayerFilters(selectedLayerId)
    }
  }

  const handlePreset = (preset: (typeof FILTER_PRESETS)[number]) => {
    const newFilters: Partial<Filters> = { ...DEFAULT_FILTERS, ...preset.filters }
    setFilters(newFilters)
    commitFilters()
  }

  const updateFilter = <K extends keyof Filters>(key: K, value: Filters[K]) => {
    setFilters({ [key]: value } as Partial<Filters>)
  }

  const resetSingle = <K extends keyof Filters>(key: K) => {
    setFilters({ [key]: DEFAULT_FILTERS[key] } as Partial<Filters>)
  }

  return (
    <div className="flex flex-col overflow-y-auto h-full">
      {/* Mode toggle */}
      <div className="px-4 pt-3 pb-2 mb-1 space-y-2">
        <div className="flex overflow-hidden">
          <button
            onClick={() => handleModeChange('layer')}
            className={`flex-1 flex items-center justify-center gap-1 px-2 py-1.5 text-[11px] font-medium transition-colors ${
              filterMode === 'layer'
                ? 'bg-violet-600 text-white'
                : 'bg-black/[0.03] dark:bg-black/40 text-gray-600 dark:text-gray-300'
            }`}
          >
            <Layers className="w-3 h-3" />
            {t('imageeditor.layer', 'Layer')}
          </button>
          <button
            onClick={() => handleModeChange('global')}
            className={`flex-1 flex items-center justify-center gap-1 px-2 py-1.5 text-[11px] font-medium transition-colors ${
              filterMode === 'global'
                ? 'bg-violet-600 text-white'
                : 'bg-black/[0.03] dark:bg-black/40 text-gray-600 dark:text-gray-300'
            }`}
          >
            <Globe className="w-3 h-3" />
            {t('imageeditor.global', 'Global')}
          </button>
        </div>
      </div>

      {/* Presets */}
      <PersistentSection id="adjust-presets" title={t('imageeditor.presets', 'Presets')} defaultOpen>
        <div className="flex gap-1.5 flex-wrap">
          {FILTER_PRESETS.map((preset) => (
            <button
              key={preset.name}
              onClick={() => handlePreset(preset)}
              className="px-2.5 py-1 text-[11px] font-medium bg-gray-100 dark:bg-gray-700/60 text-gray-900 dark:text-gray-300 hover:bg-violet-100 dark:hover:bg-violet-900/30 hover:text-violet-700 dark:hover:text-violet-300 transition-colors"
            >
              {preset.name}
            </button>
          ))}
        </div>
      </PersistentSection>

      {/* Light & Color */}
      <PersistentSection id="adjust-light" title={t('imageeditor.lightColor', 'Light & Color')} defaultOpen>
        <FilterSlider label={t('imageeditor.brightness', 'Brightness')} value={filters.brightness} min={-100} max={100} onChange={(v) => updateFilter('brightness', v)} onReset={() => resetSingle('brightness')} onCommit={commitFilters} />
        <FilterSlider label={t('imageeditor.contrast', 'Contrast')} value={filters.contrast} min={-100} max={100} onChange={(v) => updateFilter('contrast', v)} onReset={() => resetSingle('contrast')} onCommit={commitFilters} />
        <FilterSlider label={t('imageeditor.saturation', 'Saturation')} value={filters.saturation} min={-100} max={100} onChange={(v) => updateFilter('saturation', v)} onReset={() => resetSingle('saturation')} onCommit={commitFilters} />
        <FilterSlider label={t('imageeditor.hue', 'Hue')} value={filters.hue} min={-180} max={180} unit={'\u00B0'} onChange={(v) => updateFilter('hue', v)} onReset={() => resetSingle('hue')} onCommit={commitFilters} />
      </PersistentSection>

      {/* Detail */}
      <PersistentSection id="adjust-detail" title={t('imageeditor.detail', 'Detail')} defaultOpen>
        <FilterSlider label={t('imageeditor.blur', 'Blur')} value={filters.blur} min={0} max={20} unit="px" onChange={(v) => updateFilter('blur', v)} onReset={() => resetSingle('blur')} onCommit={commitFilters} />
        <FilterSlider label={t('imageeditor.sharpen', 'Sharpen')} value={filters.sharpen} min={0} max={100} onChange={(v) => updateFilter('sharpen', v)} onReset={() => resetSingle('sharpen')} onCommit={commitFilters} />
        <FilterSlider label={t('imageeditor.noise', 'Noise')} value={filters.noise} min={0} max={100} onChange={(v) => updateFilter('noise', v)} onReset={() => resetSingle('noise')} onCommit={commitFilters} />
      </PersistentSection>

      {/* Effects */}
      <PersistentSection id="adjust-effects" title={t('imageeditor.effects', 'Effects')}>
        <FilterSlider label={t('imageeditor.pixelate', 'Pixelate')} value={filters.pixelate} min={0} max={50} unit="px" onChange={(v) => updateFilter('pixelate', v)} onReset={() => resetSingle('pixelate')} onCommit={commitFilters} />
        <FilterSlider label={t('imageeditor.posterize', 'Posterize')} value={filters.posterize} min={2} max={32} onChange={(v) => updateFilter('posterize', v)} onReset={() => resetSingle('posterize')} onCommit={commitFilters} />
        <FilterSlider label={t('imageeditor.vignette', 'Vignette')} value={filters.vignette} min={0} max={100} onChange={(v) => updateFilter('vignette', v)} onReset={() => resetSingle('vignette')} onCommit={commitFilters} />
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <label className="text-[11px] text-gray-800 dark:text-gray-200 flex-1">{t('imageeditor.tintColor', 'Tint')}</label>
            <input
              type="color"
              value={filters.tintColor}
              onChange={(e) => { updateFilter('tintColor', e.target.value); commitFilters() }}
              className="w-6 h-6 cursor-pointer bg-transparent"
            />
          </div>
          <FilterSlider label={t('imageeditor.tintAmount', 'Amount')} value={filters.tintAmount} min={0} max={100} unit="%" onChange={(v) => updateFilter('tintAmount', v)} onReset={() => resetSingle('tintAmount')} onCommit={commitFilters} />
        </div>
      </PersistentSection>

      {/* Styles */}
      <PersistentSection id="adjust-styles" title={t('imageeditor.toggleFilters', 'Styles')}>
        <div className="flex gap-1.5 flex-wrap">
          <FilterToggle label={t('imageeditor.grayscale', 'Grayscale')} active={filters.grayscale} onChange={(v) => { updateFilter('grayscale', v); commitFilters() }} />
          <FilterToggle label={t('imageeditor.sepia', 'Sepia')} active={filters.sepia} onChange={(v) => { updateFilter('sepia', v); commitFilters() }} />
          <FilterToggle label={t('imageeditor.invert', 'Invert')} active={filters.invert} onChange={(v) => { updateFilter('invert', v); commitFilters() }} />
          <FilterToggle label={t('imageeditor.emboss', 'Emboss')} active={filters.emboss} onChange={(v) => { updateFilter('emboss', v); commitFilters() }} />
          <FilterToggle label={t('imageeditor.edgeDetect', 'Edge Detect')} active={filters.edgeDetect} onChange={(v) => { updateFilter('edgeDetect', v); commitFilters() }} />
        </div>
      </PersistentSection>

      {/* Reset */}
      <div className="px-4 py-3">
        <button
          onClick={() => { resetFilters(); commitFilters() }}
          className="w-full flex items-center justify-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-900 dark:text-gray-200 transition-colors"
        >
          <RotateCcw className="w-3.5 h-3.5" />
          {t('imageeditor.reset', 'Reset')}
        </button>
      </div>
    </div>
  )
}
