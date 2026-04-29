import { useState, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { motion } from 'framer-motion'
import { X, Download, Image as ImageIcon, Monitor } from 'lucide-react'
import { useLayerStore, useCanvasStore } from '@/stores/canwa'
// Filter state is read from layer.filters directly (matching Canvas.tsx)
import { useIsMobile } from '@/hooks/useIsMobile'
import { useWallpaperStore } from '@/stores/wallpaperStore'
import type { ExportSettings, Filters, Layer, TextEffects } from '../types'
import { DEFAULT_TEXT_EFFECTS } from '../types'

// Build CSS filter string from Filters object (must match Canvas.tsx exactly)
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const _buildFilterString = (filters: Filters): string => {
  const parts: string[] = []
  if (filters.brightness !== 0) parts.push(`brightness(${1 + filters.brightness / 100})`)
  if (filters.contrast !== 0) parts.push(`contrast(${1 + filters.contrast / 100})`)
  if (filters.saturation !== 0) parts.push(`saturate(${1 + filters.saturation / 100})`)
  if (filters.hue !== 0) parts.push(`hue-rotate(${filters.hue}deg)`)
  if (filters.blur > 0) parts.push(`blur(${filters.blur}px)`)
  if (filters.grayscale) parts.push('grayscale(1)')
  if (filters.sepia) parts.push('sepia(1)')
  if (filters.invert) parts.push('invert(1)')
  return parts.length > 0 ? parts.join(' ') : 'none'
}

// Check if filters need pixel manipulation (not just CSS filters)
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const _hasPixelFilters = (f: Filters): boolean => {
  return f.pixelate > 0 || f.sharpen > 0 || f.noise > 0 ||
    (f.posterize > 0 && f.posterize < 32) || f.vignette > 0 || f.emboss || f.edgeDetect ||
    f.tintAmount > 0
}

// Convolution helper (matches Canvas.tsx)
const applyConvolution = (ctx: CanvasRenderingContext2D, w: number, h: number, kernel: number[], strength: number) => {
  const src = ctx.getImageData(0, 0, w, h)
  const dst = ctx.createImageData(w, h)
  const sd = src.data, dd = dst.data
  const kSize = Math.round(Math.sqrt(kernel.length))
  const half = (kSize - 1) / 2
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = (y * w + x) * 4
      if (sd[i + 3] === 0) { dd[i+3] = 0; continue }
      for (let c = 0; c < 3; c++) {
        let sum = 0
        for (let ky = 0; ky < kSize; ky++) {
          for (let kx = 0; kx < kSize; kx++) {
            const sy = Math.min(h - 1, Math.max(0, y + ky - half))
            const sx = Math.min(w - 1, Math.max(0, x + kx - half))
            sum += sd[(sy * w + sx) * 4 + c] * kernel[ky * kSize + kx]
          }
        }
        const orig = sd[i + c]
        dd[i + c] = Math.max(0, Math.min(255, Math.round(orig + (sum - orig) * strength)))
      }
      dd[i + 3] = sd[i + 3]
    }
  }
  ctx.putImageData(dst, 0, 0)
}

