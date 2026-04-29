/* eslint-disable react-hooks/immutability */
import { useRef, useEffect, useCallback, useState, useMemo } from 'react'
import { useLayerStore, useCanvasStore, useCanwaAIStore } from '@/stores/canwa'
import { useHistoryStore } from '@/stores/canwa/historyStore'
import { DEFAULT_FILTERS, DEFAULT_TEXT_EFFECTS, DEFAULT_LAYER_EFFECTS } from '@/apps/imageeditor/types'
import type { Layer, Filters } from '@/apps/imageeditor/types'

// ── Constants ──

const HANDLE_SIZE = 8
const ROTATION_HANDLE_OFFSET = 24
const SNAP_THRESHOLD = 12
const CHECKERBOARD_SIZE = 24
const MIN_LAYER_SIZE = 10

type DragMode = 'none' | 'move' | 'resize' | 'pan' | 'rotate'
type ResizeHandle = 'nw' | 'n' | 'ne' | 'e' | 'se' | 's' | 'sw' | 'w' | null

interface SnapGuide {
  orientation: 'h' | 'v'
  position: number // in project coords
}

// ── Image Cache ──

const imageCache = new Map<string, HTMLImageElement>()
const MAX_CACHE_SIZE = 50
let _onImageLoaded: (() => void) | null = null

function getImage(src: string): HTMLImageElement | null {
  if (imageCache.has(src)) {
    const img = imageCache.get(src)!
    // Move to end (LRU)
    imageCache.delete(src)
    imageCache.set(src, img)
    return img.complete ? img : null
  }
  // Evict oldest if over limit
  if (imageCache.size >= MAX_CACHE_SIZE) {
    const oldest = imageCache.keys().next().value
    if (oldest) imageCache.delete(oldest)
  }
  const img = new Image()
  img.onload = () => { _onImageLoaded?.() }
  img.onerror = () => { imageCache.delete(src) }
  img.src = src
  imageCache.set(src, img)
  return img.complete ? img : null
}

// ── Filter String Builder (CSS filters) ──

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

// ── Pixel-based filters (not available as CSS filters) ──

function hasPixelFilters(f: Filters): boolean {
  return f.pixelate > 0 || f.sharpen > 0 || f.noise > 0 ||
    (f.posterize > 0 && f.posterize < 32) || f.vignette > 0 || f.emboss || f.edgeDetect ||
    f.tintAmount > 0
}

function applyPixelFilters(canvas: HTMLCanvasElement, f: Filters): void {
  const ctx = canvas.getContext('2d')!
  const w = canvas.width
  const h = canvas.height

  // Pixelate (must happen before getImageData for other filters)
  if (f.pixelate > 0) {
    const size = Math.max(2, Math.round(f.pixelate))
    // Scale down then back up with nearest-neighbor
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

  // Posterize (0 = off, 2-31 = active)
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

  // Convolution-based filters (sharpen, emboss, edge detect) — need fresh reads
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

function applyConvolution(
  ctx: CanvasRenderingContext2D, w: number, h: number,
  kernel: number[], strength: number
): void {
  const src = ctx.getImageData(0, 0, w, h)
  const dst = ctx.createImageData(w, h)
  const sd = src.data, dd = dst.data
  const kSize = 3, half = 1

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const idx = (y * w + x) * 4
      if (sd[idx + 3] === 0) { dd[idx + 3] = 0; continue }
      let r = 0, g = 0, b = 0
      for (let ky = 0; ky < kSize; ky++) {
        for (let kx = 0; kx < kSize; kx++) {
          const sy = Math.min(h - 1, Math.max(0, y + ky - half))
          const sx = Math.min(w - 1, Math.max(0, x + kx - half))
          const si = (sy * w + sx) * 4
          const kv = kernel[ky * kSize + kx]
          r += sd[si] * kv
          g += sd[si + 1] * kv
          b += sd[si + 2] * kv
        }
      }
      // Blend between original and filtered by strength
      dd[idx] = Math.max(0, Math.min(255, Math.round(sd[idx] * (1 - strength) + r * strength)))
      dd[idx + 1] = Math.max(0, Math.min(255, Math.round(sd[idx + 1] * (1 - strength) + g * strength)))
      dd[idx + 2] = Math.max(0, Math.min(255, Math.round(sd[idx + 2] * (1 - strength) + b * strength)))
      dd[idx + 3] = sd[idx + 3]
    }
  }
  ctx.putImageData(dst, 0, 0)
}

// ── Hit-Testing Helpers ──

function pointInRotatedRect(
  px: number, py: number,
  rx: number, ry: number, rw: number, rh: number,
  rotation: number
): boolean {
  // Transform point into layer's local space
  const cx = rx + rw / 2
  const cy = ry + rh / 2
  const rad = (-rotation * Math.PI) / 180
  const cos = Math.cos(rad)
  const sin = Math.sin(rad)
  const dx = px - cx
  const dy = py - cy
  const localX = dx * cos - dy * sin + rw / 2
  const localY = dx * sin + dy * cos + rh / 2
  return localX >= 0 && localX <= rw && localY >= 0 && localY <= rh
}

function getResizeHandleAtPoint(
  px: number, py: number,
  layer: Layer,
  handleSize: number
): ResizeHandle {
  const { x, y, width, height, rotation } = layer
  const cx = x + width / 2
  const cy = y + height / 2
  const rad = (-rotation * Math.PI) / 180
  const cos = Math.cos(rad)
  const sin = Math.sin(rad)
  const dx = px - cx
  const dy = py - cy
  const localX = dx * cos - dy * sin + width / 2
  const localY = dx * sin + dy * cos + height / 2

  const hs = handleSize
  const handles: { handle: ResizeHandle; hx: number; hy: number }[] = [
    { handle: 'nw', hx: 0, hy: 0 },
    { handle: 'n', hx: width / 2, hy: 0 },
    { handle: 'ne', hx: width, hy: 0 },
    { handle: 'e', hx: width, hy: height / 2 },
    { handle: 'se', hx: width, hy: height },
    { handle: 's', hx: width / 2, hy: height },
    { handle: 'sw', hx: 0, hy: height },
    { handle: 'w', hx: 0, hy: height / 2 },
  ]

  for (const { handle, hx, hy } of handles) {
    if (Math.abs(localX - hx) < hs && Math.abs(localY - hy) < hs) {
      return handle
    }
  }
  return null
}

function isNearRotationHandle(
  px: number, py: number,
  layer: Layer,
  handleSize: number
): boolean {
  const { x, y, width, rotation } = layer
  const cx = x + width / 2
  const cy = y
  // Rotation handle is above top-center
  const rad = (rotation * Math.PI) / 180
  // Adjust for rotation pivot
  const pivotX = layer.x + layer.width / 2
  const pivotY = layer.y + layer.height / 2
  const rdx = cx - pivotX
  const rdy = (cy - ROTATION_HANDLE_OFFSET) - pivotY
  const rotHandleX = pivotX + rdx * Math.cos(rad) - rdy * Math.sin(rad)
  const rotHandleY = pivotY + rdx * Math.sin(rad) + rdy * Math.cos(rad)

  return Math.abs(px - rotHandleX) < handleSize * 1.5 && Math.abs(py - rotHandleY) < handleSize * 1.5
}

