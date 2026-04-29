import type { ImageProject, Filters } from '@/apps/imageeditor/types'
import { DEFAULT_FILTERS, DEFAULT_LAYER_EFFECTS, DEFAULT_TEXT_EFFECTS } from '@/apps/imageeditor/types'

// In the Canwa WKWebView wrapper every cross-origin URL is proxied through
// the canwa:// scheme handler. Leaving the path relative means
// `<img src="/media/…">` resolves to `canwa://app/media/…`, which Swift
// forwards to the real backend with the shared Bearer token.
export const MEDIA_BASE_URL = ''

export const getMediaUrl = (path: string) => {
  if (!path) return ''
  if (path.startsWith('http') || path.startsWith('data:') || path.startsWith('canwa:')) return path
  if (path.startsWith('/')) return path
  return `/${path}`
}

// Build CSS filter string — matches Canvas.tsx buildFilterString()
function buildFilterString(filters: Filters): string {
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

// Generate thumbnail from project layers — mirrors Canvas.tsx rendering pipeline
export const generateThumbnail = async (project: ImageProject): Promise<string> => {
  try {
    const THUMB_WIDTH = 320
    const THUMB_HEIGHT = 180

    const canvas = document.createElement('canvas')
    canvas.width = THUMB_WIDTH
    canvas.height = THUMB_HEIGHT
    const ctx = canvas.getContext('2d')
    if (!ctx) return ''

    // Calculate scale to fit
    const scale = Math.min(THUMB_WIDTH / project.width, THUMB_HEIGHT / project.height)
    const offsetX = (THUMB_WIDTH - project.width * scale) / 2
    const offsetY = (THUMB_HEIGHT - project.height * scale) / 2

    // Fill background with checkerboard pattern for transparency
    const checkerSize = 8
    for (let y = 0; y < THUMB_HEIGHT; y += checkerSize) {
      for (let x = 0; x < THUMB_WIDTH; x += checkerSize) {
        const isEven = ((x / checkerSize) + (y / checkerSize)) % 2 === 0
        ctx.fillStyle = isEven ? '#3a3a3a' : '#2a2a2a'
        ctx.fillRect(x, y, checkerSize, checkerSize)
      }
    }

    // If project has a non-transparent background color, fill on top
    const bgColor = project.backgroundColor
    const isTransparent = !bgColor || bgColor === 'transparent' || bgColor === 'rgba(0,0,0,0)' || bgColor === ''
    if (!isTransparent) {
      ctx.fillStyle = bgColor
      ctx.fillRect(offsetX, offsetY, project.width * scale, project.height * scale)
    }

    // Draw each visible layer
    for (const layer of project.layers) {
      if (!layer.visible) continue

      // ── Text layers — matches Canvas.tsx drawTextLayer() ──
      if (layer.type === 'text' && layer.text) {
        ctx.save()
        ctx.globalAlpha = layer.opacity / 100
        if (layer.blendMode && layer.blendMode !== 'normal') {
          ctx.globalCompositeOperation = layer.blendMode as GlobalCompositeOperation
        }

        const fontSize = (layer.fontSize || 48) * scale
        const fontWeight = layer.fontWeight || 400
        const fontFamily = layer.fontFamily || 'Inter'       // Match Canvas.tsx default
        const textAlign = layer.textAlign || 'left'
        const fontColor = layer.fontColor || '#000000'        // Match Canvas.tsx default
        const effects = layer.textEffects || DEFAULT_TEXT_EFFECTS

        // Quote font family — matches Canvas.tsx: `"${fontFamily}"`
        ctx.font = `${fontWeight} ${fontSize}px "${fontFamily}"`
        ctx.textBaseline = 'top'

        // Translate to center, rotate, offset back (for rotation support)
        const centerX = offsetX + (layer.x + layer.width / 2) * scale
        const centerY = offsetY + (layer.y + layer.height / 2) * scale
        ctx.translate(centerX, centerY)
        ctx.rotate((layer.rotation * Math.PI) / 180)
        ctx.translate((-layer.width / 2) * scale, (-layer.height / 2) * scale)

        // Text X position based on alignment — matches Canvas.tsx
        let textX = 0
        if (textAlign === 'center') textX = (layer.width / 2) * scale
        else if (textAlign === 'right') textX = layer.width * scale
        ctx.textAlign = textAlign as CanvasTextAlign

        // Split text into lines — matches Canvas.tsx line splitting
        const lines = layer.text.split('\n')
        const lineHeight = fontSize * 1.3
        const textY = 0

        const drawLines = (xPos: number, yStart: number) => {
          lines.forEach((line, i) => {
            ctx.fillText(line, xPos, yStart + i * lineHeight)
          })
        }
        const strokeLines = (xPos: number, yStart: number) => {
          lines.forEach((line, i) => {
            ctx.strokeText(line, xPos, yStart + i * lineHeight)
          })
        }

        // Effects order matches Canvas.tsx: glow → outline → shadow → main text (conditional)

        // 1. Glow effect
        if (effects.glow.enabled) {
          ctx.save()
          ctx.shadowColor = effects.glow.color
          ctx.shadowBlur = effects.glow.intensity * scale
          ctx.shadowOffsetX = 0
          ctx.shadowOffsetY = 0
          ctx.fillStyle = fontColor                           // Match Canvas.tsx: uses fontColor
          drawLines(textX, textY)
          ctx.restore()
        }

        // 2. Outline effect
        if (effects.outline.enabled) {
          ctx.save()
          ctx.strokeStyle = effects.outline.color
          ctx.lineWidth = effects.outline.width * scale        // Match Canvas.tsx: no *2
          ctx.lineJoin = 'round'
          strokeLines(textX, textY)
          ctx.restore()
        }

        // 3. Shadow effect
        if (effects.shadow.enabled) {
          ctx.save()
          ctx.shadowColor = effects.shadow.color
          ctx.shadowBlur = effects.shadow.blur * scale
          ctx.shadowOffsetX = effects.shadow.offsetX * scale
          ctx.shadowOffsetY = effects.shadow.offsetY * scale
          ctx.fillStyle = fontColor
          drawLines(textX, textY)
          ctx.restore()
        }

        // 4. Main text — only when shadow is off (shadow pass already draws text)
        if (!effects.shadow.enabled) {
          ctx.fillStyle = fontColor
          drawLines(textX, textY)
        }

        ctx.restore()
      }
      // ── Image layers — with filters and layer effects ──
      else if (layer.imageData) {
        try {
          const img = await new Promise<HTMLImageElement>((resolve, reject) => {
            const image = new Image()
            image.onload = () => resolve(image)
            image.onerror = reject
            image.src = layer.imageData!
          })

          ctx.save()
          ctx.globalAlpha = layer.opacity / 100
          if (layer.blendMode && layer.blendMode !== 'normal') {
            ctx.globalCompositeOperation = layer.blendMode as GlobalCompositeOperation
          }

          // Apply layer effects — drop shadow
          const effects = layer.layerEffects || DEFAULT_LAYER_EFFECTS
          if (effects.dropShadow.enabled) {
            ctx.shadowColor = effects.dropShadow.color + Math.round(effects.dropShadow.opacity * 2.55).toString(16).padStart(2, '0')
            ctx.shadowBlur = effects.dropShadow.blur * scale
            ctx.shadowOffsetX = effects.dropShadow.offsetX * scale
            ctx.shadowOffsetY = effects.dropShadow.offsetY * scale
          }

          ctx.translate(
            offsetX + (layer.x + layer.width / 2) * scale,
            offsetY + (layer.y + layer.height / 2) * scale
          )
          ctx.rotate((layer.rotation * Math.PI) / 180)

          const dw = layer.width * scale
          const dh = layer.height * scale

          // Apply CSS filters if present
          const filters = layer.filters || DEFAULT_FILTERS
          const filterStr = buildFilterString(filters)
          if (filterStr !== 'none') {
            // Render to offscreen canvas with filter, then draw result
            const off = document.createElement('canvas')
            off.width = Math.round(dw)
            off.height = Math.round(dh)
            const offCtx = off.getContext('2d')
            if (offCtx) {
              offCtx.filter = filterStr
              offCtx.drawImage(img, 0, 0, off.width, off.height)
              ctx.drawImage(off, -dw / 2, -dh / 2, dw, dh)
            }
          } else {
            ctx.drawImage(img, -dw / 2, -dh / 2, dw, dh)
          }

          // Outer glow (second pass)
          if (effects.outerGlow.enabled) {
            ctx.save()
            ctx.globalAlpha = effects.outerGlow.opacity / 100
            ctx.shadowColor = effects.outerGlow.color
            ctx.shadowBlur = effects.outerGlow.blur * scale
            ctx.shadowOffsetX = 0
            ctx.shadowOffsetY = 0
            ctx.drawImage(img, -dw / 2, -dh / 2, dw, dh)
            ctx.restore()
          }

          ctx.restore()
        } catch {
          // Skip failed images
        }
      }
    }

    return canvas.toDataURL('image/jpeg', 0.7)
  } catch (error) {
    console.error('Failed to generate thumbnail:', error)
    return ''
  }
}
