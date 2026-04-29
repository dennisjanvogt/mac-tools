/**
 * SAM (Segment Anything Model) Service
 *
 * Provides AI-powered object selection using SlimSAM via @huggingface/transformers.
 * The user clicks on an object and it gets automatically segmented.
 */

import { SamModel, AutoProcessor, RawImage, env } from '@huggingface/transformers'

// Use Hugging Face CDN (default) for model downloads
// Models are cached in the browser after first download (~15MB)
env.allowLocalModels = false
env.useBrowserCache = true

export interface SAMPoint {
  x: number
  y: number
  label: 0 | 1 // 0 = background (exclude), 1 = foreground (include)
}

export interface SAMConfig {
  onProgress?: (progress: number, message: string) => void
}

class SAMService {
  private model: SamModel | null = null
  private processor: AutoProcessor | null = null
  private imageEmbeddings: Awaited<ReturnType<SamModel['get_image_embeddings']>> | null = null
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private processedInputs: any = null // Stores original_sizes, reshaped_input_sizes from processor
  private embeddingImageSize: { width: number; height: number } | null = null
  private isLoading = false
  private isReady = false

  /**
   * Check if models are loaded and ready
   */
  get ready(): boolean {
    return this.isReady && this.model !== null
  }

  /**
   * Check if models are currently loading
   */
  get loading(): boolean {
    return this.isLoading
  }

  /**
   * Check if an embedding is cached for the current image
   */
  get hasEmbedding(): boolean {
    return this.imageEmbeddings !== null
  }

  /**
   * Load the SlimSAM model (~5.5MB)
   */
  async loadModels(config?: SAMConfig): Promise<void> {
    if (this.isReady) return
    if (this.isLoading) {
      // Wait for existing load to complete
      while (this.isLoading) {
        await new Promise(resolve => setTimeout(resolve, 100))
      }
      return
    }

    this.isLoading = true
    config?.onProgress?.(0, 'Initializing SAM...')

    try {
      config?.onProgress?.(10, 'Loading SAM model...')

      // Use SlimSAM - smallest SAM variant (~14MB total)
      // Model is served from backend via env.remoteHost configuration
      // @ts-expect-error - transformers.js types are incomplete
      this.model = await SamModel.from_pretrained('Xenova/slimsam-50-uniform', {
        progress_callback: (progress: { status: string; progress?: number; loaded?: number; total?: number }) => {
          if (progress.status === 'progress' && progress.progress !== undefined) {
            const pct = Math.round(10 + progress.progress * 0.8) // 10-90%
            config?.onProgress?.(pct, `Loading model: ${Math.round(progress.progress)}%`)
          } else if (progress.status === 'ready') {
            config?.onProgress?.(90, 'Model loaded')
          }
        }
      })

      config?.onProgress?.(90, 'Loading processor...')

      this.processor = await AutoProcessor.from_pretrained('Xenova/slimsam-50-uniform')

      config?.onProgress?.(100, 'Models loaded successfully')
      this.isReady = true
    } catch (error) {
      console.error('Failed to load SAM models:', error)
      this.model = null
      this.processor = null
      throw new Error(`Failed to load SAM models: ${error instanceof Error ? error.message : 'Unknown error'}`)
    } finally {
      this.isLoading = false
    }
  }

  /**
   * Generate image embedding for click-based segmentation
   * This is cached and only needs to be regenerated when the image changes
   */
  async generateEmbedding(imageData: ImageData): Promise<void> {
    if (!this.model || !this.processor) {
      throw new Error('SAM model not loaded. Call loadModels() first.')
    }

    // Store original image dimensions for coordinate transformation
    this.embeddingImageSize = {
      width: imageData.width,
      height: imageData.height,
    }

    // Convert ImageData to RawImage format for transformers.js
    const rawImage = new RawImage(
      new Uint8ClampedArray(imageData.data),
      imageData.width,
      imageData.height,
      4 // RGBA channels
    )

    console.log('Generating SAM embeddings for image:', imageData.width, 'x', imageData.height)

    // Process image through processor to get pixel_values tensor
    // @ts-expect-error - transformers.js processor is callable but types don't reflect it
    this.processedInputs = await this.processor(rawImage)

    // Generate embeddings from processed inputs
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    this.imageEmbeddings = await (this.model as any).get_image_embeddings(this.processedInputs)

    console.log('SAM embeddings generated')
  }

  /**
   * Clear the cached embedding (call when image changes)
   */
  clearEmbedding(): void {
    this.imageEmbeddings = null
    this.processedInputs = null
    this.embeddingImageSize = null
  }

