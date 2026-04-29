import { create } from 'zustand'
import type { Layer } from '@/apps/imageeditor/types'
import { generateId } from '@/apps/imageeditor/types'
import { callOpenRouterProxy, fetchExternalImage, safeJsonParse } from './utils/openRouterProxy'
import { useLayerStore } from './layerStore'
import { useHistoryStore } from './historyStore'
import { useCanvasStore } from './canvasStore'
import { DEFAULT_SELECTION } from '@/apps/imageeditor/types'

// ---------------------------------------------------------------------------
// Helper: extract image data URL from various AI response formats
// ---------------------------------------------------------------------------
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function extractImageFromResponse(data: Record<string, any>): string | null {
  let imageData: string | null = null
  const message = data.choices?.[0]?.message
  const content = message?.content

  // Format 1: Images array in message (Gemini via OpenRouter)
  if (message?.images && Array.isArray(message.images)) {
    for (const img of message.images) {
      if (img.type === 'image_url' && img.image_url?.url) { imageData = img.image_url.url; break }
      if (img.url) { imageData = img.url; break }
    }
  }

  // Format 2: Content is array with image parts (OpenAI/Gemini style)
  if (!imageData && Array.isArray(content)) {
    for (const part of content) {
      if (part.type === 'image_url' && part.image_url?.url) { imageData = part.image_url.url; break }
      if (part.type === 'image' && part.source?.data) {
        imageData = `data:${part.source.media_type || 'image/png'};base64,${part.source.data}`; break
      }
      if (part.inline_data?.data) {
        imageData = `data:${part.inline_data.mime_type || 'image/png'};base64,${part.inline_data.data}`; break
      }
    }
  }

  // Format 3: Content is string with base64 data URL
  if (!imageData && content && typeof content === 'string') {
    const base64Match = content.match(/data:image\/[^;]+;base64,[A-Za-z0-9+/=]+/)
    if (base64Match) imageData = base64Match[0]
    const mdImageMatch = content.match(/!\[.*?\]\((https?:\/\/[^\s)]+)\)/)
    if (!imageData && mdImageMatch) imageData = mdImageMatch[1]
  }

  // Format 4: Direct URL in data field (some providers)
  if (!imageData && data.data?.[0]?.url) imageData = data.data[0].url
  if (!imageData && data.data?.[0]?.b64_json) imageData = `data:image/png;base64,${data.data[0].b64_json}`

  // Format 5: Image URL in message (DALL-E style via OpenRouter)
  if (!imageData && message?.image_url) imageData = message.image_url

  // Format 6: Tool call with image result
  if (!imageData && message?.tool_calls) {
    for (const toolCall of message.tool_calls) {
      if (toolCall.function?.name === 'generate_image') {
        const args = safeJsonParse<Record<string, string>>(toolCall.function.arguments || '{}', {})
        if (args.url) imageData = args.url
        if (args.image) imageData = args.image
      }
    }
  }

  return imageData
}

interface AIState {
  // Loading flags
  isRemovingBackground: boolean
  isAutoEnhancing: boolean
  isGeneratingImage: boolean
  isEditingImage: boolean
  isEditingAllLayers: boolean
  isEditingLayerWithContext: boolean
  isApplyingFilter: boolean
  isUpscaling: boolean
  isExtractingColors: boolean
  isExtendingImage: boolean
  extractedColors: string[]
  pickedColor: string | null // Color picked from palette — shared across panels

  // SAM state
  isSAMLoading: boolean
  isSAMReady: boolean
  isSAMSegmenting: boolean
  samEmbeddingLayerId: string | null
  samPoints: { x: number; y: number; label: 0 | 1 }[]
  samMode: 'browser' | 'server'
  samServerAvailable: boolean | null

  // Methods
  removeBackground: (layerId: string) => Promise<void>
  autoEnhance: (layerId: string) => Promise<void>
  addBackgroundGradient: (gradient: { startColor: string; endColor: string; type: 'linear' | 'radial'; angle?: number }) => void
  addBackgroundPattern: (patternType: string, colors: string[]) => void
  generateAIImage: (prompt: string) => Promise<void>
  editImageWithAI: (layerId: string, prompt: string) => Promise<void>
  editAllLayersWithAI: (prompt: string) => Promise<void>
  editLayerWithContext: (instruction: string) => Promise<void>
  applyAIFilter: (layerId: string, filterType: string) => Promise<void>
  upscaleImage: (layerId: string, scale: number) => Promise<void>
  extractColorPalette: (layerId: string) => Promise<void>
  extendImageToFit: (layerId: string, useAI?: boolean) => Promise<void>
  setPickedColor: (color: string | null) => void

  // SAM methods
  setSAMMode: (mode: 'browser' | 'server') => void
  checkSAMServerStatus: () => Promise<void>
  loadSAM: () => Promise<void>
  generateSAMEmbedding: (layerId: string) => Promise<void>
  segmentAtPoint: (x: number, y: number, isPositive: boolean) => Promise<void>
  clearSAMPoints: () => Promise<void>
  confirmSAMSelection: () => void
}