// Apply pixel-based filters to a canvas element (matches Canvas.tsx exactly)
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const _applyPixelFilters = (canvas: HTMLCanvasElement, f: Filters): void => {
  const ctx = canvas.getContext('2d')!
  const w = canvas.width
  const h = canvas.height

  // Pixelate (must happen before getImageData for other filters)
  if (f.pixelate > 0) {
    const size = Math.max(2, Math.round(f.pixelate))
    const smallW = Math.max(1, Math.ceil(w / size))
    const smallH = Math.max(1, Math.ceil(h / size))
    const tmp = document.createElement('canvas')
    tmp.width = smallW
    tmp.height = smallH
    const tmpCtx = tmp.getContext('2d')!
    tmpCtx.imageSmoothingEnabled = false
    tmpCtx.drawImage(canvas, 0, 0, smallW, smallH)
    ctx.imageSmoothingEnabled = false
    ctx.clearRect(0, 0, w, h)
    ctx.drawImage(tmp, 0, 0, w, h)
    ctx.imageSmoothingEnabled = true
  }

  const imageData = ctx.getImageData(0, 0, w, h)
  const d = imageData.data

  // Posterize
  if (f.posterize > 0 && f.posterize < 32) {
    const levels = Math.max(2, f.posterize)
    const step = 255 / (levels - 1)
    for (let i = 0; i < d.length; i += 4) {
      d[i] = Math.round(Math.round(d[i] / step) * step)
      d[i + 1] = Math.round(Math.round(d[i + 1] / step) * step)
      d[i + 2] = Math.round(Math.round(d[i + 2] / step) * step)
    }
  }

  // Noise
  if (f.noise > 0) {
    const amount = f.noise * 2.55
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] === 0) continue
      const n = (Math.random() - 0.5) * amount
      d[i] = Math.max(0, Math.min(255, d[i] + n))
      d[i + 1] = Math.max(0, Math.min(255, d[i + 1] + n))
      d[i + 2] = Math.max(0, Math.min(255, d[i + 2] + n))
    }
  }

  // Tint
  if (f.tintAmount > 0 && f.tintColor) {
    const hex = f.tintColor.replace('#', '')
    const tR = parseInt(hex.substring(0, 2), 16)
    const tG = parseInt(hex.substring(2, 4), 16)
    const tB = parseInt(hex.substring(4, 6), 16)
    const mix = f.tintAmount / 100
    const inv = 1 - mix
    for (let i = 0; i < d.length; i += 4) {
      if (d[i + 3] === 0) continue
      d[i] = Math.round(d[i] * inv + tR * mix)
      d[i + 1] = Math.round(d[i + 1] * inv + tG * mix)
      d[i + 2] = Math.round(d[i + 2] * inv + tB * mix)
    }
  }

  // Vignette
  if (f.vignette > 0) {
    const cx = w / 2, cy = h / 2
    const maxDist = Math.sqrt(cx * cx + cy * cy)
    const strength = f.vignette / 100
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const i = (y * w + x) * 4
        if (d[i + 3] === 0) continue
        const dist = Math.sqrt((x - cx) ** 2 + (y - cy) ** 2) / maxDist
        const factor = 1 - dist * dist * strength
        d[i] = Math.round(d[i] * factor)
        d[i + 1] = Math.round(d[i + 1] * factor)
        d[i + 2] = Math.round(d[i + 2] * factor)
      }
    }
  }

  ctx.putImageData(imageData, 0, 0)

  // Convolution-based filters (sharpen, emboss, edge detect)
  if (f.sharpen > 0) {
    applyConvolution(ctx, w, h, [0, -1, 0, -1, 5, -1, 0, -1, 0], f.sharpen / 100)
  }
  if (f.emboss) {
    applyConvolution(ctx, w, h, [-2, -1, 0, -1, 1, 1, 0, 1, 2], 1)
  }
  if (f.edgeDetect) {
    applyConvolution(ctx, w, h, [-1, -1, -1, -1, 8, -1, -1, -1, -1], 1)
  }
}