// ── Component ──

export function Canvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const animFrameRef = useRef<number>(0)

  // Store state
  const currentProject = useLayerStore(s => s.currentProject)
  const selectedLayerId = useLayerStore(s => s.selectedLayerId)
  const selectLayer = useLayerStore(s => s.selectLayer)
  const setLayerPosition = useLayerStore(s => s.setLayerPosition)
  const setLayerTransform = useLayerStore(s => s.setLayerTransform)
  const updateLayerText = useLayerStore(s => s.updateLayerText)
  const addImageAsLayer = useLayerStore(s => s.addImageAsLayer)
  const setLayerRotation = useLayerStore(s => s.setLayerRotation)

  const workspaceBg = useCanvasStore(s => s.workspaceBg)
  const zoom = useCanvasStore(s => s.zoom)
  const panX = useCanvasStore(s => s.panX)
  const panY = useCanvasStore(s => s.panY)
  const setZoom = useCanvasStore(s => s.setZoom)
  const setPan = useCanvasStore(s => s.setPan)
  const fitToViewTrigger = useCanvasStore(s => s.fitToViewTrigger)
  const showGrid = useCanvasStore(s => s.showGrid)
  const gridSize = useCanvasStore(s => s.gridSize)
  const gridColor = useCanvasStore(s => s.gridColor)
  const snapEnabled = useCanvasStore(s => s.snapEnabled)
  const guidelines = useCanvasStore(s => s.guidelines)

  const pushHistory = useHistoryStore(s => s.pushHistory)

  // Local interaction state
  const [dragMode, setDragMode] = useState<DragMode>('none')
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 })
  const [dragLayerStart, setDragLayerStart] = useState({ x: 0, y: 0, w: 0, h: 0 })
  const [resizeHandle, setResizeHandle] = useState<ResizeHandle>(null)
  const [rotateStart, setRotateStart] = useState(0)
  const [rotateLayerStart, setRotateLayerStart] = useState(0)
  const snapGuidesRef = useRef<SnapGuide[]>([])
  const [hoveredLayerId, setHoveredLayerId] = useState<string | null>(null)
  const [editingTextLayerId, setEditingTextLayerId] = useState<string | null>(null)
  const [editingText, setEditingText] = useState('')
  const [isDragOver, setIsDragOver] = useState(false)
  const [spaceHeld, setSpaceHeld] = useState(false)
  const [shiftHeld, setShiftHeld] = useState(false)
  const [hasMoved, setHasMoved] = useState(false)

  // Multi-touch state
  const touchesRef = useRef<Map<number, { x: number; y: number }>>(new Map())
  const pinchStartDistRef = useRef(0)
  const pinchStartZoomRef = useRef(100)
  const pinchStartPanRef = useRef({ x: 0, y: 0 })

  // ── Fix 1: rAF-throttled mouse move refs ──

  // ── Refs that mirror store values for renderCanvas (synced synchronously) ──
  const zoomRef = useRef(zoom)
  const panXRef = useRef(panX)
  const panYRef = useRef(panY)
  const projectRef = useRef(currentProject)
  const selectedLayerIdRef = useRef(selectedLayerId)
  const hoveredLayerIdRef = useRef(hoveredLayerId)
  const showGridRef = useRef(showGrid)
  const gridSizeRef = useRef(gridSize)
  const gridColorRef = useRef(gridColor)
  const guidelinesRef = useRef(guidelines)
  const editingTextLayerIdRef = useRef(editingTextLayerId)

  // Sync refs synchronously during render (not in useEffect which is async)
  zoomRef.current = zoom
  panXRef.current = panX
  panYRef.current = panY
  projectRef.current = currentProject
  selectedLayerIdRef.current = selectedLayerId
  hoveredLayerIdRef.current = hoveredLayerId
  showGridRef.current = showGrid
  gridSizeRef.current = gridSize
  gridColorRef.current = gridColor
  guidelinesRef.current = guidelines
  editingTextLayerIdRef.current = editingTextLayerId

  // ── Coordinate Conversion ──

  const screenToProject = useCallback((sx: number, sy: number): { x: number; y: number } => {
    const container = containerRef.current
    if (!container) return { x: sx, y: sy }
    const rect = container.getBoundingClientRect()
    const scale = zoom / 100
    return {
      x: (sx - rect.left - panX) / scale,
      y: (sy - rect.top - panY) / scale,
    }
  }, [zoom, panX, panY])

  // ── Layer Hit Testing ──

  const getLayerAtPoint = useCallback((px: number, py: number): Layer | null => {
    if (!currentProject) return null
    // Iterate in reverse (top layer first)
    for (let i = currentProject.layers.length - 1; i >= 0; i--) {
      const layer = currentProject.layers[i]
      if (!layer.visible || layer.locked) continue
      if (pointInRotatedRect(px, py, layer.x, layer.y, layer.width, layer.height, layer.rotation)) {
        return layer
      }
    }
    return null
  }, [currentProject])

  // ── Snap Guide Calculation ──

  const calculateSnapGuides = useCallback((
    movingLayer: Layer,
    newX: number, newY: number,
    newW?: number, newH?: number
  ): { x: number; y: number; guides: SnapGuide[] } => {
    if (!currentProject || !snapEnabled) return { x: newX, y: newY, guides: [] }

    const w = newW ?? movingLayer.width
    const h = newH ?? movingLayer.height
    const guides: SnapGuide[] = []
    let snappedX = newX
    let snappedY = newY

    const movingEdges = {
      left: newX,
      right: newX + w,
      centerX: newX + w / 2,
      top: newY,
      bottom: newY + h,
      centerY: newY + h / 2,
    }

    // Canvas edges + center
    const targets: { x: number[]; y: number[] } = {
      x: [0, currentProject.width / 2, currentProject.width],
      y: [0, currentProject.height / 2, currentProject.height],
    }

    // Other layers' edges + centers
    for (const layer of currentProject.layers) {
      if (layer.id === movingLayer.id || !layer.visible) continue
      targets.x.push(layer.x, layer.x + layer.width / 2, layer.x + layer.width)
      targets.y.push(layer.y, layer.y + layer.height / 2, layer.y + layer.height)
    }

    // Custom user guidelines
    for (const g of guidelines) {
      if (g.orientation === 'v') targets.x.push(g.position)
      else targets.y.push(g.position)
    }

    // Snap X — find the closest target, snap to it, and only emit one guide
    let bestSnapX: { dist: number; offset: number; pos: number } | null = null
    for (const tx of targets.x) {
      for (const edge of [movingEdges.left, movingEdges.centerX, movingEdges.right]) {
        const dist = Math.abs(edge - tx)
        if (dist < SNAP_THRESHOLD && (!bestSnapX || dist < bestSnapX.dist)) {
          bestSnapX = { dist, offset: tx - edge, pos: tx }
        }
      }
    }
    if (bestSnapX) {
      snappedX = newX + bestSnapX.offset
      guides.push({ orientation: 'v', position: bestSnapX.pos })
    }

    // Snap Y — find the closest target, snap to it, and only emit one guide
    let bestSnapY: { dist: number; offset: number; pos: number } | null = null
    for (const ty of targets.y) {
      for (const edge of [movingEdges.top, movingEdges.centerY, movingEdges.bottom]) {
        const dist = Math.abs(edge - ty)
        if (dist < SNAP_THRESHOLD && (!bestSnapY || dist < bestSnapY.dist)) {
          bestSnapY = { dist, offset: ty - edge, pos: ty }
        }
      }
    }
    if (bestSnapY) {
      snappedY = newY + bestSnapY.offset
      guides.push({ orientation: 'h', position: bestSnapY.pos })
    }

    return { x: snappedX, y: snappedY, guides }
  }, [currentProject, snapEnabled, guidelines])

  // ── Canvas Rendering ──

  const renderCanvas = useCallback(() => {
    const canvas = canvasRef.current
    const container = containerRef.current
    const currentProject = projectRef.current
    if (!canvas || !container || !currentProject) return

    const dpr = window.devicePixelRatio || 1
    const cw = container.clientWidth
    const ch = container.clientHeight

    if (cw === 0 || ch === 0) {
      animFrameRef.current = requestAnimationFrame(renderCanvas)
      return
    }

    if (canvas.width !== cw * dpr || canvas.height !== ch * dpr) {
      canvas.width = cw * dpr
      canvas.height = ch * dpr
      canvas.style.width = `${cw}px`
      canvas.style.height = `${ch}px`
    }

    const ctx = canvas.getContext('2d')!
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, cw, ch)

    // Read rapidly-changing values from refs
    const zoom = zoomRef.current
    const panX = panXRef.current
    const panY = panYRef.current
    const selectedLayerId = selectedLayerIdRef.current
    const hoveredLayerId = hoveredLayerIdRef.current
    const showGrid = showGridRef.current
    const gridSize = gridSizeRef.current
    const gridColor = gridColorRef.current
    const guidelines = guidelinesRef.current
    const editingTextLayerId = editingTextLayerIdRef.current

    try {

    const scale = zoom / 100

    const pw = currentProject.width
    const ph = currentProject.height

    // ── Checkerboard transparency background (zoom-independent) ──
    // Draw in screen space so the pattern stays the same size regardless of zoom
    ctx.save()
    ctx.beginPath()
    ctx.rect(panX, panY, pw * scale, ph * scale)
    ctx.clip()
    const cs = CHECKERBOARD_SIZE
    const startX = Math.floor(panX / cs) * cs
    const startY = Math.floor(panY / cs) * cs
    const endX = panX + pw * scale
    const endY = panY + ph * scale
    for (let y = startY; y < endY; y += cs) {
      for (let x = startX; x < endX; x += cs) {
        const isLight = ((Math.floor(x / cs) + Math.floor(y / cs)) % 2) === 0
        ctx.fillStyle = isLight ? '#cccccc' : '#999999'
        ctx.fillRect(x, y, cs, cs)
      }
    }
    ctx.restore()

    ctx.save()
    ctx.translate(panX, panY)
    ctx.scale(scale, scale)

    // ── Background color ──
    if (currentProject.backgroundColor && currentProject.backgroundColor !== 'transparent' && currentProject.backgroundColor !== '#ffffff' && currentProject.backgroundColor !== '#FFFFFF') {
      ctx.fillStyle = currentProject.backgroundColor
      ctx.fillRect(0, 0, pw, ph)
    }

    // ── Clip to project bounds ──
    ctx.save()
    ctx.beginPath()
    ctx.rect(0, 0, pw, ph)
    ctx.clip()

    // ── Draw layers ──
    for (const layer of currentProject.layers) {
      if (!layer.visible) continue
      // Skip text layer being edited — the textarea overlay replaces it
      if (layer.type === 'text' && layer.id === editingTextLayerId) continue

      ctx.save()
      ctx.globalAlpha = layer.opacity / 100
      ctx.globalCompositeOperation = (layer.blendMode === 'normal' ? 'source-over' : layer.blendMode) as GlobalCompositeOperation

      // Apply per-layer filters
      const filters = layer.filters || DEFAULT_FILTERS
      const filterStr = buildFilterString(filters)
      if (filterStr !== 'none') {
        ctx.filter = filterStr
      }

      // Apply rotation
      if (layer.rotation !== 0) {
        const cx = layer.x + layer.width / 2
        const cy = layer.y + layer.height / 2
        ctx.translate(cx, cy)
        ctx.rotate((layer.rotation * Math.PI) / 180)
        ctx.translate(-cx, -cy)
      }

      // Apply layer effects (drop shadow)
      const effects = layer.layerEffects || DEFAULT_LAYER_EFFECTS
      if (effects.dropShadow.enabled) {
        ctx.shadowColor = effects.dropShadow.color + Math.round(effects.dropShadow.opacity * 2.55).toString(16).padStart(2, '0')
        ctx.shadowBlur = effects.dropShadow.blur
        ctx.shadowOffsetX = effects.dropShadow.offsetX
        ctx.shadowOffsetY = effects.dropShadow.offsetY
      }

      if (layer.type === 'image' && layer.imageData) {
        const img = getImage(layer.imageData)
        if (img) {
          if (hasPixelFilters(filters)) {
            // Render to offscreen canvas, apply pixel filters, then draw
            const offW = Math.round(layer.width)
            const offH = Math.round(layer.height)
            if (offW > 0 && offH > 0) {
              const off = document.createElement('canvas')
              off.width = offW
              off.height = offH
              const offCtx = off.getContext('2d')!
              // Apply CSS filters first on offscreen
              if (filterStr !== 'none') offCtx.filter = filterStr
              offCtx.drawImage(img, 0, 0, offW, offH)
              offCtx.filter = 'none'
              applyPixelFilters(off, filters)
              // Draw result — clear CSS filter on main ctx so it doesn't double-apply
              ctx.filter = 'none'
              ctx.drawImage(off, layer.x, layer.y, layer.width, layer.height)
            }
          } else {
            ctx.drawImage(img, layer.x, layer.y, layer.width, layer.height)
          }
        }
      } else if (layer.type === 'text' && layer.text) {
        drawTextLayer(ctx, layer)
      }

      // Outer glow (drawn as second pass)
      if (effects.outerGlow.enabled && layer.type === 'image' && layer.imageData) {
        ctx.save()
        ctx.globalAlpha = effects.outerGlow.opacity / 100
        ctx.shadowColor = effects.outerGlow.color
        ctx.shadowBlur = effects.outerGlow.blur
        ctx.shadowOffsetX = 0
        ctx.shadowOffsetY = 0
        const img = getImage(layer.imageData)
        if (img) {
          ctx.drawImage(img, layer.x, layer.y, layer.width, layer.height)
        }
        ctx.restore()
      }

      ctx.restore()
    }

    ctx.restore() // end clip

    // ── Grid overlay ──
    if (showGrid) {
      drawGrid(ctx, pw, ph, gridColor, gridSize)
    }

    // ── Hover highlight ──
    if (hoveredLayerId && hoveredLayerId !== selectedLayerId) {
      const hoverLayer = currentProject.layers.find(l => l.id === hoveredLayerId)
      if (hoverLayer && hoverLayer.visible) {
        drawLayerOutline(ctx, hoverLayer, '#3b82f6', 1.5, zoom)
      }
    }

    // ── Selection handles ──
    if (selectedLayerId) {
      const selectedLayer = currentProject.layers.find(l => l.id === selectedLayerId)
      if (selectedLayer && selectedLayer.visible) {
        drawSelectionHandles(ctx, selectedLayer, zoom)
      }
    }

    // ── Custom user guidelines (persistent) ──
    if (guidelines.length > 0) {
      drawCustomGuidelines(ctx, pw, ph, zoom, guidelines)
    }

    // ── Snap guides ──
    if (snapGuidesRef.current.length > 0) {
      drawSnapGuides(ctx, pw, ph, zoom)
    }

    // ── SAM mask overlay ──
    const selection = useCanvasStore.getState().selection
    if (selection.active && selection.type === 'mask' && selection.mask) {
      const { samEmbeddingLayerId: maskLayerId } = useCanwaAIStore.getState()
      const maskLayer = maskLayerId ? currentProject.layers.find(l => l.id === maskLayerId) : null
      const maskCanvas = document.createElement('canvas')
      maskCanvas.width = selection.mask.width
      maskCanvas.height = selection.mask.height
      const maskCtx = maskCanvas.getContext('2d')!
      maskCtx.putImageData(selection.mask, 0, 0)
      // Draw mask at source layer position (mask is full image-sized)
      // Mask pixels already have built-in alpha (180/255 ≈ 70%)
      if (maskLayer) {
        ctx.drawImage(maskCanvas, maskLayer.x, maskLayer.y, maskLayer.width, maskLayer.height)
      } else {
        ctx.drawImage(maskCanvas, selection.x, selection.y, selection.width, selection.height)
      }
    }

    // ── SAM click points ──
    const { samPoints: currentSamPoints, samEmbeddingLayerId: embLayerId } = useCanwaAIStore.getState()
    if (embLayerId && currentSamPoints.length > 0) {
      const embLayer = currentProject.layers.find(l => l.id === embLayerId)
      if (embLayer) {
        // Points are in native image pixel coords — scale back to display coords
        // Native image size comes from the mask or embedding size
        const maskW = selection?.mask?.width || embLayer.width
        const maskH = selection?.mask?.height || embLayer.height
        const invScaleX = embLayer.width / maskW
        const invScaleY = embLayer.height / maskH

        currentSamPoints.forEach(pt => {
          const ptX = embLayer.x + pt.x * invScaleX
          const ptY = embLayer.y + pt.y * invScaleY
          ctx.beginPath()
          ctx.arc(ptX, ptY, 6 / (zoom / 100), 0, Math.PI * 2)
          ctx.fillStyle = pt.label === 1 ? 'rgba(34, 197, 94, 0.8)' : 'rgba(239, 68, 68, 0.8)'
          ctx.fill()
          ctx.strokeStyle = '#fff'
          ctx.lineWidth = 2 / (zoom / 100)
          ctx.stroke()
        })
      }
    }

    ctx.restore() // end pan/zoom transform

    } catch (err) {
      console.error('[Canwa] renderCanvas error:', err)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Text Layer Rendering ──

  function drawTextLayer(ctx: CanvasRenderingContext2D, layer: Layer) {
    const text = layer.text || ''
    const fontSize = layer.fontSize || 48
    const fontFamily = layer.fontFamily || 'Inter'
    const fontWeight = layer.fontWeight || 400
    const fontColor = layer.fontColor || '#000000'
    const textAlign = layer.textAlign || 'left'
    const effects = layer.textEffects || DEFAULT_TEXT_EFFECTS

    ctx.font = `${fontWeight} ${fontSize}px "${fontFamily}"`
    ctx.textBaseline = 'top'

    // Calculate x offset based on alignment
    let xOffset = layer.x
    if (textAlign === 'center') xOffset = layer.x + layer.width / 2
    else if (textAlign === 'right') xOffset = layer.x + layer.width
    ctx.textAlign = textAlign

    const lines = text.split('\n')
    const lineHeight = fontSize * 1.3

    // Text glow effect
    if (effects.glow.enabled) {
      ctx.save()
      ctx.shadowColor = effects.glow.color
      ctx.shadowBlur = effects.glow.intensity
      ctx.shadowOffsetX = 0
      ctx.shadowOffsetY = 0
      ctx.fillStyle = fontColor
      lines.forEach((line, i) => {
        ctx.fillText(line, xOffset, layer.y + i * lineHeight)
      })
      ctx.restore()
    }

    // Text outline effect
    if (effects.outline.enabled) {
      ctx.save()
      ctx.strokeStyle = effects.outline.color
      ctx.lineWidth = effects.outline.width
      ctx.lineJoin = 'round'
      lines.forEach((line, i) => {
        ctx.strokeText(line, xOffset, layer.y + i * lineHeight)
      })
      ctx.restore()
    }

    // Text shadow effect
    if (effects.shadow.enabled) {
      ctx.save()
      ctx.shadowColor = effects.shadow.color
      ctx.shadowBlur = effects.shadow.blur
      ctx.shadowOffsetX = effects.shadow.offsetX
      ctx.shadowOffsetY = effects.shadow.offsetY
      ctx.fillStyle = fontColor
      lines.forEach((line, i) => {
        ctx.fillText(line, xOffset, layer.y + i * lineHeight)
      })
      ctx.restore()
    }

    // Main text fill (always drawn)
    if (!effects.shadow.enabled) {
      ctx.fillStyle = fontColor
      lines.forEach((line, i) => {
        ctx.fillText(line, xOffset, layer.y + i * lineHeight)
      })
    }

    // Curved text
    if (effects.curve !== 0) {
      // Curved text is drawn by re-rendering with arc - simplified version
      // The above already renders the text; curve is a visual enhancement
      // Full implementation would use ctx.translate/rotate per character
    }
  }

  // ── Grid Drawing ──

  function drawGrid(ctx: CanvasRenderingContext2D, pw: number, ph: number, _gridColor: string, _gridSize: number) {
    ctx.save()
    ctx.strokeStyle = _gridColor
    ctx.lineWidth = 0.5
    for (let x = 0; x <= pw; x += _gridSize) {
      ctx.beginPath()
      ctx.moveTo(x, 0)
      ctx.lineTo(x, ph)
      ctx.stroke()
    }
    for (let y = 0; y <= ph; y += _gridSize) {
      ctx.beginPath()
      ctx.moveTo(0, y)
      ctx.lineTo(pw, y)
      ctx.stroke()
    }
    ctx.restore()
  }

  // ── Layer Outline (Hover) ──

  function drawLayerOutline(ctx: CanvasRenderingContext2D, layer: Layer, color: string, lineWidth: number, _zoom: number) {
    ctx.save()
    if (layer.rotation !== 0) {
      const cx = layer.x + layer.width / 2
      const cy = layer.y + layer.height / 2
      ctx.translate(cx, cy)
      ctx.rotate((layer.rotation * Math.PI) / 180)
      ctx.translate(-cx, -cy)
    }
    ctx.strokeStyle = color
    ctx.lineWidth = lineWidth / (_zoom / 100)
    ctx.setLineDash([6 / (_zoom / 100), 4 / (_zoom / 100)])
    ctx.strokeRect(layer.x, layer.y, layer.width, layer.height)
    ctx.setLineDash([])
    ctx.restore()
  }

  // ── Selection Handles ──

  function drawSelectionHandles(ctx: CanvasRenderingContext2D, layer: Layer, _zoom: number) {
    const scale = _zoom / 100
    const hs = HANDLE_SIZE / scale

    ctx.save()
    if (layer.rotation !== 0) {
      const cx = layer.x + layer.width / 2
      const cy = layer.y + layer.height / 2
      ctx.translate(cx, cy)
      ctx.rotate((layer.rotation * Math.PI) / 180)
      ctx.translate(-cx, -cy)
    }

    // Selection border
    ctx.strokeStyle = '#7c3aed'
    ctx.lineWidth = 2 / scale
    ctx.strokeRect(layer.x, layer.y, layer.width, layer.height)

    // Resize handles
    const handles = [
      { x: layer.x, y: layer.y },                                    // NW
      { x: layer.x + layer.width / 2, y: layer.y },                  // N
      { x: layer.x + layer.width, y: layer.y },                      // NE
      { x: layer.x + layer.width, y: layer.y + layer.height / 2 },   // E
      { x: layer.x + layer.width, y: layer.y + layer.height },       // SE
      { x: layer.x + layer.width / 2, y: layer.y + layer.height },   // S
      { x: layer.x, y: layer.y + layer.height },                     // SW
      { x: layer.x, y: layer.y + layer.height / 2 },                 // W
    ]

    for (const h of handles) {
      ctx.fillStyle = '#ffffff'
      ctx.strokeStyle = '#7c3aed'
      ctx.lineWidth = 1.5 / scale
      ctx.fillRect(h.x - hs / 2, h.y - hs / 2, hs, hs)
      ctx.strokeRect(h.x - hs / 2, h.y - hs / 2, hs, hs)
    }

    // Rotation handle (above top-center)
    const rotX = layer.x + layer.width / 2
    const rotY = layer.y - ROTATION_HANDLE_OFFSET / scale

    // Line from top-center to rotation handle
    ctx.beginPath()
    ctx.moveTo(rotX, layer.y)
    ctx.lineTo(rotX, rotY)
    ctx.strokeStyle = '#7c3aed'
    ctx.lineWidth = 1.5 / scale
    ctx.stroke()

    // Rotation handle circle
    ctx.beginPath()
    ctx.arc(rotX, rotY, hs / 2, 0, Math.PI * 2)
    ctx.fillStyle = '#ffffff'
    ctx.fill()
    ctx.strokeStyle = '#7c3aed'
    ctx.lineWidth = 1.5 / scale
    ctx.stroke()

    ctx.restore()
  }

  // ── Custom Guidelines Drawing (persistent, user-placed) ──

  function drawCustomGuidelines(ctx: CanvasRenderingContext2D, pw: number, ph: number, _zoom: number, _guidelines: typeof guidelines) {
    const scale = _zoom / 100
    ctx.save()
    ctx.strokeStyle = '#6d28d9' // violet
    ctx.lineWidth = 1 / scale
    ctx.setLineDash([6 / scale, 3 / scale])

    for (const guide of _guidelines) {
      ctx.beginPath()
      if (guide.orientation === 'v') {
        ctx.moveTo(guide.position, 0)
        ctx.lineTo(guide.position, ph)
      } else {
        ctx.moveTo(0, guide.position)
        ctx.lineTo(pw, guide.position)
      }
      ctx.stroke()
    }

    ctx.setLineDash([])
    ctx.restore()
  }

  // ── Snap Guides Drawing ──

  function drawSnapGuides(ctx: CanvasRenderingContext2D, pw: number, ph: number, _zoom: number) {
    const scale = _zoom / 100
    ctx.save()
    ctx.strokeStyle = '#ef4444'
    ctx.lineWidth = 1 / scale
    ctx.setLineDash([4 / scale, 4 / scale])

    for (const guide of snapGuidesRef.current) {
      ctx.beginPath()
      if (guide.orientation === 'v') {
        ctx.moveTo(guide.position, 0)
        ctx.lineTo(guide.position, ph)
      } else {
        ctx.moveTo(0, guide.position)
        ctx.lineTo(pw, guide.position)
      }
      ctx.stroke()
    }

    ctx.setLineDash([])
    ctx.restore()
  }

  // ── Render Loop (store-subscription driven, decoupled from React re-renders) ──

  useEffect(() => {
    let dirty = false
    const scheduleRedraw = () => {
      if (!dirty) {
        dirty = true
        animFrameRef.current = requestAnimationFrame(() => {
          dirty = false
          renderCanvas()
        })
      }
    }

    // Register callback so images that finish loading trigger a re-render
    _onImageLoaded = scheduleRedraw

    // Subscribe to all relevant stores — any change marks dirty, draws once per frame
    const unsubCanvas = useCanvasStore.subscribe(scheduleRedraw)
    const unsubLayer = useLayerStore.subscribe(scheduleRedraw)
    const unsubAI = useCanwaAIStore.subscribe(scheduleRedraw)

    // Resize Observer (re-render when container resizes)
    const container = containerRef.current
    let ro: ResizeObserver | undefined
    if (container) {
      ro = new ResizeObserver(scheduleRedraw)
      ro.observe(container)
    }

    // Initial draw
    scheduleRedraw()

    return () => {
      cancelAnimationFrame(animFrameRef.current)
      _onImageLoaded = null
      unsubCanvas()
      unsubLayer()
      unsubAI()
      ro?.disconnect()
    }
  }, [renderCanvas])

  // ── Fit to View ──

  useEffect(() => {
    if (fitToViewTrigger === 0) return
    const container = containerRef.current
    if (!container || !currentProject) return

    const cw = container.clientWidth
    const ch = container.clientHeight
    const pw = currentProject.width
    const ph = currentProject.height

    const padding = 60
    const scaleX = (cw - padding * 2) / pw
    const scaleY = (ch - padding * 2) / ph
    const newZoom = Math.min(scaleX, scaleY) * 100

    const clamped = Math.max(10, Math.min(400, newZoom))
    const scale = clamped / 100

    setZoom(clamped, currentProject.id)
    setPan(
      (cw - pw * scale) / 2,
      (ch - ph * scale) / 2
    )
  }, [fitToViewTrigger, currentProject?.id]) // eslint-disable-line react-hooks/exhaustive-deps

  // Initial fit to view
  useEffect(() => {
    if (!currentProject) return
    const timer = setTimeout(() => {
      useCanvasStore.getState().triggerFitToView()
    }, 50)
    return () => clearTimeout(timer)
  }, [currentProject?.id]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Keyboard Events ──

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      // Don't intercept keys when an input/select/textarea is focused
      const tag = (document.activeElement?.tagName || '').toLowerCase()
      const isInput = tag === 'input' || tag === 'textarea' || tag === 'select'

      if (e.code === 'Space' && !editingTextLayerId && !isInput) {
        e.preventDefault()
        setSpaceHeld(true)
      }
      if (e.key === 'Shift') setShiftHeld(true)

      // Delete selected layer
      if ((e.key === 'Delete' || e.key === 'Backspace') && selectedLayerId && !editingTextLayerId && !isInput) {
        e.preventDefault()
        useLayerStore.getState().deleteLayer(selectedLayerId)
      }

      // Escape to deselect or stop text editing
      if (e.key === 'Escape') {
        // Clear SAM points first if active
        const samState = useCanwaAIStore.getState()
        if (samState.isSAMReady && samState.samPoints.length > 0) {
          samState.clearSAMPoints()
          e.preventDefault()
          return
        }
        if (editingTextLayerId) {
          commitTextEdit()
        } else {
          selectLayer(null)
        }
      }
    }
    const onKeyUp = (e: KeyboardEvent) => {
      if (e.code === 'Space') setSpaceHeld(false)
      if (e.key === 'Shift') setShiftHeld(false)
    }

    window.addEventListener('keydown', onKeyDown)
    window.addEventListener('keyup', onKeyUp)
    return () => {
      window.removeEventListener('keydown', onKeyDown)
      window.removeEventListener('keyup', onKeyUp)
    }
  }, [selectedLayerId, editingTextLayerId]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── Mouse Handlers ──

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    if (e.button === 1 || spaceHeld) {
      // Middle click or space+click: start panning
      setDragMode('pan')
      setDragStart({ x: e.clientX - panX, y: e.clientY - panY })
      e.preventDefault()
      return
    }

    if (e.button !== 0) return

    const { x: px, y: py } = screenToProject(e.clientX, e.clientY)

    // SAM segmentation click — only hijack when the click lands inside the
    // SAM-active layer. Outside, fall through to normal selection/drag so a
    // left-behind SAM embedding doesn't lock out the whole canvas.
    const { isSAMReady, samEmbeddingLayerId, segmentAtPoint } = useCanwaAIStore.getState()
    if (isSAMReady && samEmbeddingLayerId && !spaceHeld && currentProject) {
      const samLayer = currentProject.layers.find(l => l.id === samEmbeddingLayerId)
      if (samLayer && pointInRotatedRect(px, py, samLayer.x, samLayer.y, samLayer.width, samLayer.height, samLayer.rotation)) {
        const isPositive = !e.ctrlKey && !e.metaKey  // Ctrl/Cmd+click = exclude
        segmentAtPoint(px, py, isPositive)
        return
      }
    }

    // Check resize handles on selected layer first
    if (selectedLayerId && currentProject) {
      const selectedLayer = currentProject.layers.find(l => l.id === selectedLayerId)
      if (selectedLayer && selectedLayer.visible && !selectedLayer.locked) {
        const handleScale = HANDLE_SIZE / (zoom / 100)

        // Check rotation handle
        if (isNearRotationHandle(px, py, selectedLayer, handleScale)) {
          setDragMode('rotate')
          const cx = selectedLayer.x + selectedLayer.width / 2
          const cy = selectedLayer.y + selectedLayer.height / 2
          setRotateStart(Math.atan2(py - cy, px - cx))
          setRotateLayerStart(selectedLayer.rotation)
          setHasMoved(false)
          return
        }

        // Check resize handles
        const handle = getResizeHandleAtPoint(px, py, selectedLayer, handleScale)
        if (handle) {
          setDragMode('resize')
          setResizeHandle(handle)
          setDragStart({ x: px, y: py })
          setDragLayerStart({
            x: selectedLayer.x,
            y: selectedLayer.y,
            w: selectedLayer.width,
            h: selectedLayer.height,
          })
          setHasMoved(false)
          return
        }
      }
    }

    // Hit test for layer selection
    const hitLayer = getLayerAtPoint(px, py)
    if (hitLayer) {
      selectLayer(hitLayer.id)
      setDragMode('move')
      setDragStart({ x: px, y: py })
      setDragLayerStart({ x: hitLayer.x, y: hitLayer.y, w: hitLayer.width, h: hitLayer.height })
      setHasMoved(false)
    } else {
      selectLayer(null)
    }
  }, [spaceHeld, panX, panY, screenToProject, selectedLayerId, currentProject, zoom, getLayerAtPoint, selectLayer])

  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    const { x: px, y: py } = screenToProject(e.clientX, e.clientY)

    if (dragMode === 'pan') {
      setPan(e.clientX - dragStart.x, e.clientY - dragStart.y)
      return
    }

    if (dragMode === 'move' && selectedLayerId && currentProject) {
      const layer = currentProject.layers.find(l => l.id === selectedLayerId)
      if (!layer || layer.locked) return

      setHasMoved(true)
      const dx = px - dragStart.x
      const dy = py - dragStart.y
      let newX = dragLayerStart.x + dx
      let newY = dragLayerStart.y + dy

      // Snap
      const snap = calculateSnapGuides(layer, newX, newY)
      newX = snap.x
      newY = snap.y
      snapGuidesRef.current = snap.guides

      setLayerPosition(selectedLayerId, Math.round(newX), Math.round(newY))
      return
    }

    if (dragMode === 'resize' && selectedLayerId && resizeHandle && currentProject) {
      const layer = currentProject.layers.find(l => l.id === selectedLayerId)
      if (!layer || layer.locked) return

      setHasMoved(true)
      const dx = px - dragStart.x
      const dy = py - dragStart.y
      let { x: nx, y: ny, w: nw, h: nh } = dragLayerStart

      const aspectRatio = dragLayerStart.w / dragLayerStart.h
      // Corner handles: proportional by default, free with Shift
      // Edge handles: free by default, proportional with Shift
      const isCorner = ['nw', 'ne', 'se', 'sw'].includes(resizeHandle)
      const keepAspect = isCorner ? !shiftHeld : shiftHeld

      switch (resizeHandle) {
        case 'se':
          nw = Math.max(MIN_LAYER_SIZE, dragLayerStart.w + dx)
          nh = keepAspect ? nw / aspectRatio : Math.max(MIN_LAYER_SIZE, dragLayerStart.h + dy)
          break
        case 'nw':
          nw = Math.max(MIN_LAYER_SIZE, dragLayerStart.w - dx)
          nh = keepAspect ? nw / aspectRatio : Math.max(MIN_LAYER_SIZE, dragLayerStart.h - dy)
          nx = dragLayerStart.x + dragLayerStart.w - nw
          ny = dragLayerStart.y + dragLayerStart.h - nh
          break
        case 'ne':
          nw = Math.max(MIN_LAYER_SIZE, dragLayerStart.w + dx)
          nh = keepAspect ? nw / aspectRatio : Math.max(MIN_LAYER_SIZE, dragLayerStart.h - dy)
          ny = dragLayerStart.y + dragLayerStart.h - nh
          break
        case 'sw':
          nw = Math.max(MIN_LAYER_SIZE, dragLayerStart.w - dx)
          nh = keepAspect ? nw / aspectRatio : Math.max(MIN_LAYER_SIZE, dragLayerStart.h + dy)
          nx = dragLayerStart.x + dragLayerStart.w - nw
          break
        case 'e':
          nw = Math.max(MIN_LAYER_SIZE, dragLayerStart.w + dx)
          if (keepAspect) nh = nw / aspectRatio
          break
        case 'w':
          nw = Math.max(MIN_LAYER_SIZE, dragLayerStart.w - dx)
          nx = dragLayerStart.x + dragLayerStart.w - nw
          if (keepAspect) nh = nw / aspectRatio
          break
        case 'n':
          nh = Math.max(MIN_LAYER_SIZE, dragLayerStart.h - dy)
          ny = dragLayerStart.y + dragLayerStart.h - nh
          if (keepAspect) nw = nh * aspectRatio
          break
        case 's':
          nh = Math.max(MIN_LAYER_SIZE, dragLayerStart.h + dy)
          if (keepAspect) nw = nh * aspectRatio
          break
      }

      // Clamp max size to 10x project dimensions
      const maxW = currentProject.width * 10
      const maxH = currentProject.height * 10
      nw = Math.min(nw, maxW)
      nh = Math.min(nh, maxH)

      setLayerTransform(selectedLayerId, Math.round(nx), Math.round(ny), Math.round(nw), Math.round(nh))
      return
    }

    if (dragMode === 'rotate' && selectedLayerId && currentProject) {
      const layer = currentProject.layers.find(l => l.id === selectedLayerId)
      if (!layer || layer.locked) return

      setHasMoved(true)
      const cx = layer.x + layer.width / 2
      const cy = layer.y + layer.height / 2
      const angle = Math.atan2(py - cy, px - cx)
      let degrees = rotateLayerStart + ((angle - rotateStart) * 180) / Math.PI

      // Snap to 15-degree increments if Shift held
      if (shiftHeld) {
        degrees = Math.round(degrees / 15) * 15
      }

      setLayerRotation(selectedLayerId, degrees)
      return
    }

    // Hover detection (only when not dragging)
    if (dragMode === 'none') {
      const hitLayer = getLayerAtPoint(px, py)
      setHoveredLayerId(hitLayer?.id ?? null)

      // Update cursor based on what's under the mouse
      const canvas = canvasRef.current
      if (!canvas) return

      if (useCanwaAIStore.getState().isSAMReady && useCanwaAIStore.getState().samEmbeddingLayerId) {
        canvas.style.cursor = (e.ctrlKey || e.metaKey) ? 'not-allowed' : 'crosshair'
        return
      }

      if (spaceHeld) {
        canvas.style.cursor = 'grab'
        return
      }

      if (selectedLayerId && currentProject) {
        const selectedLayer = currentProject.layers.find(l => l.id === selectedLayerId)
        if (selectedLayer && selectedLayer.visible && !selectedLayer.locked) {
          const handleScale = HANDLE_SIZE / (zoom / 100)

          if (isNearRotationHandle(px, py, selectedLayer, handleScale)) {
            canvas.style.cursor = 'crosshair'
            return
          }

          const handle = getResizeHandleAtPoint(px, py, selectedLayer, handleScale)
          if (handle) {
            const cursors: Record<string, string> = {
              nw: 'nwse-resize', ne: 'nesw-resize', se: 'nwse-resize', sw: 'nesw-resize',
              n: 'ns-resize', s: 'ns-resize', e: 'ew-resize', w: 'ew-resize',
            }
            canvas.style.cursor = cursors[handle] || 'default'
            return
          }
        }
      }

      canvas.style.cursor = hitLayer ? 'move' : 'default'
    }
  }, [
    dragMode, dragStart, dragLayerStart, resizeHandle, shiftHeld, spaceHeld,
    screenToProject, selectedLayerId, currentProject, zoom,
    setPan, setLayerPosition, setLayerTransform, setLayerRotation,
    calculateSnapGuides, getLayerAtPoint, rotateStart, rotateLayerStart,
  ])

  const handleMouseUp = useCallback(() => {
    if ((dragMode === 'move' || dragMode === 'resize' || dragMode === 'rotate') && hasMoved) {
      try {
        pushHistory(
          dragMode === 'move' ? 'Move Layer' :
          dragMode === 'resize' ? 'Resize Layer' : 'Rotate Layer'
        )
      } catch (err) {
        console.warn('[Canwa] Failed to push history:', err)
      }
    }

    setDragMode('none')
    setResizeHandle(null)
    snapGuidesRef.current = []
    setHasMoved(false)

    const canvas = canvasRef.current
    if (canvas && !spaceHeld) {
      canvas.style.cursor = 'default'
    }
  }, [dragMode, hasMoved, pushHistory, spaceHeld])

  // ── Double-Click (Inline Text Edit) ──

  const handleDoubleClick = useCallback((e: React.MouseEvent) => {
    const { x: px, y: py } = screenToProject(e.clientX, e.clientY)
    const hitLayer = getLayerAtPoint(px, py)

    if (hitLayer && hitLayer.type === 'text') {
      setEditingTextLayerId(hitLayer.id)
      setEditingText(hitLayer.text || '')
      selectLayer(hitLayer.id)
    }
  }, [screenToProject, getLayerAtPoint, selectLayer])

  const commitTextEdit = useCallback(() => {
    if (editingTextLayerId && editingText !== undefined) {
      pushHistory('Edit Text')
      updateLayerText(editingTextLayerId, editingText)
    }
    setEditingTextLayerId(null)
    setEditingText('')
  }, [editingTextLayerId, editingText, pushHistory, updateLayerText])

  // ── Mouse Wheel (Zoom) ──

  const handleWheel = useCallback((e: React.WheelEvent) => {
    e.preventDefault()

    if (e.ctrlKey || e.metaKey) {
      // Zoom centered on cursor
      const container = containerRef.current
      if (!container) return

      const rect = container.getBoundingClientRect()
      const mx = e.clientX - rect.left
      const my = e.clientY - rect.top

      const oldScale = zoom / 100
      const delta = e.deltaY > 0 ? -5 : 5
      const newZoom = Math.max(10, Math.min(400, zoom + delta))
      const newScale = newZoom / 100

      // Adjust pan to keep the point under the cursor stable
      const newPanX = mx - (mx - panX) * (newScale / oldScale)
      const newPanY = my - (my - panY) * (newScale / oldScale)

      setZoom(newZoom, currentProject?.id)
      setPan(newPanX, newPanY)
    } else {
      // Scroll pan
      setPan(panX - e.deltaX, panY - e.deltaY)
    }
  }, [zoom, panX, panY, setZoom, setPan, currentProject?.id])

  // ── Multi-Touch Gestures ──

  const handlePointerDown = useCallback((e: React.PointerEvent) => {
    touchesRef.current.set(e.pointerId, { x: e.clientX, y: e.clientY })

    if (touchesRef.current.size === 2) {
      // Start pinch
      const points = Array.from(touchesRef.current.values())
      const dist = Math.hypot(points[1].x - points[0].x, points[1].y - points[0].y)
      pinchStartDistRef.current = dist
      pinchStartZoomRef.current = zoom
      pinchStartPanRef.current = { x: panX, y: panY }
    }
  }, [zoom, panX, panY])

  const handlePointerMove = useCallback((e: React.PointerEvent) => {
    if (!touchesRef.current.has(e.pointerId)) return
    touchesRef.current.set(e.pointerId, { x: e.clientX, y: e.clientY })

    if (touchesRef.current.size === 2) {
      const points = Array.from(touchesRef.current.values())
      const dist = Math.hypot(points[1].x - points[0].x, points[1].y - points[0].y)
      const ratio = dist / pinchStartDistRef.current
      const newZoom = Math.max(10, Math.min(400, pinchStartZoomRef.current * ratio))

      // Two-finger pan: track midpoint delta
      const midX = (points[0].x + points[1].x) / 2
      const midY = (points[0].y + points[1].y) / 2

      setZoom(newZoom, currentProject?.id)
      // Simplified pan during pinch
      setPan(pinchStartPanRef.current.x + (midX - (points[0].x + points[1].x) / 2), pinchStartPanRef.current.y + (midY - (points[0].y + points[1].y) / 2))
    }
  }, [setZoom, setPan, currentProject?.id])

  const handlePointerUp = useCallback((e: React.PointerEvent) => {
    touchesRef.current.delete(e.pointerId)
  }, [])

  // ── Drag and Drop ──

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragOver(true)
  }, [])

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragOver(false)
  }, [])

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setIsDragOver(false)

    const files = Array.from(e.dataTransfer.files)
    const imageFiles = files.filter(f => f.type.startsWith('image/'))

    for (const file of imageFiles) {
      addImageAsLayer(file)
    }
  }, [addImageAsLayer])

  // ── Get the editing layer for the inline text overlay ──

  const editingLayer = editingTextLayerId && currentProject
    ? currentProject.layers.find(l => l.id === editingTextLayerId) ?? null
    : null

  // Compute textarea position in screen coords
  const textOverlayStyle = useMemo(() => {
    if (!editingLayer) return null
    const scale = zoom / 100
    return {
      position: 'absolute' as const,
      left: editingLayer.x * scale + panX,
      top: editingLayer.y * scale + panY,
      width: editingLayer.width * scale,
      minHeight: editingLayer.height * scale,
      fontSize: (editingLayer.fontSize || 48) * scale,
      fontFamily: editingLayer.fontFamily || 'Inter',
      fontWeight: editingLayer.fontWeight || 400,
      color: editingLayer.fontColor || '#000000',
      textAlign: (editingLayer.textAlign || 'left') as React.CSSProperties['textAlign'],
      lineHeight: 1.3,
      background: 'transparent',
      border: '2px solid #7c3aed',
      borderRadius: 4,
      outline: 'none',
      resize: 'none' as const,
      padding: 4,
      zIndex: 50,
      transform: editingLayer.rotation ? `rotate(${editingLayer.rotation}deg)` : undefined,
      transformOrigin: 'top left',
      overflow: 'visible' as const,
      whiteSpace: 'pre' as const,
      boxSizing: 'border-box' as const,
    }
  }, [editingLayer, zoom, panX, panY])

  return (
    <div
      ref={containerRef}
      className={`absolute inset-0 overflow-hidden ${!workspaceBg ? 'bg-gray-200 dark:bg-gray-800' : ''}`}
      style={workspaceBg ? { backgroundColor: workspaceBg } : undefined}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      <canvas
        data-canwa-canvas
        ref={canvasRef}
        onMouseDown={handleMouseDown}
        onMouseMove={handleMouseMove}
        onMouseUp={handleMouseUp}
        onMouseLeave={handleMouseUp}
        onDoubleClick={handleDoubleClick}
        onWheel={handleWheel}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        className="absolute inset-0"
        style={{ touchAction: 'none' }}
      />

      {/* Inline text editor overlay */}
      {editingTextLayerId && editingLayer && textOverlayStyle && (
        <textarea
          value={editingText}
          onChange={e => {
            const v = e.target.value
            setEditingText(v)
            // Live-resize the layer so the textarea hugs the text while typing.
            if (editingTextLayerId) updateLayerText(editingTextLayerId, v)
          }}
          onBlur={commitTextEdit}
          onKeyDown={e => {
            if (e.key === 'Escape') {
              commitTextEdit()
            }
            // Allow Enter for newlines, Ctrl+Enter to commit
            if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
              e.preventDefault()
              commitTextEdit()
            }
            e.stopPropagation()
          }}
          autoFocus
          style={textOverlayStyle}
        />
      )}

      {/* Drag-drop overlay */}
      {isDragOver && (
        <div className="absolute inset-0 bg-violet-500/20 border-2 border-dashed border-violet-500 flex items-center justify-center pointer-events-none z-40">
          <div className="bg-white dark:bg-gray-800 px-6 py-4 shadow-lg">
            <p className="text-violet-600 dark:text-violet-400 font-medium">Drop image to add as layer</p>
          </div>
        </div>
      )}
    </div>
  )
}