export const useAIStore = create<AIState>()((set, get) => ({
  // Loading flags
  isRemovingBackground: false,
  isAutoEnhancing: false,
  isGeneratingImage: false,
  isEditingImage: false,
  isEditingAllLayers: false,
  isEditingLayerWithContext: false,
  isApplyingFilter: false,
  isUpscaling: false,
  isExtractingColors: false,
  isExtendingImage: false,
  extractedColors: [],
  pickedColor: null,

  // SAM state
  isSAMLoading: false,
  isSAMReady: false,
  isSAMSegmenting: false,
  samEmbeddingLayerId: null,
  samPoints: [],
  samMode: 'browser',
  samServerAvailable: null,

  // =========================================================================
  // Background Removal
  // =========================================================================
  removeBackground: async (layerId) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    const layer = currentProject.layers.find((l) => l.id === layerId)
    if (!layer || !layer.imageData) {
      showToast('No image data to process', 'error')
      return
    }

    set({ isRemovingBackground: true })
    showToast('Removing background... This may take a moment', 'info')

    try {
      // Dynamic import to avoid loading the large library until needed
      const { removeBackground: removeBg } = await import('@imgly/background-removal')

      // Convert data URL to blob
      const response = await fetch(layer.imageData)
      const blob = await response.blob()

      // Remove background with proper configuration
      const resultBlob = await removeBg(blob, {
        output: {
          format: 'image/png',
          quality: 1,
        },
        progress: (key, current, total) => {
          console.log(`Background removal: ${key} ${Math.round((current / total) * 100)}%`)
        },
      })

      // Convert result back to data URL
      const reader = new FileReader()
      const resultDataUrl = await new Promise<string>((resolve, reject) => {
        reader.onload = () => resolve(reader.result as string)
        reader.onerror = reject
        reader.readAsDataURL(resultBlob)
      })

      pushHistory('Remove Background')

      // Update the layer with the new image
      useLayerStore.setState((state) => ({
        currentProject: state.currentProject
          ? {
              ...state.currentProject,
              layers: state.currentProject.layers.map((l) =>
                l.id === layerId
                  ? { ...l, imageData: resultDataUrl }
                  : l
              ),
              updatedAt: Date.now(),
            }
          : null,
        isDirty: true,
      }))

      set({ isRemovingBackground: false })
      showToast('Background removed successfully', 'success')
    } catch (error) {
      console.error('Background removal failed:', error)
      set({ isRemovingBackground: false })
      showToast('Failed to remove background', 'error')
    }
  },

  // =========================================================================
  // Auto-Enhance Image
  // =========================================================================
  autoEnhance: async (layerId) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    const layer = currentProject.layers.find((l) => l.id === layerId)
    if (!layer || !layer.imageData) {
      showToast('No image data to enhance', 'error')
      return
    }

    set({ isAutoEnhancing: true })
    showToast('Enhancing image...', 'info')

    try {
      // Load the image
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = reject
        img.src = layer.imageData!
      })

      // Create canvas for processing
      const canvas = document.createElement('canvas')
      canvas.width = img.width
      canvas.height = img.height
      const ctx = canvas.getContext('2d')
      if (!ctx) throw new Error('Failed to get canvas context')

      ctx.drawImage(img, 0, 0)
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
      const data = imageData.data

      // Analyze image statistics
      let minR = 255, maxR = 0, minG = 255, maxG = 0, minB = 255, maxB = 0
      let totalBrightness = 0
      let totalSaturation = 0
      const pixelCount = data.length / 4

      for (let i = 0; i < data.length; i += 4) {
        const r = data[i]
        const g = data[i + 1]
        const b = data[i + 2]

        minR = Math.min(minR, r)
        maxR = Math.max(maxR, r)
        minG = Math.min(minG, g)
        maxG = Math.max(maxG, g)
        minB = Math.min(minB, b)
        maxB = Math.max(maxB, b)

        // Calculate brightness (luminance)
        const brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255
        totalBrightness += brightness

        // Calculate saturation
        const max = Math.max(r, g, b)
        const min = Math.min(r, g, b)
        const saturation = max === 0 ? 0 : (max - min) / max
        totalSaturation += saturation
      }

      const avgBrightness = totalBrightness / pixelCount
      const avgSaturation = totalSaturation / pixelCount

      // Calculate auto-levels stretch factors
      const rangeR = maxR - minR || 1
      const rangeG = maxG - minG || 1
      const rangeB = maxB - minB || 1

      // Apply enhancements
      for (let i = 0; i < data.length; i += 4) {
        let r = data[i]
        let g = data[i + 1]
        let b = data[i + 2]

        // 1. Auto-levels (stretch histogram)
        r = Math.round(((r - minR) / rangeR) * 255)
        g = Math.round(((g - minG) / rangeG) * 255)
        b = Math.round(((b - minB) / rangeB) * 255)

        // 2. Brightness adjustment (if image is too dark or bright)
        const brightnessAdjust = avgBrightness < 0.4 ? 20 : avgBrightness > 0.6 ? -10 : 0
        r = Math.min(255, Math.max(0, r + brightnessAdjust))
        g = Math.min(255, Math.max(0, g + brightnessAdjust))
        b = Math.min(255, Math.max(0, b + brightnessAdjust))

        // 3. Contrast enhancement
        const contrastFactor = 1.1
        r = Math.min(255, Math.max(0, Math.round((r - 128) * contrastFactor + 128)))
        g = Math.min(255, Math.max(0, Math.round((g - 128) * contrastFactor + 128)))
        b = Math.min(255, Math.max(0, Math.round((b - 128) * contrastFactor + 128)))

        // 4. Saturation boost (if undersaturated)
        if (avgSaturation < 0.3) {
          const gray = 0.299 * r + 0.587 * g + 0.114 * b
          const satBoost = 1.15
          r = Math.min(255, Math.max(0, Math.round(gray + (r - gray) * satBoost)))
          g = Math.min(255, Math.max(0, Math.round(gray + (g - gray) * satBoost)))
          b = Math.min(255, Math.max(0, Math.round(gray + (b - gray) * satBoost)))
        }

        data[i] = r
        data[i + 1] = g
        data[i + 2] = b
      }

      ctx.putImageData(imageData, 0, 0)

      // Apply subtle sharpening using convolution
      const tempCanvas = document.createElement('canvas')
      tempCanvas.width = canvas.width
      tempCanvas.height = canvas.height
      const tempCtx = tempCanvas.getContext('2d')
      if (tempCtx) {
        tempCtx.drawImage(canvas, 0, 0)
        // Simple sharpening by drawing slightly smaller and larger
        ctx.globalAlpha = 0.15
        ctx.drawImage(tempCanvas, -1, -1, canvas.width + 2, canvas.height + 2)
        ctx.globalAlpha = 1
      }

      pushHistory('Auto Enhance')

      const enhancedImageData = canvas.toDataURL('image/png')

      useLayerStore.setState((state) => ({
        currentProject: state.currentProject
          ? {
              ...state.currentProject,
              layers: state.currentProject.layers.map((l) =>
                l.id === layerId ? { ...l, imageData: enhancedImageData } : l
              ),
              updatedAt: Date.now(),
            }
          : null,
        isDirty: true,
      }))

      set({ isAutoEnhancing: false })
      showToast('Image enhanced successfully', 'success')
    } catch (error) {
      console.error('Auto-enhance failed:', error)
      set({ isAutoEnhancing: false })
      showToast('Failed to enhance image', 'error')
    }
  },

  // =========================================================================
  // Add Gradient Background Layer
  // =========================================================================
  addBackgroundGradient: (gradient) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    pushHistory('Add Gradient Background')

    const canvas = document.createElement('canvas')
    canvas.width = currentProject.width
    canvas.height = currentProject.height
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let grad: CanvasGradient
    const angle = gradient.angle || 0
    const angleRad = (angle * Math.PI) / 180

    if (gradient.type === 'linear') {
      // Calculate gradient start/end points based on angle
      const centerX = canvas.width / 2
      const centerY = canvas.height / 2
      const length = Math.sqrt(canvas.width * canvas.width + canvas.height * canvas.height) / 2

      const x1 = centerX - Math.cos(angleRad) * length
      const y1 = centerY - Math.sin(angleRad) * length
      const x2 = centerX + Math.cos(angleRad) * length
      const y2 = centerY + Math.sin(angleRad) * length

      grad = ctx.createLinearGradient(x1, y1, x2, y2)
    } else {
      grad = ctx.createRadialGradient(
        canvas.width / 2,
        canvas.height / 2,
        0,
        canvas.width / 2,
        canvas.height / 2,
        Math.max(canvas.width, canvas.height) / 2
      )
    }

    grad.addColorStop(0, gradient.startColor)
    grad.addColorStop(1, gradient.endColor)

    ctx.fillStyle = grad
    ctx.fillRect(0, 0, canvas.width, canvas.height)

    const imageData = canvas.toDataURL('image/png')

    const newLayer: Layer = {
      id: generateId(),
      name: `Gradient ${gradient.type}`,
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
      imageData,
    }

    // Insert at the bottom (index 0) so it's behind other layers
    useLayerStore.setState((state) => ({
      currentProject: state.currentProject
        ? {
            ...state.currentProject,
            layers: [newLayer, ...state.currentProject.layers],
            updatedAt: Date.now(),
          }
        : null,
      selectedLayerId: newLayer.id,
      isDirty: true,
    }))

    showToast('Gradient background added', 'success')
  },

  // =========================================================================
  // Add Pattern Background Layer
  // =========================================================================
  addBackgroundPattern: (patternType, colors) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    pushHistory('Add Pattern Background')

    const canvas = document.createElement('canvas')
    canvas.width = currentProject.width
    canvas.height = currentProject.height
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const [color1, color2] = colors

    switch (patternType) {
      case 'stripes': {
        const stripeWidth = 20
        for (let x = 0; x < canvas.width + canvas.height; x += stripeWidth * 2) {
          ctx.fillStyle = color1
          ctx.beginPath()
          ctx.moveTo(x, 0)
          ctx.lineTo(x + stripeWidth, 0)
          ctx.lineTo(x + stripeWidth - canvas.height, canvas.height)
          ctx.lineTo(x - canvas.height, canvas.height)
          ctx.closePath()
          ctx.fill()

          ctx.fillStyle = color2
          ctx.beginPath()
          ctx.moveTo(x + stripeWidth, 0)
          ctx.lineTo(x + stripeWidth * 2, 0)
          ctx.lineTo(x + stripeWidth * 2 - canvas.height, canvas.height)
          ctx.lineTo(x + stripeWidth - canvas.height, canvas.height)
          ctx.closePath()
          ctx.fill()
        }
        break
      }
      case 'dots': {
        ctx.fillStyle = color1
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        ctx.fillStyle = color2
        const dotRadius = 8
        const spacing = 30
        for (let y = 0; y < canvas.height + spacing; y += spacing) {
          for (let x = 0; x < canvas.width + spacing; x += spacing) {
            ctx.beginPath()
            ctx.arc(x, y, dotRadius, 0, Math.PI * 2)
            ctx.fill()
          }
        }
        break
      }
      case 'checkerboard': {
        const size = 40
        for (let y = 0; y < canvas.height; y += size) {
          for (let x = 0; x < canvas.width; x += size) {
            ctx.fillStyle = ((x / size + y / size) % 2 === 0) ? color1 : color2
            ctx.fillRect(x, y, size, size)
          }
        }
        break
      }
      case 'waves': {
        ctx.fillStyle = color1
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        ctx.strokeStyle = color2
        ctx.lineWidth = 3
        const amplitude = 20
        const frequency = 0.02
        for (let y = -amplitude; y < canvas.height + amplitude * 2; y += 30) {
          ctx.beginPath()
          for (let x = 0; x <= canvas.width; x += 5) {
            const waveY = y + Math.sin(x * frequency) * amplitude
            if (x === 0) ctx.moveTo(x, waveY)
            else ctx.lineTo(x, waveY)
          }
          ctx.stroke()
        }
        break
      }
      case 'grid': {
        ctx.fillStyle = color1
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        ctx.strokeStyle = color2
        ctx.lineWidth = 1
        const gridSize = 30
        for (let x = 0; x < canvas.width; x += gridSize) {
          ctx.beginPath()
          ctx.moveTo(x, 0)
          ctx.lineTo(x, canvas.height)
          ctx.stroke()
        }
        for (let y = 0; y < canvas.height; y += gridSize) {
          ctx.beginPath()
          ctx.moveTo(0, y)
          ctx.lineTo(canvas.width, y)
          ctx.stroke()
        }
        break
      }
      default:
        ctx.fillStyle = color1
        ctx.fillRect(0, 0, canvas.width, canvas.height)
    }

    const imageData = canvas.toDataURL('image/png')

    const newLayer: Layer = {
      id: generateId(),
      name: `Pattern ${patternType}`,
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
      imageData,
    }

    // Insert at the bottom
    useLayerStore.setState((state) => ({
      currentProject: state.currentProject
        ? {
            ...state.currentProject,
            layers: [newLayer, ...state.currentProject.layers],
            updatedAt: Date.now(),
          }
        : null,
      selectedLayerId: newLayer.id,
      isDirty: true,
    }))

    showToast('Pattern background added', 'success')
  },

  // =========================================================================
  // AI Image Generation
  // =========================================================================
  generateAIImage: async (prompt) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    set({ isGeneratingImage: true })
    showToast('Generating AI image...', 'info')

    try {
      // Get image model from AI store
      const { useAIStore } = await import('@/stores/aiStore')
      const aiState = useAIStore.getState()
      const imageModel = aiState.imageModel || 'google/gemini-2.0-flash-001:image-generation'

      // Use backend proxy (API key is handled server-side)
      const data = await callOpenRouterProxy({
        model: imageModel,
        messages: [{ role: 'user', content: prompt }],
      })

      // SECURITY: Only log in development to avoid exposing sensitive data
      if (import.meta.env.DEV) {
        console.log('AI Image Generation Response:', JSON.stringify(data, null, 2))
      }

      // Extract image from response - handle various formats
      let imageData: string | null = null
      const message = data.choices?.[0]?.message
      const content = message?.content

      // Format 1: Images array in message (Gemini via OpenRouter)
      if (message?.images && Array.isArray(message.images)) {
        for (const img of message.images) {
          if (img.type === 'image_url' && img.image_url?.url) {
            imageData = img.image_url.url
            break
          }
          if (img.url) {
            imageData = img.url
            break
          }
        }
      }

      // Format 2: Content is array with image parts (OpenAI/Gemini style)
      if (!imageData && Array.isArray(content)) {
        for (const part of content) {
          // image_url format
          if (part.type === 'image_url' && part.image_url?.url) {
            imageData = part.image_url.url
            break
          }
          // inline_data format (Gemini)
          if (part.type === 'image' && part.source?.data) {
            const mimeType = part.source.media_type || 'image/png'
            imageData = `data:${mimeType};base64,${part.source.data}`
            break
          }
          // Another inline format
          if (part.inline_data?.data) {
            const mimeType = part.inline_data.mime_type || 'image/png'
            imageData = `data:${mimeType};base64,${part.inline_data.data}`
            break
          }
        }
      }

      // Format 2: Content is string with base64 data URL
      if (!imageData && content && typeof content === 'string') {
        const base64Match = content.match(/data:image\/[^;]+;base64,[A-Za-z0-9+/=]+/)
        if (base64Match) {
          imageData = base64Match[0]
        }
        // Check for markdown image with URL
        const mdImageMatch = content.match(/!\[.*?\]\((https?:\/\/[^\s)]+)\)/)
        if (!imageData && mdImageMatch) {
          imageData = mdImageMatch[1]
        }
      }

      // Format 3: Direct URL in data field (some providers)
      if (!imageData && data.data?.[0]?.url) {
        imageData = data.data[0].url
      }
      if (!imageData && data.data?.[0]?.b64_json) {
        imageData = `data:image/png;base64,${data.data[0].b64_json}`
      }

      // Format 4: Image URL in message (DALL-E style via OpenRouter)
      if (!imageData && message?.image_url) {
        imageData = message.image_url
      }

      // Format 5: Tool call with image result
      if (!imageData && message?.tool_calls) {
        for (const toolCall of message.tool_calls) {
          if (toolCall.function?.name === 'generate_image') {
            const args = safeJsonParse<Record<string, string>>(toolCall.function.arguments || '{}', {})
            if (args.url) imageData = args.url
            if (args.image) imageData = args.image
          }
        }
      }

      if (!imageData) {
        console.error('Could not extract image from response. Full response:', data)
        throw new Error('No image generated in response. Check console for details.')
      }

      // If it's a URL (not base64), fetch and convert to base64 (with validation)
      if (imageData.startsWith('http')) {
        showToast('Downloading generated image...', 'info')
        imageData = await fetchExternalImage(imageData)
      }

      pushHistory('AI Generate Image')

      // Create a new layer with the generated image
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = reject
        img.src = imageData!
      })

      const newLayer: Layer = {
        id: generateId(),
        name: `AI: ${prompt.slice(0, 20)}...`,
        type: 'image',
        visible: true,
        locked: false,
        opacity: 100,
        blendMode: 'normal',
        x: Math.floor((currentProject.width - img.width) / 2),
        y: Math.floor((currentProject.height - img.height) / 2),
        width: img.width,
        height: img.height,
        rotation: 0,
        imageData,
      }

      useLayerStore.setState((state) => ({
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

      set({ isGeneratingImage: false })

      // Immediately save to backend after AI generation (costs money!)
      await useLayerStore.getState().saveProjectToBackend()

      showToast('AI image generated and saved', 'success')
    } catch (error) {
      console.error('AI image generation failed:', error)
      set({ isGeneratingImage: false })
      showToast('Failed to generate image', 'error')
    }
  },

  // =========================================================================
  // AI Image Editing - modify existing image with AI
  // =========================================================================
  editImageWithAI: async (layerId, prompt) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    const layer = currentProject.layers.find((l) => l.id === layerId)
    if (!layer || !layer.imageData) {
      showToast('Kein Bild zum Bearbeiten gefunden', 'error')
      return
    }

    set({ isEditingImage: true })
    showToast('Bild wird mit KI bearbeitet...', 'info')

    try {
      // Get image model from AI store
      const { useAIStore } = await import('@/stores/aiStore')
      const aiState = useAIStore.getState()
      const imageModel = aiState.imageModel || 'google/gemini-2.0-flash-001:image-generation'

      // Use backend proxy (API key is handled server-side)
      const data = await callOpenRouterProxy({
        model: imageModel,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image_url',
                image_url: { url: layer.imageData },
              },
              {
                type: 'text',
                text: `Edit this image: ${prompt}. Return only the edited image.`,
              },
            ],
          },
        ],
      })

      // SECURITY: Only log in development to avoid exposing sensitive data
      if (import.meta.env.DEV) {
        console.log('AI Image Edit Response:', JSON.stringify(data, null, 2))
      }

      // Extract image from response - handle various formats (same as generateAIImage)
      let imageData: string | null = null
      const message = data.choices?.[0]?.message
      const content = message?.content

      // Format 1: Images array in message (Gemini via OpenRouter)
      if (message?.images && Array.isArray(message.images)) {
        for (const img of message.images) {
          if (img.type === 'image_url' && img.image_url?.url) {
            imageData = img.image_url.url
            break
          }
          if (img.url) {
            imageData = img.url
            break
          }
        }
      }

      // Format 2: Content is array with image parts
      if (!imageData && Array.isArray(content)) {
        for (const part of content) {
          if (part.type === 'image_url' && part.image_url?.url) {
            imageData = part.image_url.url
            break
          }
          if (part.type === 'image' && part.source?.data) {
            const mimeType = part.source.media_type || 'image/png'
            imageData = `data:${mimeType};base64,${part.source.data}`
            break
          }
          if (part.inline_data?.data) {
            const mimeType = part.inline_data.mime_type || 'image/png'
            imageData = `data:${mimeType};base64,${part.inline_data.data}`
            break
          }
        }
      }

      // Format 3: Content is string with base64 data URL
      if (!imageData && content && typeof content === 'string') {
        const base64Match = content.match(/data:image\/[^;]+;base64,[A-Za-z0-9+/=]+/)
        if (base64Match) {
          imageData = base64Match[0]
        }
        const mdImageMatch = content.match(/!\[.*?\]\((https?:\/\/[^\s)]+)\)/)
        if (!imageData && mdImageMatch) {
          imageData = mdImageMatch[1]
        }
      }

      // Format 4: Direct URL in data field
      if (!imageData && data.data?.[0]?.url) {
        imageData = data.data[0].url
      }
      if (!imageData && data.data?.[0]?.b64_json) {
        imageData = `data:image/png;base64,${data.data[0].b64_json}`
      }

      // Format 5: Image URL in message
      if (!imageData && message?.image_url) {
        imageData = message.image_url
      }

      if (!imageData) {
        console.error('Could not extract edited image from response. Full response:', data)
        throw new Error('Kein bearbeitetes Bild in der Antwort. Prüfe die Konsole für Details.')
      }

      // If it's a URL (not base64), fetch and convert to base64 (with validation)
      if (imageData.startsWith('http')) {
        showToast('Bearbeitetes Bild wird heruntergeladen...', 'info')
        imageData = await fetchExternalImage(imageData)
      }

      pushHistory('AI Edit Image')

      // Load the new image to get dimensions
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = reject
        img.src = imageData!
      })

      // Create a new layer with the edited image (don't replace original)
      const newLayer: Layer = {
        id: generateId(),
        name: `AI Edit: ${prompt.slice(0, 15)}...`,
        type: 'image',
        visible: true,
        locked: false,
        opacity: 100,
        blendMode: 'normal',
        x: layer.x,
        y: layer.y,
        width: img.width,
        height: img.height,
        rotation: 0,
        imageData,
      }

      useLayerStore.setState((state) => ({
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

      set({ isEditingImage: false })

      // Immediately save to backend after AI edit (costs money!)
      await useLayerStore.getState().saveProjectToBackend()

      showToast('Bild mit KI bearbeitet und gespeichert', 'success')
    } catch (error) {
      console.error('AI image edit failed:', error)
      set({ isEditingImage: false })
      showToast('Bearbeitung fehlgeschlagen', 'error')
    }
  },

  // =========================================================================
  // Edit all visible layers flattened together with AI
  // =========================================================================
  editAllLayersWithAI: async (prompt) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    // Get all visible layers with image data
    const visibleLayers = currentProject.layers.filter(l => l.visible && l.imageData)
    if (visibleLayers.length === 0) {
      showToast('Keine sichtbaren Ebenen mit Bildern', 'error')
      return
    }

    set({ isEditingAllLayers: true })
    showToast('Alle Ebenen werden mit KI bearbeitet...', 'info')

    try {
      // Create a flattened canvas of all visible layers
      const canvas = document.createElement('canvas')
      canvas.width = currentProject.width
      canvas.height = currentProject.height
      const ctx = canvas.getContext('2d')
      if (!ctx) throw new Error('Could not get canvas context')

      // Fill with background color
      ctx.fillStyle = currentProject.backgroundColor
      ctx.fillRect(0, 0, canvas.width, canvas.height)

      // Draw each visible layer in order
      for (const layer of currentProject.layers.filter(l => l.visible)) {
        if (layer.imageData) {
          const img = new Image()
          await new Promise<void>((resolve, reject) => {
            img.onload = () => resolve()
            img.onerror = reject
            img.src = layer.imageData!
          })

          ctx.save()
          ctx.globalAlpha = layer.opacity / 100
          // Simple composite - could add blend modes later
          ctx.drawImage(img, layer.x, layer.y, layer.width, layer.height)
          ctx.restore()
        }
      }

      // Convert flattened canvas to base64
      const flattenedImageData = canvas.toDataURL('image/png')

      // Get image model from AI store
      const { useAIStore } = await import('@/stores/aiStore')
      const aiState = useAIStore.getState()
      const imageModel = aiState.imageModel || 'google/gemini-2.0-flash-001:image-generation'

      // Send flattened image to AI
      const data = await callOpenRouterProxy({
        model: imageModel,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image_url',
                image_url: { url: flattenedImageData },
              },
              {
                type: 'text',
                text: `Edit this image: ${prompt}. Return only the edited image.`,
              },
            ],
          },
        ],
      })

      // SECURITY: Only log in development to avoid exposing sensitive data
      if (import.meta.env.DEV) {
        console.log('AI Edit All Response:', JSON.stringify(data, null, 2))
      }

      // Extract image from response (same logic as editImageWithAI)
      let imageData: string | null = null
      const message = data.choices?.[0]?.message
      const content = message?.content

      if (message?.images && Array.isArray(message.images)) {
        for (const img of message.images) {
          if (img.type === 'image_url' && img.image_url?.url) {
            imageData = img.image_url.url
            break
          }
          if (img.url) {
            imageData = img.url
            break
          }
        }
      }

      if (!imageData && Array.isArray(content)) {
        for (const part of content) {
          if (part.type === 'image_url' && part.image_url?.url) {
            imageData = part.image_url.url
            break
          }
          if (part.type === 'image' && part.source?.data) {
            const mimeType = part.source.media_type || 'image/png'
            imageData = `data:${mimeType};base64,${part.source.data}`
            break
          }
          if (part.inline_data?.data) {
            const mimeType = part.inline_data.mime_type || 'image/png'
            imageData = `data:${mimeType};base64,${part.inline_data.data}`
            break
          }
        }
      }

      if (!imageData && content && typeof content === 'string') {
        const base64Match = content.match(/data:image\/[^;]+;base64,[A-Za-z0-9+/=]+/)
        if (base64Match) {
          imageData = base64Match[0]
        }
        const mdImageMatch = content.match(/!\[.*?\]\((https?:\/\/[^\s)]+)\)/)
        if (!imageData && mdImageMatch) {
          imageData = mdImageMatch[1]
        }
      }

      if (!imageData && data.data?.[0]?.url) {
        imageData = data.data[0].url
      }
      if (!imageData && data.data?.[0]?.b64_json) {
        imageData = `data:image/png;base64,${data.data[0].b64_json}`
      }

      if (!imageData && message?.image_url) {
        imageData = message.image_url
      }

      if (!imageData) {
        console.error('Could not extract edited image from response. Full response:', data)
        throw new Error('Kein bearbeitetes Bild in der Antwort.')
      }

      // If it's a URL, fetch and convert to base64
      if (imageData.startsWith('http')) {
        showToast('Bearbeitetes Bild wird heruntergeladen...', 'info')
        imageData = await fetchExternalImage(imageData)
      }

      pushHistory('AI Edit All Layers')

      // Load the new image to get dimensions
      const resultImg = new Image()
      await new Promise<void>((resolve, reject) => {
        resultImg.onload = () => resolve()
        resultImg.onerror = reject
        resultImg.src = imageData!
      })

      // Create a new layer with the edited image
      const newLayer: Layer = {
        id: generateId(),
        name: `AI Edit: ${prompt.slice(0, 15)}...`,
        type: 'image',
        visible: true,
        locked: false,
        opacity: 100,
        blendMode: 'normal',
        x: 0,
        y: 0,
        width: resultImg.width,
        height: resultImg.height,
        rotation: 0,
        imageData,
      }

      useLayerStore.setState((state) => ({
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

      set({ isEditingAllLayers: false })

      await useLayerStore.getState().saveProjectToBackend()
      showToast('Alle Ebenen mit KI bearbeitet', 'success')
    } catch (error) {
      console.error('AI edit all layers failed:', error)
      set({ isEditingAllLayers: false })
      showToast('Bearbeitung fehlgeschlagen', 'error')
    }
  },

  // =========================================================================
  // AI Context-Aware Layer Editing - Two-step process:
  // 1. Analysis LLM analyzes composite + layer to generate detailed prompt
  // 2. Image generation model creates new layer based on that prompt
  // =========================================================================
  editLayerWithContext: async (instruction) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    // Optional: use selected layer for extra context
    const selectedLayerId = useLayerStore.getState().selectedLayerId
    const selectedLayer = selectedLayerId
      ? currentProject.layers.find((l) => l.id === selectedLayerId)
      : null

    set({ isEditingLayerWithContext: true })
    showToast('Analysiere Bild...', 'info')

    try {
      // Get models from AI store
      const { useAIStore } = await import('@/stores/aiStore')
      const aiState = useAIStore.getState()
      const analysisModel = aiState.analysisModel || 'google/gemini-2.0-flash-001'
      const imageModel = aiState.imageModel || 'google/gemini-2.0-flash-001:image-generation'

      // Step 1: Render composite image of all layers
      const compositeCanvas = document.createElement('canvas')
      compositeCanvas.width = currentProject.width
      compositeCanvas.height = currentProject.height
      const compositeCtx = compositeCanvas.getContext('2d')
      if (!compositeCtx) throw new Error('Failed to get canvas context')

      compositeCtx.fillStyle = currentProject.backgroundColor || '#ffffff'
      compositeCtx.fillRect(0, 0, compositeCanvas.width, compositeCanvas.height)

      for (const l of currentProject.layers) {
        if (!l.visible) continue
        if (l.imageData) {
          try {
            const img = await new Promise<HTMLImageElement>((resolve, reject) => {
              const image = new Image()
              image.onload = () => resolve(image)
              image.onerror = reject
              image.src = l.imageData!
            })
            compositeCtx.save()
            compositeCtx.globalAlpha = l.opacity / 100
            compositeCtx.translate(l.x + l.width / 2, l.y + l.height / 2)
            compositeCtx.rotate((l.rotation * Math.PI) / 180)
            compositeCtx.drawImage(img, -l.width / 2, -l.height / 2, l.width, l.height)
            compositeCtx.restore()
          } catch { /* skip */ }
        } else if (l.type === 'text' && l.text) {
          compositeCtx.save()
          compositeCtx.globalAlpha = l.opacity / 100
          compositeCtx.font = `${l.fontSize || 24}px ${l.fontFamily || 'Arial'}`
          compositeCtx.fillStyle = l.fontColor || '#000000'
          compositeCtx.textAlign = (l.textAlign as CanvasTextAlign) || 'left'
          compositeCtx.fillText(l.text, l.x, l.y + (l.fontSize || 24))
          compositeCtx.restore()
        }
      }

      const compositeImage = compositeCanvas.toDataURL('image/png')

      // Step 2: Call analysis LLM with composite (+ optional selected layer)
      showToast('KI erstellt detaillierten Prompt...', 'info')

      const analysisContent: Array<{ type: string; text?: string; image_url?: { url: string } }> = [
        { type: 'image_url', image_url: { url: compositeImage } },
      ]

      // If a layer with image data is selected, send it as extra context
      if (selectedLayer?.imageData) {
        analysisContent.push({ type: 'image_url', image_url: { url: selectedLayer.imageData } })
      }

      const hasLayerContext = selectedLayer?.imageData
      analysisContent.push({
        type: 'text',
        text: hasLayerContext
          ? `Du bist ein Experte für Bildgenerierung. Analysiere diese zwei Bilder:

Bild 1: Das Gesamtbild (Komposition aller Ebenen)
Bild 2: Eine ausgewählte Ebene aus diesem Bild

Der Benutzer möchte folgendes: "${instruction}"

Erstelle einen detaillierten, präzisen Prompt für ein Bildgenerierungsmodell.
Der Prompt soll beschreiben, wie das neue Bild aussehen soll, damit es:
1. Zur Gesamtkomposition passt (Stil, Farben, Perspektive)
2. Die Anweisung des Benutzers umsetzt

Antworte NUR mit dem Prompt, ohne weitere Erklärungen. Englisch, max 200 Wörter.`
          : `Du bist ein Experte für Bildgenerierung. Analysiere dieses Bild (Komposition aller Ebenen).

Der Benutzer möchte folgendes: "${instruction}"

Erstelle einen detaillierten, präzisen Prompt für ein Bildgenerierungsmodell.
Der Prompt soll beschreiben, wie das neue Bild aussehen soll, damit es:
1. Zur Gesamtkomposition passt (Stil, Farben, Perspektive)
2. Die Anweisung des Benutzers umsetzt

Antworte NUR mit dem Prompt, ohne weitere Erklärungen. Englisch, max 200 Wörter.`,
      })

      const analysisData = await callOpenRouterProxy({
        model: analysisModel,
        messages: [{ role: 'user', content: analysisContent }],
      })

      const generatedPrompt = analysisData.choices?.[0]?.message?.content
      if (!generatedPrompt || typeof generatedPrompt !== 'string') {
        throw new Error('Kein Prompt vom Analyse-LLM generiert')
      }

      if (import.meta.env.DEV) {
        console.log('Generated prompt from analysis:', generatedPrompt)
      }

      // Step 3: Generate new image using the detailed prompt (inline, no generateAIImage call)
      showToast('Generiere neue Ebene...', 'info')

      const data = await callOpenRouterProxy({
        model: imageModel,
        messages: [{ role: 'user', content: generatedPrompt.trim() }],
      })

      let imageData = extractImageFromResponse(data)

      if (!imageData) {
        throw new Error('Kein Bild in der Antwort')
      }

      if (imageData.startsWith('http')) {
        showToast('Bild wird heruntergeladen...', 'info')
        imageData = await fetchExternalImage(imageData)
      }

      pushHistory('AI Context Edit')

      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = reject
        img.src = imageData!
      })

      const newLayer: Layer = {
        id: generateId(),
        name: `AI Context: ${instruction.slice(0, 15)}...`,
        type: 'image',
        visible: true,
        locked: false,
        opacity: 100,
        blendMode: 'normal',
        x: Math.floor((currentProject.width - img.width) / 2),
        y: Math.floor((currentProject.height - img.height) / 2),
        width: img.width,
        height: img.height,
        rotation: 0,
        imageData,
      }

      useLayerStore.setState((state) => ({
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

      set({ isEditingLayerWithContext: false })
      await useLayerStore.getState().saveProjectToBackend()
      showToast('Neue Ebene basierend auf Analyse erstellt', 'success')
    } catch (error) {
      console.error('AI context-aware edit failed:', error)
      set({ isEditingLayerWithContext: false })
      showToast(`Kontextbasierte Bearbeitung fehlgeschlagen: ${error instanceof Error ? error.message : 'Unbekannter Fehler'}`, 'error')
    }
  },

  // =========================================================================
  // AI Filters - Pixel manipulation filters
  // =========================================================================
  applyAIFilter: async (layerId, filterType) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    const layer = currentProject.layers.find((l) => l.id === layerId)
    if (!layer || !layer.imageData) {
      showToast('No image data to filter', 'error')
      return
    }

    set({ isApplyingFilter: true })
    showToast(`Applying ${filterType} filter...`, 'info')

    try {
      // Load the image
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = reject
        img.src = layer.imageData!
      })

      // Create canvas for processing
      const canvas = document.createElement('canvas')
      canvas.width = img.width
      canvas.height = img.height
      const ctx = canvas.getContext('2d')
      if (!ctx) throw new Error('Failed to get canvas context')

      ctx.drawImage(img, 0, 0)
      const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
      const data = imageData.data

      // Apply filter based on type
      switch (filterType) {
        case 'vintage': {
          // Sepia tone + vignette + grain
          for (let i = 0; i < data.length; i += 4) {
            const r = data[i], g = data[i + 1], b = data[i + 2]
            // Sepia
            data[i] = Math.min(255, r * 0.393 + g * 0.769 + b * 0.189)
            data[i + 1] = Math.min(255, r * 0.349 + g * 0.686 + b * 0.168)
            data[i + 2] = Math.min(255, r * 0.272 + g * 0.534 + b * 0.131)
            // Add subtle grain
            const noise = (Math.random() - 0.5) * 20
            data[i] = Math.min(255, Math.max(0, data[i] + noise))
            data[i + 1] = Math.min(255, Math.max(0, data[i + 1] + noise))
            data[i + 2] = Math.min(255, Math.max(0, data[i + 2] + noise))
          }
          break
        }
        case 'cinematic': {
          // Teal and orange color grading + contrast
          for (let i = 0; i < data.length; i += 4) {
            let r = data[i], g = data[i + 1], b = data[i + 2]
            // Increase contrast
            r = Math.min(255, Math.max(0, (r - 128) * 1.2 + 128))
            g = Math.min(255, Math.max(0, (g - 128) * 1.2 + 128))
            b = Math.min(255, Math.max(0, (b - 128) * 1.2 + 128))
            // Teal shadows, orange highlights
            const luminance = (r + g + b) / 3
            if (luminance < 128) {
              // Shadows - add teal
              b = Math.min(255, b + 20)
              g = Math.min(255, g + 10)
            } else {
              // Highlights - add orange
              r = Math.min(255, r + 20)
              g = Math.min(255, g + 5)
            }
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
          }
          break
        }
        case 'hdr': {
          // High dynamic range effect
          for (let i = 0; i < data.length; i += 4) {
            let r = data[i], g = data[i + 1], b = data[i + 2]
            // Boost saturation
            const gray = 0.299 * r + 0.587 * g + 0.114 * b
            const satBoost = 1.4
            r = Math.min(255, Math.max(0, gray + (r - gray) * satBoost))
            g = Math.min(255, Math.max(0, gray + (g - gray) * satBoost))
            b = Math.min(255, Math.max(0, gray + (b - gray) * satBoost))
            // Boost contrast
            r = Math.min(255, Math.max(0, (r - 128) * 1.3 + 128))
            g = Math.min(255, Math.max(0, (g - 128) * 1.3 + 128))
            b = Math.min(255, Math.max(0, (b - 128) * 1.3 + 128))
            // Boost clarity (local contrast)
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
          }
          break
        }
        case 'noir': {
          // Black and white with high contrast
          for (let i = 0; i < data.length; i += 4) {
            const r = data[i], g = data[i + 1], b = data[i + 2]
            // Weighted grayscale
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            // High contrast
            gray = Math.min(255, Math.max(0, (gray - 128) * 1.5 + 128))
            data[i] = gray
            data[i + 1] = gray
            data[i + 2] = gray
          }
          break
        }
        case 'dreamy': {
          // Soft, ethereal look with slight blur and glow
          for (let i = 0; i < data.length; i += 4) {
            let r = data[i], g = data[i + 1], b = data[i + 2]
            // Lighten
            r = Math.min(255, r + 20)
            g = Math.min(255, g + 20)
            b = Math.min(255, b + 25)
            // Reduce contrast
            r = Math.min(255, Math.max(0, (r - 128) * 0.85 + 128 + 15))
            g = Math.min(255, Math.max(0, (g - 128) * 0.85 + 128 + 15))
            b = Math.min(255, Math.max(0, (b - 128) * 0.85 + 128 + 20))
            // Slight pink tint
            r = Math.min(255, r + 5)
            b = Math.min(255, b + 10)
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
          }
          break
        }
        case 'pop': {
          // Vibrant pop art style
          for (let i = 0; i < data.length; i += 4) {
            let r = data[i], g = data[i + 1], b = data[i + 2]
            // Posterize
            r = Math.round(r / 64) * 64
            g = Math.round(g / 64) * 64
            b = Math.round(b / 64) * 64
            // Boost saturation
            const gray = 0.299 * r + 0.587 * g + 0.114 * b
            r = Math.min(255, Math.max(0, gray + (r - gray) * 2))
            g = Math.min(255, Math.max(0, gray + (g - gray) * 2))
            b = Math.min(255, Math.max(0, gray + (b - gray) * 2))
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
          }
          break
        }
        case 'cool': {
          // Cool blue tones
          for (let i = 0; i < data.length; i += 4) {
            let r = data[i], g = data[i + 1], b = data[i + 2]
            // Shift towards blue
            r = Math.max(0, r - 15)
            b = Math.min(255, b + 25)
            g = Math.min(255, g + 5)
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
          }
          break
        }
        case 'warm': {
          // Warm orange/yellow tones
          for (let i = 0; i < data.length; i += 4) {
            let r = data[i], g = data[i + 1], b = data[i + 2]
            // Shift towards warm
            r = Math.min(255, r + 25)
            g = Math.min(255, g + 10)
            b = Math.max(0, b - 15)
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
          }
          break
        }
        case 'fade': {
          // Faded film look
          for (let i = 0; i < data.length; i += 4) {
            let r = data[i], g = data[i + 1], b = data[i + 2]
            // Lift blacks
            r = Math.min(255, r * 0.9 + 25)
            g = Math.min(255, g * 0.9 + 25)
            b = Math.min(255, b * 0.9 + 30)
            // Reduce saturation
            const gray = 0.299 * r + 0.587 * g + 0.114 * b
            r = Math.min(255, Math.max(0, gray + (r - gray) * 0.7))
            g = Math.min(255, Math.max(0, gray + (g - gray) * 0.7))
            b = Math.min(255, Math.max(0, gray + (b - gray) * 0.7))
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
          }
          break
        }
        case 'dramatic': {
          // High contrast dramatic look
          for (let i = 0; i < data.length; i += 4) {
            let r = data[i], g = data[i + 1], b = data[i + 2]
            // Strong contrast
            r = Math.min(255, Math.max(0, (r - 128) * 1.5 + 128))
            g = Math.min(255, Math.max(0, (g - 128) * 1.5 + 128))
            b = Math.min(255, Math.max(0, (b - 128) * 1.5 + 128))
            // Slight desaturation
            const gray = 0.299 * r + 0.587 * g + 0.114 * b
            r = Math.min(255, Math.max(0, gray + (r - gray) * 0.85))
            g = Math.min(255, Math.max(0, gray + (g - gray) * 0.85))
            b = Math.min(255, Math.max(0, gray + (b - gray) * 0.85))
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
          }
          break
        }
      }

      ctx.putImageData(imageData, 0, 0)
      pushHistory(`Apply ${filterType} Filter`)

      const filteredImageData = canvas.toDataURL('image/png')

      useLayerStore.setState((state) => ({
        currentProject: state.currentProject
          ? {
              ...state.currentProject,
              layers: state.currentProject.layers.map((l) =>
                l.id === layerId ? { ...l, imageData: filteredImageData } : l
              ),
              updatedAt: Date.now(),
            }
          : null,
        isDirty: true,
      }))

      set({ isApplyingFilter: false })
      showToast(`${filterType} filter applied`, 'success')
    } catch (error) {
      console.error('Filter application failed:', error)
      set({ isApplyingFilter: false })
      showToast('Failed to apply filter', 'error')
    }
  },

  // =========================================================================
  // AI Upscaling with Real-ESRGAN via Replicate
  // =========================================================================
  upscaleImage: async (layerId, scale) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    const layer = currentProject.layers.find((l) => l.id === layerId)
    if (!layer || !layer.imageData) {
      showToast('No image data to upscale', 'error')
      return
    }

    set({ isUpscaling: true })
    showToast(`KI-Upscaling ${scale}x läuft...`, 'info')

    try {
      // Call backend Replicate API
      const response = await fetch('/api/ai/upscale', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          image: layer.imageData,
          scale: scale,
          face_enhance: false
        })
      })

      if (!response.ok) {
        const error = await response.json()
        throw new Error(error.error || 'Upscaling failed')
      }

      const result = await response.json()

      pushHistory(`Upscale ${scale}x`)

      useLayerStore.setState((state) => ({
        currentProject: state.currentProject
          ? {
              ...state.currentProject,
              layers: state.currentProject.layers.map((l) =>
                l.id === layerId
                  ? { ...l, imageData: result.image_url, width: result.width, height: result.height }
                  : l
              ),
              updatedAt: Date.now(),
            }
          : null,
        isDirty: true,
      }))

      set({ isUpscaling: false })
      showToast(`Bild auf ${result.width}x${result.height} vergrößert`, 'success')
    } catch (error) {
      console.error('Upscaling failed:', error)
      set({ isUpscaling: false })
      showToast(error instanceof Error ? error.message : 'Upscaling fehlgeschlagen', 'error')
    }
  },

  // =========================================================================
  // Extract Dominant Colors from Image
  // =========================================================================
  extractColorPalette: async (layerId) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    if (!currentProject) return

    const layer = currentProject.layers.find((l) => l.id === layerId)
    if (!layer || !layer.imageData) {
      showToast('No image data to analyze', 'error')
      return
    }

    set({ isExtractingColors: true })

    try {
      // Load the image
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = reject
        img.src = layer.imageData!
      })

      // Create small canvas for sampling
      const sampleSize = 100
      const canvas = document.createElement('canvas')
      canvas.width = sampleSize
      canvas.height = sampleSize
      const ctx = canvas.getContext('2d')
      if (!ctx) throw new Error('Failed to get canvas context')

      ctx.drawImage(img, 0, 0, sampleSize, sampleSize)
      const imageData = ctx.getImageData(0, 0, sampleSize, sampleSize)
      const data = imageData.data

      // Simple k-means clustering for color extraction
      const colors: [number, number, number][] = []
      for (let i = 0; i < data.length; i += 4) {
        colors.push([data[i], data[i + 1], data[i + 2]])
      }

      // Quantize colors into buckets
      const bucketSize = 32
      const colorBuckets: Map<string, { count: number; r: number; g: number; b: number }> = new Map()

      for (const [r, g, b] of colors) {
        const qr = Math.round(r / bucketSize) * bucketSize
        const qg = Math.round(g / bucketSize) * bucketSize
        const qb = Math.round(b / bucketSize) * bucketSize
        const key = `${qr}-${qg}-${qb}`

        const existing = colorBuckets.get(key)
        if (existing) {
          existing.count++
          existing.r += r
          existing.g += g
          existing.b += b
        } else {
          colorBuckets.set(key, { count: 1, r, g, b })
        }
      }

      // Get top 6 colors
      const sortedBuckets = Array.from(colorBuckets.values())
        .sort((a, b) => b.count - a.count)
        .slice(0, 6)

      const extractedColors = sortedBuckets.map((bucket) => {
        const avgR = Math.round(bucket.r / bucket.count)
        const avgG = Math.round(bucket.g / bucket.count)
        const avgB = Math.round(bucket.b / bucket.count)
        return `#${avgR.toString(16).padStart(2, '0')}${avgG.toString(16).padStart(2, '0')}${avgB.toString(16).padStart(2, '0')}`
      })

      set({
        extractedColors,
        isExtractingColors: false,
      })

      showToast('Colors extracted', 'success')
    } catch (error) {
      console.error('Color extraction failed:', error)
      set({ isExtractingColors: false })
      showToast('Failed to extract colors', 'error')
    }
  },

  // =========================================================================
  // Extend Image to Fit Project Canvas
  // =========================================================================
  extendImageToFit: async (layerId, useAI = false) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { pushHistory } = useHistoryStore.getState()
    if (!currentProject) return

    const layer = currentProject.layers.find((l) => l.id === layerId)
    if (!layer || !layer.imageData) {
      showToast('Keine Bilddaten zum Erweitern', 'error')
      return
    }

    // Check if extension is needed
    const targetWidth = currentProject.width
    const targetHeight = currentProject.height
    if (layer.width >= targetWidth && layer.height >= targetHeight) {
      showToast('Bild ist bereits groß genug', 'info')
      return
    }

    set({ isExtendingImage: true })
    showToast(useAI ? 'Erweitere Bild mit KI...' : 'Erweitere Bild...', 'info')

    try {
      // Load the original image
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = reject
        img.src = layer.imageData!
      })

      if (useAI) {
        // AI-based extension using OpenRouter proxy
        const { useAIStore } = await import('@/stores/aiStore')
        const aiState = useAIStore.getState()
        const imageModel = aiState.imageModel || 'google/gemini-2.0-flash-001:image-generation'

        // Directly extend the image using the image model with outpainting prompt
        showToast('Erweitere Bild mit KI...', 'info')

        const extendPrompt = `OUTPAINTING TASK - EXTEND IMAGE TO ${targetWidth}x${targetHeight}px

CRITICAL RULES:
1. DO NOT modify, alter, or change ANY part of the original image
2. The original image MUST remain EXACTLY as it is - pixel-perfect preservation
3. ONLY add new content to extend the canvas to fill ${targetWidth}x${targetHeight}px
4. The new extended areas must seamlessly blend with the existing image edges
5. Match the exact style, colors, lighting, and atmosphere of the original

Current image size: ${img.width}x${img.height}px
Target canvas size: ${targetWidth}x${targetHeight}px
Extension needed: ${targetWidth > img.width ? `${targetWidth - img.width}px wider` : ''} ${targetHeight > img.height ? `${targetHeight - img.height}px taller` : ''}

Extend the canvas by continuing the background/environment naturally. The original subject/content must not be touched or regenerated.`

        const genData = await callOpenRouterProxy({
          model: imageModel,
          messages: [{
            role: 'user',
            content: [
              { type: 'image_url', image_url: { url: layer.imageData } },
              { type: 'text', text: extendPrompt },
            ],
          }],
        })

        // Extract image from response (same logic as generateAIImage)
        let newImageData: string | null = null
        const message = genData.choices?.[0]?.message
        const content = message?.content

        if (message?.images && Array.isArray(message.images)) {
          for (const imgItem of message.images) {
            if (imgItem.type === 'image_url' && imgItem.image_url?.url) {
              newImageData = imgItem.image_url.url
              break
            }
            if (imgItem.url) {
              newImageData = imgItem.url
              break
            }
          }
        }

        if (!newImageData && Array.isArray(content)) {
          for (const part of content) {
            if (part.type === 'image_url' && part.image_url?.url) {
              newImageData = part.image_url.url
              break
            }
            if (part.inline_data?.data) {
              const mimeType = part.inline_data.mime_type || 'image/png'
              newImageData = `data:${mimeType};base64,${part.inline_data.data}`
              break
            }
          }
        }

        if (!newImageData && content && typeof content === 'string') {
          const base64Match = content.match(/data:image\/[^;]+;base64,[A-Za-z0-9+/=]+/)
          if (base64Match) newImageData = base64Match[0]
        }

        if (!newImageData && genData.data?.[0]?.url) {
          newImageData = genData.data[0].url
        }
        if (!newImageData && genData.data?.[0]?.b64_json) {
          newImageData = `data:image/png;base64,${genData.data[0].b64_json}`
        }

        if (!newImageData) {
          throw new Error('Kein Bild in der Antwort')
        }

        // Fetch if URL (with validation)
        if (newImageData.startsWith('http')) {
          newImageData = await fetchExternalImage(newImageData)
        }

        pushHistory('AI Extend Image')

        // Load the generated image
        const newImg = new Image()
        await new Promise<void>((resolve, reject) => {
          newImg.onload = () => resolve()
          newImg.onerror = reject
          newImg.src = newImageData!
        })

        // Scale/fit the generated image to target size if needed
        let finalImageData = newImageData
        if (newImg.width !== targetWidth || newImg.height !== targetHeight) {
          showToast('Passe Größe an...', 'info')

          const scaleCanvas = document.createElement('canvas')
          scaleCanvas.width = targetWidth
          scaleCanvas.height = targetHeight
          const scaleCtx = scaleCanvas.getContext('2d')
          if (scaleCtx) {
            // Calculate scaling to cover the target area (crop if needed)
            const scale = Math.max(targetWidth / newImg.width, targetHeight / newImg.height)
            const scaledWidth = newImg.width * scale
            const scaledHeight = newImg.height * scale
            const offsetX = (targetWidth - scaledWidth) / 2
            const offsetY = (targetHeight - scaledHeight) / 2

            scaleCtx.drawImage(newImg, offsetX, offsetY, scaledWidth, scaledHeight)
            finalImageData = scaleCanvas.toDataURL('image/png')
          }
        }

        const newLayer = {
          id: generateId(),
          name: `${layer.name} (erweitert)`,
          type: 'image' as const,
          visible: true,
          locked: false,
          opacity: 100,
          blendMode: 'normal' as const,
          x: 0,
          y: 0,
          width: targetWidth,
          height: targetHeight,
          rotation: 0,
          imageData: finalImageData,
        }

        useLayerStore.setState((state) => ({
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

        set({ isExtendingImage: false })

        await useLayerStore.getState().saveProjectToBackend()
        showToast('Bild mit KI erweitert', 'success')

      } else {
        // Local extension: Analyze edges and create gradient fill
        const canvas = document.createElement('canvas')
        canvas.width = targetWidth
        canvas.height = targetHeight
        const ctx = canvas.getContext('2d')
        if (!ctx) throw new Error('Canvas context failed')

        // Sample edge colors from original image
        const sampleCanvas = document.createElement('canvas')
        sampleCanvas.width = img.width
        sampleCanvas.height = img.height
        const sampleCtx = sampleCanvas.getContext('2d')
        if (!sampleCtx) throw new Error('Sample canvas context failed')
        sampleCtx.drawImage(img, 0, 0)

        // Get average colors from each edge
        const getEdgeColor = (edge: 'top' | 'bottom' | 'left' | 'right') => {
          const sampleSize = 10
          let r = 0, g = 0, b = 0, count = 0

          if (edge === 'top' || edge === 'bottom') {
            const y = edge === 'top' ? 0 : img.height - sampleSize
            const data = sampleCtx!.getImageData(0, y, img.width, sampleSize).data
            for (let i = 0; i < data.length; i += 4) {
              r += data[i]; g += data[i + 1]; b += data[i + 2]; count++
            }
          } else {
            const x = edge === 'left' ? 0 : img.width - sampleSize
            const data = sampleCtx!.getImageData(x, 0, sampleSize, img.height).data
            for (let i = 0; i < data.length; i += 4) {
              r += data[i]; g += data[i + 1]; b += data[i + 2]; count++
            }
          }

          return `rgb(${Math.round(r / count)}, ${Math.round(g / count)}, ${Math.round(b / count)})`
        }

        const topColor = getEdgeColor('top')
        const bottomColor = getEdgeColor('bottom')
        const leftColor = getEdgeColor('left')
        const rightColor = getEdgeColor('right')

        // Calculate center position for the original image
        const offsetX = Math.floor((targetWidth - img.width) / 2)
        const offsetY = Math.floor((targetHeight - img.height) / 2)

        // Create gradient background
        // Vertical gradient
        const vGradient = ctx.createLinearGradient(0, 0, 0, targetHeight)
        vGradient.addColorStop(0, topColor)
        vGradient.addColorStop(0.5, topColor)
        vGradient.addColorStop(0.5, bottomColor)
        vGradient.addColorStop(1, bottomColor)
        ctx.fillStyle = vGradient
        ctx.fillRect(0, 0, targetWidth, targetHeight)

        // Horizontal gradient overlay with transparency
        ctx.globalCompositeOperation = 'overlay'
        const hGradient = ctx.createLinearGradient(0, 0, targetWidth, 0)
        hGradient.addColorStop(0, leftColor)
        hGradient.addColorStop(0.5, 'transparent')
        hGradient.addColorStop(1, rightColor)
        ctx.fillStyle = hGradient
        ctx.fillRect(0, 0, targetWidth, targetHeight)

        // Reset composite operation
        ctx.globalCompositeOperation = 'source-over'

        // Apply blur to the background for smoother transition
        ctx.filter = 'blur(20px)'
        ctx.drawImage(canvas, 0, 0)
        ctx.filter = 'none'

        // Draw original image in center
        ctx.drawImage(img, offsetX, offsetY)

        // Blend edges with feathered mask
        const featherSize = 30
        ctx.globalCompositeOperation = 'destination-out'

        // Top feather
        if (offsetY > 0) {
          const topFade = ctx.createLinearGradient(0, offsetY, 0, offsetY + featherSize)
          topFade.addColorStop(0, 'rgba(0,0,0,1)')
          topFade.addColorStop(1, 'rgba(0,0,0,0)')
          ctx.fillStyle = topFade
          ctx.fillRect(offsetX, offsetY, img.width, featherSize)
        }

        // Bottom feather
        if (offsetY + img.height < targetHeight) {
          const bottomFade = ctx.createLinearGradient(0, offsetY + img.height - featherSize, 0, offsetY + img.height)
          bottomFade.addColorStop(0, 'rgba(0,0,0,0)')
          bottomFade.addColorStop(1, 'rgba(0,0,0,1)')
          ctx.fillStyle = bottomFade
          ctx.fillRect(offsetX, offsetY + img.height - featherSize, img.width, featherSize)
        }

        // Left feather
        if (offsetX > 0) {
          const leftFade = ctx.createLinearGradient(offsetX, 0, offsetX + featherSize, 0)
          leftFade.addColorStop(0, 'rgba(0,0,0,1)')
          leftFade.addColorStop(1, 'rgba(0,0,0,0)')
          ctx.fillStyle = leftFade
          ctx.fillRect(offsetX, offsetY, featherSize, img.height)
        }

        // Right feather
        if (offsetX + img.width < targetWidth) {
          const rightFade = ctx.createLinearGradient(offsetX + img.width - featherSize, 0, offsetX + img.width, 0)
          rightFade.addColorStop(0, 'rgba(0,0,0,0)')
          rightFade.addColorStop(1, 'rgba(0,0,0,1)')
          ctx.fillStyle = rightFade
          ctx.fillRect(offsetX + img.width - featherSize, offsetY, featherSize, img.height)
        }

        ctx.globalCompositeOperation = 'source-over'

        // Redraw original image on top
        ctx.drawImage(img, offsetX, offsetY)

        const extendedImageData = canvas.toDataURL('image/png')

        pushHistory('Extend Image')

        // Update the layer with extended image
        useLayerStore.setState((state) => ({
          currentProject: state.currentProject
            ? {
                ...state.currentProject,
                layers: state.currentProject.layers.map((l) =>
                  l.id === layerId
                    ? {
                        ...l,
                        imageData: extendedImageData,
                        width: targetWidth,
                        height: targetHeight,
                        x: 0,
                        y: 0,
                      }
                    : l
                ),
                updatedAt: Date.now(),
              }
            : null,
          isDirty: true,
        }))

        set({ isExtendingImage: false })
        showToast('Bild erweitert', 'success')
      }
    } catch (error) {
      console.error('Image extension failed:', error)
      set({ isExtendingImage: false })
      showToast(`Erweiterung fehlgeschlagen: ${error instanceof Error ? error.message : 'Unbekannter Fehler'}`, 'error')
    }
  },

  setPickedColor: (color) => set({ pickedColor: color }),

  // =========================================================================
  // SAM (AI Object Selection)
  // =========================================================================
  setSAMMode: (mode) => {
    // Clear existing embedding when switching modes
    get().clearSAMPoints()
    set({ samMode: mode, isSAMReady: false })
  },

  checkSAMServerStatus: async () => {
    try {
      const { samBackendClient } = await import('@/services/sam')
      const status = await samBackendClient.checkStatus()
      set({ samServerAvailable: status.available })
    } catch {
      set({ samServerAvailable: false })
    }
  },

  loadSAM: async () => {
    const { showToast } = useCanvasStore.getState()
    const { samMode } = get()
    if (get().isSAMReady || get().isSAMLoading) return

    set({ isSAMLoading: true })

    if (samMode === 'server') {
      // Server mode: just verify server is available
      showToast('Verbinde mit Server-SAM...', 'info')
      try {
        const { samBackendClient } = await import('@/services/sam')
        const status = await samBackendClient.checkStatus()
        if (!status.available) {
          throw new Error('Server-SAM nicht verfügbar. MobileSAM nicht installiert.')
        }
        set({ isSAMLoading: false, isSAMReady: true, samServerAvailable: true })
        showToast('Server-SAM bereit', 'success')
      } catch (error) {
        console.error('Failed to connect to SAM server:', error)
        set({ isSAMLoading: false, samServerAvailable: false })
        showToast(
          `Server-SAM nicht verfügbar: ${error instanceof Error ? error.message : 'Unbekannter Fehler'}`,
          'error'
        )
      }
    } else {
      // Browser mode: download and load model
      showToast('Lade AI-Segmentierung (~30MB)...', 'info')
      try {
        const { samService } = await import('@/services/sam')
        await samService.loadModels({
          onProgress: (progress, message) => {
            console.log(`SAM loading: ${progress}% - ${message}`)
          },
        })
        set({ isSAMLoading: false, isSAMReady: true })
        showToast('AI-Segmentierung bereit', 'success')
      } catch (error) {
        console.error('Failed to load SAM:', error)
        set({ isSAMLoading: false })
        showToast(
          `SAM konnte nicht geladen werden: ${error instanceof Error ? error.message : 'Unbekannter Fehler'}`,
          'error'
        )
      }
    }
  },

  generateSAMEmbedding: async (layerId) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { isSAMReady, samMode } = get()
    console.log('generateSAMEmbedding called, isSAMReady:', isSAMReady, 'mode:', samMode)
    if (!currentProject || !isSAMReady) {
      console.log('generateSAMEmbedding: early return', { currentProject: !!currentProject, isSAMReady })
      return
    }

    const layer = currentProject.layers.find((l) => l.id === layerId)
    if (!layer || !layer.imageData) {
      showToast('Keine Bilddaten vorhanden', 'error')
      return
    }

    set({ isSAMSegmenting: true })

    try {
      // Load the image and convert to ImageData
      const img = new Image()
      await new Promise<void>((resolve, reject) => {
        img.onload = () => resolve()
        img.onerror = reject
        img.src = layer.imageData!
      })

      console.log('Generating SAM embedding for image:', img.width, 'x', img.height)

      const canvas = document.createElement('canvas')
      canvas.width = img.width
      canvas.height = img.height
      const ctx = canvas.getContext('2d')
      if (!ctx) throw new Error('Canvas context failed')

      ctx.drawImage(img, 0, 0)
      const imageData = ctx.getImageData(0, 0, img.width, img.height)

      // Generate embedding using appropriate service
      if (samMode === 'server') {
        const { samBackendClient } = await import('@/services/sam')
        await samBackendClient.generateEmbedding(imageData)
      } else {
        const { samService } = await import('@/services/sam')
        await samService.generateEmbedding(imageData)
      }
      console.log('SAM embedding generated successfully')

      set({
        samEmbeddingLayerId: layerId,
        samPoints: [],
        isSAMSegmenting: false,
      })
    } catch (error) {
      console.error('Failed to generate SAM embedding:', error)
      set({ isSAMSegmenting: false })
      showToast('Bildanalyse fehlgeschlagen', 'error')
    }
  },

  segmentAtPoint: async (x, y, isPositive = true) => {
    const { currentProject } = useLayerStore.getState()
    const { showToast } = useCanvasStore.getState()
    const { samEmbeddingLayerId, samPoints, isSAMReady, samMode } = get()
    if (!currentProject || !isSAMReady || !samEmbeddingLayerId) return

    const layer = currentProject.layers.find((l) => l.id === samEmbeddingLayerId)
    if (!layer) return

    set({ isSAMSegmenting: true })

    // Transform coordinates from project space to native image pixel space
    // The layer may be displayed at a different size than the actual image
    const layerX = x - layer.x
    const layerY = y - layer.y

    // Scale from display coordinates to native image coordinates
    // We need native image dimensions — load image to get them
    let scaleX = 1, scaleY = 1
    if (layer.imageData) {
      try {
        const img = new Image()
        await new Promise<void>((resolve) => {
          img.onload = () => resolve()
          img.onerror = () => resolve() // fallback to 1:1
          img.src = layer.imageData!
        })
        if (img.width > 0 && img.height > 0) {
          scaleX = img.width / layer.width
          scaleY = img.height / layer.height
        }
      } catch { /* use 1:1 */ }
    }

    const nativeX = layerX * scaleX
    const nativeY = layerY * scaleY

    // Add the new point (in native image pixel coordinates)
    const newPoint = { x: nativeX, y: nativeY, label: (isPositive ? 1 : 0) as 0 | 1 }
    const updatedPoints = [...samPoints, newPoint]

    try {
      const { getMaskBoundingBox } = await import('@/services/sam/utils')

      // Segment with all accumulated points using appropriate service
      let mask: ImageData
      if (samMode === 'server') {
        const { samBackendClient } = await import('@/services/sam')
        mask = await samBackendClient.segment(updatedPoints)
      } else {
        const { samService } = await import('@/services/sam')
        mask = await samService.segment(updatedPoints)
      }

      // Get bounding box of the mask
      const bounds = getMaskBoundingBox(mask)
      if (!bounds) {
        set({ isSAMSegmenting: false })
        showToast('Kein Objekt erkannt', 'info')
        return
      }

      // Set the mask selection (offset by layer position)
      set({
        samPoints: updatedPoints,
        isSAMSegmenting: false,
      })

      useCanvasStore.getState().setSelection({
        type: 'mask',
        x: layer.x + bounds.x,
        y: layer.y + bounds.y,
        width: bounds.width,
        height: bounds.height,
        mask: mask,
        active: true,
      })
    } catch (error) {
      console.error('SAM segmentation failed:', error)
      set({ isSAMSegmenting: false })
      showToast('Segmentierung fehlgeschlagen', 'error')
    }
  },

  clearSAMPoints: async () => {
    const { samMode } = get()
    // Clear embedding from the appropriate SAM service
    try {
      if (samMode === 'server') {
        const { samBackendClient } = await import('@/services/sam')
        await samBackendClient.clearEmbedding()
      } else {
        const { samService } = await import('@/services/sam')
        samService.clearEmbedding()
      }
    } catch (e) {
      console.warn('Could not clear SAM embedding:', e)
    }

    set({
      samPoints: [],
      samEmbeddingLayerId: null,
    })

    useCanvasStore.getState().setSelection({ ...DEFAULT_SELECTION })
  },

  confirmSAMSelection: () => {
    // The mask selection is already applied; release the embedding lock so
    // subsequent canvas clicks return to normal layer selection/drag. Without
    // this, any click on the canvas stays routed to segmentAtPoint forever.
    set({
      samPoints: [],
      samEmbeddingLayerId: null,
    })
  },
}))