// Render curved text along an arc
const renderCurvedText = (
  ctx: CanvasRenderingContext2D,
  text: string,
  x: number,
  y: number,
  width: number,
  effects: TextEffects,
  fontColor: string,
  fontSize: number
) => {
  ctx.save()

  const curveAmount = effects.curve / 100
  const arcHeight = width * 0.3 * Math.abs(curveAmount)
  const isConvex = curveAmount > 0

  const chord = width * 0.8
  const radius = arcHeight > 0 ? (arcHeight / 2 + (chord * chord) / (8 * arcHeight)) : 1000000

  const centerY = isConvex ? y + radius : y - radius + fontSize
  const totalAngle = 2 * Math.asin(chord / (2 * radius))

  const textWidth = ctx.measureText(text).width
  const startAngle = isConvex ? Math.PI - totalAngle / 2 : totalAngle / 2
  const anglePerChar = (totalAngle * textWidth) / (text.length * chord)

  ctx.translate(x, centerY)

  for (let i = 0; i < text.length; i++) {
    const char = text[i]
    const charWidth = ctx.measureText(char).width
    const charAngle = startAngle + (i + 0.5) * anglePerChar * (isConvex ? 1 : -1)

    ctx.save()
    ctx.rotate(charAngle + (isConvex ? Math.PI / 2 : -Math.PI / 2))
    ctx.translate(0, -radius)

    if (effects.glow.enabled) {
      ctx.shadowColor = effects.glow.color
      ctx.shadowBlur = effects.glow.intensity
      ctx.fillStyle = effects.glow.color
      ctx.fillText(char, -charWidth / 2, 0)
    }

    if (effects.shadow.enabled) {
      ctx.shadowColor = effects.shadow.color
      ctx.shadowBlur = effects.shadow.blur
      ctx.shadowOffsetX = effects.shadow.offsetX
      ctx.shadowOffsetY = effects.shadow.offsetY
    } else {
      ctx.shadowColor = 'transparent'
      ctx.shadowBlur = 0
    }

    if (effects.outline.enabled) {
      ctx.strokeStyle = effects.outline.color
      ctx.lineWidth = effects.outline.width * 2
      ctx.lineJoin = 'round'
      ctx.strokeText(char, -charWidth / 2, 0)
    }

    ctx.fillStyle = fontColor
    ctx.fillText(char, -charWidth / 2, 0)

    ctx.restore()
  }

  ctx.restore()
}

// Render text layer with effects
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const _renderTextLayer = (ctx: CanvasRenderingContext2D, layer: Layer) => {
  if (layer.type !== 'text' || !layer.text) return

  const effects = layer.textEffects || DEFAULT_TEXT_EFFECTS
  const fontSize = layer.fontSize || 48
  const fontFamily = layer.fontFamily || 'Arial'
  const fontWeight = layer.fontWeight || 400
  const textAlign = layer.textAlign || 'left'
  const fontColor = layer.fontColor || '#ffffff'

  ctx.save()
  ctx.globalAlpha = layer.opacity / 100
  ctx.globalCompositeOperation = (layer.blendMode === 'normal' ? 'source-over' : layer.blendMode) as GlobalCompositeOperation

  // Apply transforms
  ctx.translate(layer.x + layer.width / 2, layer.y + layer.height / 2)
  ctx.rotate((layer.rotation * Math.PI) / 180)
  ctx.translate(-layer.width / 2, -layer.height / 2)

  // Set font
  ctx.font = `${fontWeight} ${fontSize}px ${fontFamily}`
  ctx.textAlign = textAlign
  ctx.textBaseline = 'top'

  // Calculate text position based on alignment
  let textX = 0
  if (textAlign === 'center') {
    textX = layer.width / 2
  } else if (textAlign === 'right') {
    textX = layer.width
  }

  // Handle curved text
  if (effects.curve !== 0) {
    renderCurvedText(ctx, layer.text, textX, fontSize / 2, layer.width, effects, fontColor, fontSize)
  } else {
    // Render glow effect
    if (effects.glow.enabled) {
      ctx.save()
      ctx.shadowColor = effects.glow.color
      ctx.shadowBlur = effects.glow.intensity
      ctx.shadowOffsetX = 0
      ctx.shadowOffsetY = 0
      ctx.fillStyle = effects.glow.color
      for (let i = 0; i < 3; i++) {
        ctx.fillText(layer.text, textX, fontSize / 2)
      }
      ctx.restore()
    }

    // Render shadow effect
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

    // Render outline effect
    if (effects.outline.enabled) {
      ctx.save()
      ctx.strokeStyle = effects.outline.color
      ctx.lineWidth = effects.outline.width * 2
      ctx.lineJoin = 'round'
      ctx.strokeText(layer.text, textX, fontSize / 2)
      ctx.restore()
    }

    // Render main text
    ctx.fillStyle = fontColor
    ctx.fillText(layer.text, textX, fontSize / 2)
  }

  ctx.restore()
}

