import { memo, useState, useCallback, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Loader2,
  Film, ZoomIn, Pipette, ImagePlus, ScanSearch,
  Expand, Grid3X3, Droplets,
} from 'lucide-react'
import { useShallow } from 'zustand/react/shallow'
import { PersistentSection } from './PersistentSection'
import { useCanwaAIStore, useLayerStore, useCanvasStore } from '@/stores/canwa'
import { useHistoryStore } from '@/stores/canwa/historyStore'
import { generateId } from '@/apps/imageeditor/types'
import { PRESET_GRADIENTS, PRESET_PATTERNS, AI_FILTER_TYPES } from '@/stores/canwa/utils/constants'

// ---------------------------------------------------------------------------
// Reusable collapsible section
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------
function ActionButton({
  label,
  loading,
  disabled,
  onClick,
  variant = 'primary',
}: {
  label: string
  loading?: boolean
  disabled?: boolean
  onClick: () => void
  variant?: 'primary' | 'secondary'
}) {
  const base =
    variant === 'primary'
      ? 'bg-violet-600 hover:bg-violet-700 text-white disabled:bg-violet-600/50'
      : 'bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 disabled:opacity-50'
  return (
    <button
      onClick={onClick}
      disabled={disabled || loading}
      className={`w-full px-3 py-1.5 text-xs font-medium flex items-center justify-center gap-1.5 transition-colors ${base} disabled:cursor-not-allowed`}
    >
      {loading && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
      {label}
    </button>
  )
}

function PromptInput({
  value,
  onChange,
  placeholder,
}: {
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <textarea
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      rows={2}
      className="w-full px-2.5 py-1.5 text-xs border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-800 dark:text-gray-200 placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-violet-500 resize-none"
    />
  )
}

// ---------------------------------------------------------------------------
// Remove Color (Chroma Key) section
// ---------------------------------------------------------------------------
function RemoveColorSection() {
  const { t } = useTranslation()
  const selectedLayerId = useLayerStore((s) => s.selectedLayerId)
  const currentProject = useLayerStore((s) => s.currentProject)
  const selectedLayer = currentProject?.layers.find((l) => l.id === selectedLayerId)
  const hasImage = selectedLayer?.type === 'image' && !!selectedLayer.imageData

  const [targetColor, setTargetColor] = useState('#00ff00')
  const [tolerance, setTolerance] = useState(30)
  const [isProcessing, setIsProcessing] = useState(false)
  const pickedColor = useCanwaAIStore((s) => s.pickedColor)

  // Sync picked color from palette into target color
  useEffect(() => {
    if (pickedColor) setTargetColor(pickedColor)
  }, [pickedColor])

  const applyChromaKey = useCallback(async () => {
    if (!selectedLayerId || !selectedLayer?.imageData) return
    setIsProcessing(true)

    try {
      // Push history before modifying
      try {
        useHistoryStore.getState().pushHistory('Remove Color')
      } catch { /* ignore */ }

      // Parse target color
      const hex = targetColor.replace('#', '')
      const tR = parseInt(hex.substring(0, 2), 16)
      const tG = parseInt(hex.substring(2, 4), 16)
      const tB = parseInt(hex.substring(4, 6), 16)

      // Load image
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = () => reject(new Error('Failed to load image'))
        img.src = selectedLayer.imageData!
      })

      // Draw to canvas and process pixels
      const canvas = document.createElement('canvas')
      canvas.width = img.width
      canvas.height = img.height
      const ctx = canvas.getContext('2d')!
      ctx.drawImage(img, 0, 0)

      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
      const data = imageData.data
      const tolSq = tolerance * tolerance * 3 // tolerance in color-space distance squared

      for (let i = 0; i < data.length; i += 4) {
        const dR = data[i] - tR
        const dG = data[i + 1] - tG
        const dB = data[i + 2] - tB
        const distSq = dR * dR + dG * dG + dB * dB

        if (distSq <= tolSq) {
          // Fully transparent
          data[i + 3] = 0
        } else if (distSq <= tolSq * 4) {
          // Feathered edge — partial transparency
          const ratio = Math.sqrt(distSq / tolSq) - 1 // 0..1
          data[i + 3] = Math.round(data[i + 3] * Math.min(1, ratio))
        }
      }

      ctx.putImageData(imageData, 0, 0)
      const newDataUrl = canvas.toDataURL('image/png')

      // Update layer
      useLayerStore.getState().updateLayerImage(selectedLayerId, newDataUrl)
    } finally {
      setIsProcessing(false)
    }
  }, [selectedLayerId, selectedLayer?.imageData, targetColor, tolerance])

  return (
    <PersistentSection id="ai-removecolor" title={t('imageeditor.removeColor', 'Remove Color')} icon={Droplets}>
      <div className="space-y-2">
        {/* Color picker row */}
        <div className="flex items-center gap-2">
          <label className="text-[11px] text-gray-600 dark:text-gray-400 flex-shrink-0">
            {t('imageeditor.targetColor', 'Color')}
          </label>
          <input
            type="color"
            value={targetColor}
            onChange={(e) => setTargetColor(e.target.value)}
            className="w-8 h-8 border border-gray-300 dark:border-gray-600 cursor-pointer bg-transparent p-0"
          />
          <input
            type="text"
            value={targetColor}
            onChange={(e) => {
              const v = e.target.value
              if (/^#[0-9a-fA-F]{0,6}$/.test(v)) setTargetColor(v)
            }}
            className="flex-1 px-2 py-1 text-xs border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 font-mono focus:outline-none focus:ring-1 focus:ring-violet-500"
          />
        </div>

        {/* Tolerance slider */}
        <div className="space-y-1">
          <div className="flex items-center justify-between">
            <label className="text-[11px] text-gray-600 dark:text-gray-400">
              {t('imageeditor.tolerance', 'Tolerance')}
            </label>
            <span className="text-[10px] text-gray-500 font-mono">{tolerance}</span>
          </div>
          <input
            type="range"
            min={1}
            max={100}
            value={tolerance}
            onChange={(e) => setTolerance(Number(e.target.value))}
            className="w-full h-1.5 appearance-none bg-gray-200 dark:bg-gray-700 accent-violet-500"
          />
        </div>

        <ActionButton
          label={
            isProcessing
              ? t('imageeditor.removingColor', 'Removing...')
              : t('imageeditor.applyRemoveColor', 'Remove Color')
          }
          loading={isProcessing}
          disabled={!hasImage}
          onClick={applyChromaKey}
        />

        {!hasImage && selectedLayerId && (
          <p className="text-[10px] text-amber-500 dark:text-amber-400">
            {t('imageeditor.selectImageLayer', 'Select an image layer with content')}
          </p>
        )}
      </div>
    </PersistentSection>
  )
}