  /**
   * Segment the image based on click points
   * @param points Array of click points with labels (1 = include, 0 = exclude)
   * @returns Mask as ImageData
   */
  async segment(points: SAMPoint[]): Promise<ImageData> {
    if (!this.model || !this.processor) {
      throw new Error('SAM model not loaded. Call loadModels() first.')
    }
    if (!this.imageEmbeddings || !this.embeddingImageSize) {
      throw new Error('No embedding available. Call generateEmbedding() first.')
    }
    if (points.length === 0) {
      throw new Error('At least one point is required for segmentation.')
    }

    // Build points as nested JS arrays for the processor
    // Format: [point_batch=1, num_points, 2] — processor auto-wraps to 4D
    const pointsArray = points.map(p => [p.x, p.y])
    const labelsArray = points.map(p => p.label)

    // Use processor to scale coordinates from original image space → processor-resized space
    // This accounts for the resize the processor applied to the image
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const proc = this.processor as any
    const input_points = proc.reshape_input_points(
      [[pointsArray]],
      this.processedInputs.original_sizes,
      this.processedInputs.reshaped_input_sizes,
    )
    const input_labels = proc.image_processor.add_input_labels(
      [[labelsArray]],
      input_points,
    )

    console.log('Running SAM decoder with points:', points, 'scaled dims:', input_points.dims)

    // Run decoder
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const result = await (this.model as any)({
      ...this.imageEmbeddings,
      input_points,
      input_labels,
    })

    const { pred_masks, iou_scores } = result

    console.log('SAM decoder output - mask dims:', pred_masks.dims, 'iou scores:', iou_scores?.data)

    // Post-process masks: upscale → crop padding → downscale to original image size
    // This correctly handles the asymmetric padding the processor applied
    const postProcessed = await proc.post_process_masks(
      pred_masks,
      this.processedInputs.original_sizes,
      this.processedInputs.reshaped_input_sizes,
      { binarize: false },
    )

    // postProcessed[0] = batch 0, shape: [num_groups, num_masks, origH, origW]
    const processed = postProcessed[0]
    const dims = processed.dims
    const maskData = processed.data as Float32Array

    console.log('Post-processed mask dims:', dims)

    // Determine mask layout and pick best mask by IoU score
    // Dims are typically [1, 3, origH, origW] — 1 group, 3 candidate masks
    const numMasks = dims.length === 4 ? (dims[1] as number) : (dims[0] as number)
    const height = dims[dims.length - 2] as number
    const width = dims[dims.length - 1] as number
    const pixelsPerMask = height * width

    let bestIdx = 0
    if (iou_scores?.data && numMasks > 1) {
      const scores = iou_scores.data as Float32Array
      let bestScore = -Infinity
      for (let m = 0; m < numMasks; m++) {
        if (scores[m] > bestScore) { bestScore = scores[m]; bestIdx = m }
      }
    }

    console.log(`Best mask: ${bestIdx}/${numMasks}, size: ${width}x${height}`)

    const bestOffset = bestIdx * pixelsPerMask

    // Convert logits → RGBA ImageData (sigmoid > 0.5 = foreground)
    const outputData = new Uint8ClampedArray(width * height * 4)
    for (let i = 0; i < pixelsPerMask; i++) {
      const logit = maskData[bestOffset + i]
      if (logit > 0) { // logit > 0 ≡ sigmoid > 0.5
        outputData[i * 4] = 99      // R (violet)
        outputData[i * 4 + 1] = 39  // G
        outputData[i * 4 + 2] = 255 // B
        outputData[i * 4 + 3] = 180 // A (more opaque for visibility)
      }
    }

    // Mask is already at original image dimensions — no resize needed
    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height
    const ctx = canvas.getContext('2d')!
    const imgData = ctx.createImageData(width, height)
    imgData.data.set(outputData)
    return imgData
  }

  /**
   * Dispose of models and free memory
   */
  async dispose(): Promise<void> {
    // transformers.js models don't have explicit dispose, just null references
    this.model = null
    this.processor = null
    this.imageEmbeddings = null
    this.processedInputs = null
    this.embeddingImageSize = null
    this.isReady = false
  }
}

// Export singleton instance for browser-based inference
export const samService = new SAMService()

// Re-export backend client
export { samBackendClient } from './backendClient'

// Export a unified interface that switches between browser and server
export type SAMMode = 'browser' | 'server'

/**
 * Creates a SAM client that uses either browser or server inference
 */
export function getSAMClient(mode: SAMMode) {
  if (mode === 'server') {
    // Dynamic import to avoid loading backend client if not needed
    return import('./backendClient').then(m => m.samBackendClient)
  }
  return Promise.resolve(samService)
}