const FORMATS = [
  { value: 'png', label: 'PNG', description: 'Verlustfrei, mit Transparenz' },
  { value: 'jpeg', label: 'JPEG', description: 'Komprimiert, ohne Transparenz' },
  { value: 'webp', label: 'WebP', description: 'Modern, beste Kompression' },
] as const

const SCALES = [
  { value: 0.5, label: '50%' },
  { value: 1, label: '100%' },
  { value: 2, label: '200%' },
] as const

export function ExportDialog() {
  const { t } = useTranslation()
  const { isMobile } = useIsMobile()
  const currentProject = useLayerStore(s => s.currentProject)
  // Filters are read from each layer directly (layer.filters), matching Canvas.tsx
  const showExportDialog = useCanvasStore(s => s.showExportDialog)
  const setShowExportDialog = useCanvasStore(s => s.setShowExportDialog)
  const onClose = useCallback(() => setShowExportDialog(false), [setShowExportDialog])
  const isOpen = showExportDialog

  const [settings, setSettings] = useState<ExportSettings>({
    format: 'png',
    quality: 90,
    scale: 1,
    backgroundColor: 'transparent',
  })

  const [isExporting, setIsExporting] = useState(false)
  const addCustomWallpaper = useWallpaperStore(s => s.addCustomWallpaper)
  const setCustomWallpaper = useWallpaperStore(s => s.setCustomWallpaper)

  const handleSetAsWallpaper = useCallback(async () => {
    if (!currentProject) return
    setIsExporting(true)
    try {
      const liveCanvas = document.querySelector<HTMLCanvasElement>('[data-canwa-canvas]')
      if (!liveCanvas) { setIsExporting(false); return }

      const canvasState = useCanvasStore.getState()
      const zoom = canvasState.zoom || 100
      const panX = canvasState.panX || 0
      const panY = canvasState.panY || 0
      const scale = zoom / 100
      const dpr = window.devicePixelRatio || 1

      const pw = currentProject.width
      const ph = currentProject.height
      const exportCanvas = document.createElement('canvas')
      exportCanvas.width = pw
      exportCanvas.height = ph
      const ctx = exportCanvas.getContext('2d')
      if (!ctx) { setIsExporting(false); return }

      const srcX = panX * dpr
      const srcY = panY * dpr
      const srcW = pw * scale * dpr
      const srcH = ph * scale * dpr

      ctx.drawImage(liveCanvas, srcX, srcY, srcW, srcH, 0, 0, pw, ph)

      const dataUrl = exportCanvas.toDataURL('image/jpeg', 0.85)
      const added = addCustomWallpaper(dataUrl)
      if (!added) {
        // Limit reached — overwrite the active custom wallpaper
        setCustomWallpaper(dataUrl)
      }
      setIsExporting(false)
      onClose()
    } catch (error) {
      console.error('Set as wallpaper failed:', error)
      setIsExporting(false)
    }
  }, [currentProject, addCustomWallpaper, setCustomWallpaper, onClose])

  const handleExport = useCallback(async () => {
    if (!currentProject) return

    setIsExporting(true)

    try {
      // Find the live canvas element from the DOM — this is exactly what the user sees
      const liveCanvas = document.querySelector<HTMLCanvasElement>('[data-canwa-canvas]')
      if (!liveCanvas) {
        console.error('Export: could not find live canvas element')
        setIsExporting(false)
        return
      }

      // Read the current pan/zoom from the canvas store to extract the project region
      const canvasState = useCanvasStore.getState()
      const zoom = canvasState.zoom || 100
      const panX = canvasState.panX || 0
      const panY = canvasState.panY || 0
      const scale = zoom / 100
      const dpr = window.devicePixelRatio || 1

      const pw = currentProject.width
      const ph = currentProject.height

      // Create export canvas at desired output size
      const exportCanvas = document.createElement('canvas')
      const outW = Math.round(pw * settings.scale)
      const outH = Math.round(ph * settings.scale)
      exportCanvas.width = outW
      exportCanvas.height = outH
      const ctx = exportCanvas.getContext('2d')
      if (!ctx) return

      // Extract the project region from the live canvas
      // The live canvas renders at: translate(panX, panY) then scale(zoom/100)
      // With DPR, the actual pixel coordinates are multiplied by dpr
      const srcX = panX * dpr
      const srcY = panY * dpr
      const srcW = pw * scale * dpr
      const srcH = ph * scale * dpr

      // For JPEG/opaque: fill background FIRST, then draw content on top
      const needsBg = settings.format === 'jpeg' || settings.backgroundColor !== 'transparent'
      if (needsBg) {
        const bgColor = settings.format === 'jpeg' && settings.backgroundColor === 'transparent'
          ? '#ffffff'
          : settings.backgroundColor
        ctx.fillStyle = bgColor
        ctx.fillRect(0, 0, outW, outH)
      }

      // Draw the live canvas content on top of background
      ctx.drawImage(
        liveCanvas,
        srcX, srcY, srcW, srcH,  // source region (project area on live canvas)
        0, 0, outW, outH          // destination (full export canvas)
      )

      // Export to blob
      const mimeType = `image/${settings.format}`
      const quality = settings.format === 'png' ? undefined : settings.quality / 100

      exportCanvas.toBlob(
        (blob) => {
          if (!blob) return
          const url = URL.createObjectURL(blob)
          const a = document.createElement('a')
          a.href = url
          a.download = `${currentProject.name}.${settings.format}`
          document.body.appendChild(a)
          a.click()
          document.body.removeChild(a)
          URL.revokeObjectURL(url)
          setIsExporting(false)
          onClose()
        },
        mimeType,
        quality
      )
    } catch (error) {
      console.error('Export failed:', error)
      setIsExporting(false)
    }
  }, [currentProject, settings, onClose])

  if (!isOpen || !currentProject) return null

  const outputWidth = Math.round(currentProject.width * settings.scale)
  const outputHeight = Math.round(currentProject.height * settings.scale)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.2, ease: 'easeOut' }}
        className="bg-[#1e1b28] w-full shadow-2xl shadow-black/50 max-h-[90vh] overflow-y-auto border border-gray-700/30 max-w-[min(28rem,calc(100vw-2rem))]"
      >
        {/* Header */}
        <div className={`flex items-center justify-between border-b border-accent-800/15 bg-gradient-to-r from-accent-900/15 to-transparent ${
          isMobile ? 'p-3' : 'p-4'
        }`}>
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-accent-600/20 flex items-center justify-center">
              <Download className={`text-accent-400 w-4 h-4`} />
            </div>
            <h2 className={`font-bold ${isMobile ? 'text-base' : 'text-lg'}`}>{t('imageeditor.exportImage')}</h2>
          </div>
          <button
            onClick={onClose}
            className={`hover:bg-gray-700/50 transition-colors ${isMobile ? 'p-2' : 'p-2'}`}
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className={`space-y-4 ${isMobile ? 'p-3' : 'p-4'}`}>
          {/* Preview */}
          <div className={`flex items-center gap-4 bg-[#13111a] border border-gray-700/30 ${isMobile ? 'p-3' : 'p-4'}`}>
            <div className="w-14 h-14 bg-gradient-to-br from-accent-600/20 to-accent-800/10 flex items-center justify-center border border-accent-700/20">
              <ImageIcon className="w-7 h-7 text-accent-400" />
            </div>
            <div>
              <p className="font-bold text-gray-100">{currentProject.name}</p>
              <p className="text-sm text-gray-400 mt-0.5">
                <span className="text-accent-300 font-medium">{outputWidth} × {outputHeight}</span> px
              </p>
            </div>
          </div>

          {/* Format */}
          <div>
            <label className="text-sm text-gray-400 block mb-2">{t('imageeditor.format')}</label>
            <div className={`grid gap-2 ${isMobile ? 'grid-cols-1' : 'grid-cols-3'}`}>
              {FORMATS.map((format) => (
                <button
                  key={format.value}
                  onClick={() => setSettings((s) => ({
                    ...s,
                    format: format.value,
                    // JPEG doesn't support transparency — switch to white bg
                    ...(format.value === 'jpeg' && s.backgroundColor === 'transparent' ? { backgroundColor: '#ffffff' } : {}),
                    // Switching back from JPEG — allow transparent again
                    ...(format.value !== 'jpeg' && s.backgroundColor === '#ffffff' ? { backgroundColor: 'transparent' } : {}),
                  }))}
                  className={` text-sm transition-colors text-left ${
                    isMobile ? 'p-3 flex items-center gap-3' : 'p-3'
                  } ${
                    settings.format === format.value
                      ? 'ring-1 ring-accent-500/30 bg-accent-600/15 text-accent-200 border border-accent-500/30 shadow-sm shadow-accent-500/5'
                      : 'bg-[#13111a] text-gray-300 hover:bg-gray-800 border border-gray-700/30 hover:border-gray-600/50'
                  }`}
                >
                  <span className="font-medium">{format.label}</span>
                  {isMobile && <span className="text-xs opacity-70">- {format.description}</span>}
                  {!isMobile && <span className="text-xs opacity-70 block">{format.description}</span>}
                </button>
              ))}
            </div>
          </div>

          {/* Quality (only for JPEG/WebP) */}
          {settings.format !== 'png' && (
            <div>
              <div className="flex justify-between text-sm mb-2">
                <span className="text-gray-400">{t('imageeditor.quality')}</span>
                <span>{settings.quality}%</span>
              </div>
              <div className={`${isMobile ? 'h-10' : 'h-6'} flex items-center`}>
                <input
                  type="range"
                  min="10"
                  max="100"
                  value={settings.quality}
                  onChange={(e) => setSettings((s) => ({ ...s, quality: Number(e.target.value) }))}
                  className="w-full slider-accent"
                  style={{ '--value-percent': `${((settings.quality - 10) / 90) * 100}%` } as React.CSSProperties}
                />
              </div>
            </div>
          )}

          {/* Scale */}
          <div>
            <label className="text-sm text-gray-400 block mb-2">{t('imageeditor.scale')}</label>
            <div className="flex gap-2">
              {SCALES.map((scale) => (
                <button
                  key={scale.value}
                  onClick={() => setSettings((s) => ({ ...s, scale: scale.value }))}
                  className={`flex-1 text-sm transition-colors ${
                    isMobile ? 'py-3 px-3' : 'py-2 px-3'
                  } ${
                    settings.scale === scale.value
                      ? 'bg-gradient-to-r from-accent-600 to-accent-500 text-white shadow-sm shadow-accent-500/15'
                      : 'bg-[#13111a] text-gray-300 hover:bg-gray-800 border border-gray-700/30'
                  }`}
                >
                  {scale.label}
                </button>
              ))}
            </div>
          </div>

          {/* Background (only for PNG/WebP) */}
          {settings.format !== 'jpeg' && (
            <div>
              <label className="text-sm text-gray-400 block mb-2">{t('imageeditor.background')}</label>
              <div className={`flex gap-2 ${isMobile ? 'flex-col' : ''}`}>
                <button
                  onClick={() => setSettings((s) => ({ ...s, backgroundColor: 'transparent' }))}
                  className={`flex-1 text-sm transition-colors flex items-center justify-center gap-2 ${
                    isMobile ? 'py-3 px-3' : 'py-2 px-3'
                  } ${
                    settings.backgroundColor === 'transparent'
                      ? 'bg-gradient-to-r from-accent-600 to-accent-500 text-white shadow-sm shadow-accent-500/15'
                      : 'bg-[#13111a] text-gray-300 hover:bg-gray-800 border border-gray-700/30'
                  }`}
                >
                  <span
                    className="w-4 h-4 border border-gray-500 shrink-0"
                    style={{
                      backgroundImage:
                        'linear-gradient(45deg, #666 25%, transparent 25%), linear-gradient(-45deg, #666 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #666 75%), linear-gradient(-45deg, transparent 75%, #666 75%)',
                      backgroundSize: '8px 8px',
                      backgroundPosition: '0 0, 0 4px, 4px -4px, -4px 0px',
                    }}
                  />
                  Transparent
                </button>
                <button
                  onClick={() => setSettings((s) => ({ ...s, backgroundColor: '#ffffff' }))}
                  className={`flex-1 text-sm transition-colors flex items-center justify-center gap-2 ${
                    isMobile ? 'py-3 px-3' : 'py-2 px-3'
                  } ${
                    settings.backgroundColor === '#ffffff'
                      ? 'bg-gradient-to-r from-accent-600 to-accent-500 text-white shadow-sm shadow-accent-500/15'
                      : 'bg-[#13111a] text-gray-300 hover:bg-gray-800 border border-gray-700/30'
                  }`}
                >
                  <span className="w-4 h-4 bg-white border border-gray-500 shrink-0" />
                  Weiß
                </button>
                <button
                  onClick={() => setSettings((s) => ({ ...s, backgroundColor: '#000000' }))}
                  className={`flex-1 text-sm transition-colors flex items-center justify-center gap-2 ${
                    isMobile ? 'py-3 px-3' : 'py-2 px-3'
                  } ${
                    settings.backgroundColor === '#000000'
                      ? 'bg-gradient-to-r from-accent-600 to-accent-500 text-white shadow-sm shadow-accent-500/15'
                      : 'bg-[#13111a] text-gray-300 hover:bg-gray-800 border border-gray-700/30'
                  }`}
                >
                  <span className="w-4 h-4 bg-black border border-gray-500 shrink-0" />
                  Schwarz
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className={`flex justify-end gap-3 border-t border-accent-800/15 ${
          isMobile ? 'p-3' : 'p-4'
        }`}>
          <button
            onClick={onClose}
            className={`text-gray-400 hover:text-white transition-colors ${
              isMobile ? 'px-4 py-3 text-base' : 'px-4 py-2.5 text-sm'
            }`}
          >
            {t('common.cancel')}
          </button>
          <button
            onClick={handleSetAsWallpaper}
            disabled={isExporting}
            className={`flex items-center gap-2 bg-white/10 hover:bg-white/20 disabled:opacity-50 text-white/80 hover:text-white font-medium transition-all duration-200 ${
              isMobile ? 'px-4 py-3 text-base' : 'px-4 py-2.5 text-sm'
            }`}
            title="Als Hintergrund setzen"
          >
            <Monitor className="w-4 h-4" />
            Hintergrund
          </button>
          <button
            onClick={handleExport}
            disabled={isExporting}
            className={`flex items-center gap-2 bg-gradient-to-r from-accent-600 to-accent-500 hover:from-accent-500 hover:to-accent-400 disabled:opacity-50 text-white font-medium transition-all duration-200 shadow-md shadow-accent-500/20 hover:shadow-lg hover:shadow-accent-500/30 ${
              isMobile ? 'px-5 py-3 text-base' : 'px-5 py-2.5 text-sm'
            }`}
          >
            {isExporting ? (
              <>
                <span className="w-4 h-4 border-2 border-white/30 border-t-white animate-spin" />
                Exportiere...
              </>
            ) : (
              <>
                <Download className="w-4 h-4" />
                {t('imageeditor.export')}
              </>
            )}
          </button>
        </div>
      </motion.div>
    </div>
  )
}