// ---------------------------------------------------------------------------
// SAM Active Section (after model loaded)
// ---------------------------------------------------------------------------
function SAMActiveSection({ handleExtractMask }: { handleExtractMask: () => void }) {
  const { t } = useTranslation()
  const {
    isSAMSegmenting, samPoints, samEmbeddingLayerId,
    clearSAMPoints, generateSAMEmbedding,
  } = useCanwaAIStore()
  const selectedLayerId = useLayerStore((s) => s.selectedLayerId)
  const currentProject = useLayerStore((s) => s.currentProject)
  const selectedLayer = currentProject?.layers.find((l) => l.id === selectedLayerId)
  const hasSelectedImageLayer = selectedLayer?.type === 'image' && !!selectedLayer.imageData

  const isEmbeddingActive = !!samEmbeddingLayerId

  return (
    <div className="space-y-2">
      {!isEmbeddingActive ? (
        <>
          <ActionButton
            label={t('imageeditor.startSelection', 'Start Selection')}
            disabled={!hasSelectedImageLayer}
            onClick={() => {
              if (selectedLayerId) generateSAMEmbedding(selectedLayerId)
            }}
          />
          <p className="text-[10px] text-gray-400 leading-relaxed">
            {t('imageeditor.samStartHint', 'Select an image layer, then click Start.')}
          </p>
        </>
      ) : (
        <>
          <div className="flex items-center gap-1.5">
            <span className="w-2 h-2 bg-green-500 flex-shrink-0 animate-pulse" />
            <span className="text-[11px] text-gray-600 dark:text-gray-300 font-medium">
              {t('imageeditor.samActive', 'Active — click canvas to select')}
            </span>
          </div>
          <p className="text-[10px] text-gray-400 leading-relaxed">
            Click = include &nbsp;·&nbsp; Ctrl+Click = exclude &nbsp;·&nbsp; Esc = clear
          </p>

          {isSAMSegmenting && (
            <div className="flex items-center gap-1.5 text-[11px] text-violet-500">
              <Loader2 className="w-3.5 h-3.5 animate-spin" />
              Segmenting...
            </div>
          )}

          {samPoints.length > 0 && (
            <div className="space-y-1.5">
              <p className="text-[10px] text-gray-500">
                {samPoints.filter(p => p.label === 1).length} include, {samPoints.filter(p => p.label === 0).length} exclude
              </p>
              <div className="flex gap-1.5">
                <ActionButton label="Clear" variant="secondary" onClick={clearSAMPoints} />
                <ActionButton label={t('imageeditor.extractLayer', 'Extract Layer')} onClick={handleExtractMask} />
              </div>
            </div>
          )}
        </>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------
export const AIPanel = memo(function AIPanel() {
  const { t } = useTranslation()

  // AI store
  const {
    isGeneratingImage,
    isEditingImage,
    isEditingAllLayers,
    isEditingLayerWithContext,
    isApplyingFilter,
    isUpscaling,
    isExtractingColors,
    isExtendingImage,
    extractedColors,
    isSAMLoading,
    isSAMReady,
    loadSAM,
    generateAIImage,
    editImageWithAI,
    editAllLayersWithAI,
    editLayerWithContext,
    upscaleImage,
    applyAIFilter,
    extractColorPalette,
    extendImageToFit,
    addBackgroundGradient,
    addBackgroundPattern,
    setPickedColor,
  } = useCanwaAIStore(useShallow(s => ({
    isGeneratingImage: s.isGeneratingImage,
    isEditingImage: s.isEditingImage,
    isEditingAllLayers: s.isEditingAllLayers,
    isEditingLayerWithContext: s.isEditingLayerWithContext,
    isApplyingFilter: s.isApplyingFilter,
    isUpscaling: s.isUpscaling,
    isExtractingColors: s.isExtractingColors,
    isExtendingImage: s.isExtendingImage,
    extractedColors: s.extractedColors,
    isSAMLoading: s.isSAMLoading,
    isSAMReady: s.isSAMReady,
    loadSAM: s.loadSAM,
    generateAIImage: s.generateAIImage,
    editImageWithAI: s.editImageWithAI,
    editAllLayersWithAI: s.editAllLayersWithAI,
    editLayerWithContext: s.editLayerWithContext,
    upscaleImage: s.upscaleImage,
    applyAIFilter: s.applyAIFilter,
    extractColorPalette: s.extractColorPalette,
    extendImageToFit: s.extendImageToFit,
    addBackgroundGradient: s.addBackgroundGradient,
    addBackgroundPattern: s.addBackgroundPattern,
    setPickedColor: s.setPickedColor,
  })))

  // Layer store
  const { selectedLayerId, currentProject } = useLayerStore(useShallow(s => ({
    selectedLayerId: s.selectedLayerId,
    currentProject: s.currentProject,
  })))
  const selectedLayer = currentProject?.layers.find((l) => l.id === selectedLayerId)
  const hasSelectedImageLayer = selectedLayer?.type === 'image' && !!selectedLayer.imageData

  // Local state
  const [aiPrompt, setAiPrompt] = useState('')
  const [aiMode, setAiMode] = useState<'generate' | 'editLayer' | 'editAll' | 'context'>('generate')
  const [upscaleScale, setUpscaleScale] = useState<2 | 4>(2)

  const isAnyAiLoading = isGeneratingImage || isEditingImage || isEditingAllLayers || isEditingLayerWithContext

  const aiModes = [
    { id: 'generate' as const, label: t('imageeditor.generate', 'Generate'), tooltip: t('imageeditor.generateTooltip', 'Create a new image from a text description') },
    { id: 'editLayer' as const, label: t('imageeditor.editLayer', 'Edit Layer'), tooltip: t('imageeditor.editLayerTooltip', 'Edit the selected layer with AI') },
    { id: 'editAll' as const, label: t('imageeditor.editAll', 'Edit All'), tooltip: t('imageeditor.editAllTooltip', 'Flatten all layers and edit the result with AI') },
    { id: 'context' as const, label: t('imageeditor.contextEditBtn', 'Context'), tooltip: t('imageeditor.contextTooltip', 'AI analyzes the full canvas to generate contextually') },
  ]

  const getPlaceholder = () => {
    switch (aiMode) {
      case 'generate': return t('imageeditor.describeImage', 'Describe the image you want to generate...')
      case 'editLayer': return t('imageeditor.describeEdit', 'Describe the edit for the selected layer...')
      case 'editAll': return t('imageeditor.describeEditAll', 'Describe the edit for all layers...')
      case 'context': return t('imageeditor.describeContextEdit', 'Describe what you want, the AI sees the full canvas...')
    }
  }

  const isDisabled = () => {
    if (!aiPrompt.trim() || isAnyAiLoading) return true
    if (aiMode === 'editLayer') return !selectedLayerId || !hasSelectedImageLayer
    if (aiMode === 'editAll') return !currentProject?.layers.length
    return false
  }

  const handleAiSubmit = async () => {
    const prompt = aiPrompt.trim()
    if (!prompt) return
    switch (aiMode) {
      case 'generate':
        await generateAIImage(prompt)
        break
      case 'editLayer':
        if (selectedLayerId) await editImageWithAI(selectedLayerId, prompt)
        break
      case 'editAll':
        await editAllLayersWithAI(prompt)
        break
      case 'context':
        await editLayerWithContext(prompt)
        break
    }
    setAiPrompt('')
  }

  const handleExtractMask = useCallback(async () => {
    const { selection } = useCanvasStore.getState()
    const { samEmbeddingLayerId: embId } = useCanwaAIStore.getState()
    if (!selection.mask || !embId) return

    const layer = currentProject?.layers.find(l => l.id === embId)
    if (!layer?.imageData) return

    try {
      const { applyMaskToImage } = await import('@/services/sam/utils')

      // Load image to get pixel data
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = () => reject(new Error('Failed to load image'))
        img.src = layer.imageData!
      })

      const canvas = document.createElement('canvas')
      canvas.width = img.width
      canvas.height = img.height
      const ctx = canvas.getContext('2d')!
      ctx.drawImage(img, 0, 0)
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)

      // Resize mask to match image dimensions if needed
      let mask = selection.mask
      if (mask.width !== img.width || mask.height !== img.height) {
        const mCanvas = document.createElement('canvas')
        mCanvas.width = mask.width
        mCanvas.height = mask.height
        const mCtx = mCanvas.getContext('2d')!
        mCtx.putImageData(mask, 0, 0)

        const rCanvas = document.createElement('canvas')
        rCanvas.width = img.width
        rCanvas.height = img.height
        const rCtx = rCanvas.getContext('2d')!
        rCtx.imageSmoothingEnabled = false // nearest neighbor for crisp mask edges
        rCtx.drawImage(mCanvas, 0, 0, img.width, img.height)
        mask = rCtx.getImageData(0, 0, img.width, img.height)
      }

      // Apply mask to extract selected pixels
      const masked = applyMaskToImage(imageData, mask)

      // Create output canvas and get data URL
      const outCanvas = document.createElement('canvas')
      outCanvas.width = masked.width
      outCanvas.height = masked.height
      const outCtx = outCanvas.getContext('2d')!
      outCtx.putImageData(masked, 0, 0)
      const dataUrl = outCanvas.toDataURL('image/png')

      // Add as a new layer
      useHistoryStore.getState().pushHistory('Extract SAM Selection')
      useLayerStore.getState().addLayer({
        id: generateId(),
        type: 'image',
        name: 'SAM Extract',
        imageData: dataUrl,
        x: layer.x,
        y: layer.y,
        width: layer.width,
        height: layer.height,
        visible: true,
        locked: false,
        opacity: 100,
        rotation: 0,
        blendMode: 'normal',
      })

      // Clear SAM state
      useCanwaAIStore.getState().clearSAMPoints()
    } catch (error) {
      console.error('Failed to extract SAM mask:', error)
    }
  }, [currentProject])

  // -------------------------------------------------------------------------
  // Render
  // -------------------------------------------------------------------------
  return (
    <div className="flex flex-col overflow-y-auto h-full">
      {/* 1. AI Image (combined) */}
      <PersistentSection id="ai-image" title={t('imageeditor.aiImage', 'AI Image')} icon={ImagePlus} defaultOpen>
        {/* Mode switcher */}
        <div className="grid grid-cols-4 gap-0.5 bg-gray-100 dark:bg-gray-800 p-0.5">
          {aiModes.map(({ id, label, tooltip }) => (
            <button
              key={id}
              onClick={() => setAiMode(id)}
              title={tooltip}
              className={`px-1 py-1.5 text-[10px] font-medium transition-colors truncate ${
                aiMode === id
                  ? 'bg-white dark:bg-gray-700 text-violet-600 dark:text-violet-400 shadow-sm'
                  : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        <PromptInput
          value={aiPrompt}
          onChange={setAiPrompt}
          placeholder={getPlaceholder()}
        />

        <ActionButton
          label={isAnyAiLoading ? t('imageeditor.processing', 'Processing...') : aiModes.find(m => m.id === aiMode)!.label}
          loading={isAnyAiLoading}
          disabled={isDisabled()}
          onClick={handleAiSubmit}
        />

        {aiMode === 'editLayer' && !hasSelectedImageLayer && selectedLayerId && (
          <p className="text-[10px] text-amber-500 dark:text-amber-400">
            {t('imageeditor.selectImageLayer', 'Select an image layer with content')}
          </p>
        )}
        {aiMode === 'context' && (
          <p className="text-[10px] text-gray-400 dark:text-gray-500">
            {t('imageeditor.contextHint', 'AI sees the full canvas. Select a layer for extra context.')}
          </p>
        )}
      </PersistentSection>

      {/* AI Upscale */}
      <PersistentSection id="ai-upscale" title={t('imageeditor.aiUpscale', 'AI Upscale')} icon={ZoomIn}>
        <div className="flex gap-2">
          <button
            onClick={() => setUpscaleScale(2)}
            className={`flex-1 px-2 py-1 text-xs font-medium transition-colors ${
              upscaleScale === 2
                ? 'bg-violet-600 text-white'
                : 'bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300'
            }`}
          >
            2x
          </button>
          <button
            onClick={() => setUpscaleScale(4)}
            className={`flex-1 px-2 py-1 text-xs font-medium transition-colors ${
              upscaleScale === 4
                ? 'bg-violet-600 text-white'
                : 'bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300'
            }`}
          >
            4x
          </button>
        </div>
        <ActionButton
          label={
            isUpscaling
              ? t('imageeditor.upscaling', 'Upscaling...')
              : t('imageeditor.upscale', `Upscale ${upscaleScale}x`)
          }
          loading={isUpscaling}
          disabled={!selectedLayerId || !hasSelectedImageLayer}
          onClick={() => {
            if (selectedLayerId) upscaleImage(selectedLayerId, upscaleScale)
          }}
        />
      </PersistentSection>

      {/* 8. AI Filters */}
      <PersistentSection id="ai-filters" title={t('imageeditor.aiFilters', 'AI Filters')} icon={Film}>
        <div className="grid grid-cols-2 gap-1.5">
          {AI_FILTER_TYPES.map((filterType) => (
            <button
              key={filterType}
              onClick={() => {
                if (selectedLayerId) applyAIFilter(selectedLayerId, filterType)
              }}
              disabled={isApplyingFilter || !selectedLayerId || !hasSelectedImageLayer}
              className="px-2 py-1.5 text-[11px] font-medium capitalize bg-gray-100 dark:bg-gray-700/60 text-gray-600 dark:text-gray-300 hover:bg-violet-100 dark:hover:bg-violet-900/30 hover:text-violet-700 dark:hover:text-violet-300 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {filterType}
            </button>
          ))}
        </div>
        {isApplyingFilter && (
          <div className="flex items-center gap-1.5 text-[10px] text-violet-500">
            <Loader2 className="w-3 h-3 animate-spin" />
            {t('imageeditor.applyingFilter', 'Applying filter...')}
          </div>
        )}
      </PersistentSection>

      {/* 9. Color Palette */}
      <PersistentSection id="ai-palette" title={t('imageeditor.colorPalette', 'Color Palette')} icon={Pipette}>
        <ActionButton
          label={
            isExtractingColors
              ? t('imageeditor.extracting', 'Extracting...')
              : t('imageeditor.extractColors', 'Extract Colors')
          }
          loading={isExtractingColors}
          disabled={!selectedLayerId || !hasSelectedImageLayer}
          onClick={() => {
            if (selectedLayerId) extractColorPalette(selectedLayerId)
          }}
        />
        {extractedColors.length > 0 && (
          <div className="space-y-1.5">
            <div className="flex gap-1.5 flex-wrap">
              {extractedColors.map((color, i) => (
                <button
                  key={i}
                  onClick={() => {
                    // Set as active picked color (shared across panels)
                    setPickedColor(color)
                    // Also apply as font color to selected text layer
                    if (selectedLayerId && selectedLayer?.type === 'text') {
                      useLayerStore.getState().updateLayerTextProperties(selectedLayerId, { fontColor: color })
                    }
                    // Copy to clipboard
                    navigator.clipboard.writeText(color)
                  }}
                  title={color}
                  className="w-7 h-7 border border-gray-300 dark:border-gray-600 hover:scale-110 transition-transform shadow-sm"
                  style={{ backgroundColor: color }}
                />
              ))}
            </div>
            <p className="text-[10px] text-gray-400">
              {t('imageeditor.clickToApply', 'Click to apply color')}
            </p>
          </div>
        )}
      </PersistentSection>

      {/* 10. Extend Image */}
      <PersistentSection id="ai-extend" title={t('imageeditor.extendImage', 'Extend Image')} icon={Expand}>
        <ActionButton
          label={
            isExtendingImage
              ? t('imageeditor.extending', 'Extending...')
              : t('imageeditor.aiExtend', 'AI Extend')
          }
          loading={isExtendingImage}
          disabled={!selectedLayerId || !hasSelectedImageLayer}
          onClick={() => {
            if (selectedLayerId) extendImageToFit(selectedLayerId, true)
          }}
        />
      </PersistentSection>

      {/* 11. SAM Segmentation */}
      <PersistentSection id="ai-sam" title={t('imageeditor.samSegmentation', 'Object Selection')} icon={ScanSearch}>
        {!isSAMReady ? (
          <>
            <ActionButton
              label={isSAMLoading ? 'Loading model...' : 'Load SAM (~30 MB)'}
              loading={isSAMLoading}
              onClick={loadSAM}
            />
            <p className="text-[10px] text-gray-400">
              {t('imageeditor.samDesc', 'AI-powered click-to-select. Works fully in-browser.')}
            </p>
          </>
        ) : (
          <SAMActiveSection handleExtractMask={handleExtractMask} />
        )}
      </PersistentSection>

      {/* 12. Remove Color (Chroma Key) */}
      <RemoveColorSection />

      {/* 13. Backgrounds */}
      <PersistentSection id="ai-backgrounds" title={t('imageeditor.backgrounds', 'Backgrounds')} icon={Grid3X3}>
        {/* Gradient presets */}
        <p className="text-[10px] font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
          {t('imageeditor.gradients', 'Gradients')}
        </p>
        <div className="grid grid-cols-4 gap-1.5">
          {PRESET_GRADIENTS.map((g) => (
            <button
              key={g.name}
              onClick={() => addBackgroundGradient(g)}
              title={g.name}
              className="w-full aspect-square border border-gray-300 dark:border-gray-600 hover:scale-105 transition-transform shadow-sm"
              style={{
                background:
                  g.type === 'linear'
                    ? `linear-gradient(${g.angle ?? 135}deg, ${g.startColor}, ${g.endColor})`
                    : `radial-gradient(circle, ${g.startColor}, ${g.endColor})`,
              }}
            />
          ))}
        </div>

        {/* Pattern presets */}
        <p className="text-[10px] font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider mt-2">
          {t('imageeditor.patterns', 'Patterns')}
        </p>
        <div className="grid grid-cols-3 gap-1.5">
          {PRESET_PATTERNS.map((p) => (
            <button
              key={p.name}
              onClick={() => addBackgroundPattern(p.type, p.colors)}
              className="px-2 py-1.5 text-[11px] font-medium bg-gray-100 dark:bg-gray-700/60 text-gray-600 dark:text-gray-300 hover:bg-violet-100 dark:hover:bg-violet-900/30 hover:text-violet-700 dark:hover:text-violet-300 transition-colors"
            >
              {p.name}
            </button>
          ))}
        </div>
      </PersistentSection>
    </div>
  )
})
