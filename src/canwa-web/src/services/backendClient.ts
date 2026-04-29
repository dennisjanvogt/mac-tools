/**
 * SAM Backend Client
 *
 * Interfaces with Django backend for server-side SAM processing.
 * The backend handles the heavy embedding computation, while this client
 * only sends coordinates for fast mask generation.
 */

import { api } from '@/api/client'
import type { SAMPoint, SAMConfig } from './index'

interface SAMEmbedResponse {
  session_id: string
  status: string
  width: number
  height: number
}

interface SAMSegmentResponse {
  mask: string // Base64 PNG
  score: number
}

interface SAMStatusResponse {
  available: boolean
  model_loaded: boolean
  active_sessions: number
}

class SAMBackendClient {
  private sessionId: string | null = null
  private embeddingImageSize: { width: number; height: number } | null = null
  private isGeneratingEmbedding = false

  /**
   * Check if backend SAM service is available
   */
  async checkStatus(): Promise<SAMStatusResponse> {
    return api.get<SAMStatusResponse>('/imageeditor/sam/status')
  }

  /**
   * Check if we have a valid embedding session
   */
  get hasEmbedding(): boolean {
    return this.sessionId !== null
  }

  /**
   * Check if embedding is being generated
   */
  get loading(): boolean {
    return this.isGeneratingEmbedding
  }

  /**
   * Generate embedding for an image on the server
   *
   * @param imageData - ImageData from canvas
   * @param config - Optional progress callback
   */
  async generateEmbedding(imageData: ImageData, config?: SAMConfig): Promise<void> {
    this.isGeneratingEmbedding = true
    config?.onProgress?.(0, 'Uploading image to server...')

    try {
      // Convert ImageData to base64 PNG
      const base64Image = this.imageDataToBase64(imageData)

      config?.onProgress?.(30, 'Generating embedding on server...')

      const response = await api.post<SAMEmbedResponse>('/imageeditor/sam/embed', {
        image: base64Image,
      })

      this.sessionId = response.session_id
      this.embeddingImageSize = {
        width: response.width,
        height: response.height,
      }

      config?.onProgress?.(100, 'Embedding ready')
      console.log('SAM embedding generated on server:', response)
    } finally {
      this.isGeneratingEmbedding = false
    }
  }

  /**
   * Segment image based on click points
   *
   * @param points - Array of click points with labels
   * @returns ImageData mask
   */
  async segment(points: SAMPoint[]): Promise<ImageData> {
    if (!this.sessionId || !this.embeddingImageSize) {
      throw new Error('No embedding session. Call generateEmbedding first.')
    }

    if (points.length === 0) {
      throw new Error('At least one point is required for segmentation.')
    }

    console.log('Requesting mask from server with points:', points)

    const response = await api.post<SAMSegmentResponse>('/imageeditor/sam/segment', {
      session_id: this.sessionId,
      points: points.map(p => ({
        x: Math.round(p.x),
        y: Math.round(p.y),
        label: p.label,
      })),
    })

    console.log('Mask received from server, score:', response.score)

    // Convert base64 PNG to ImageData
    return this.base64ToImageData(response.mask, this.embeddingImageSize.width, this.embeddingImageSize.height)
  }

  /**
   * Clear the embedding session on the server
   */
  async clearEmbedding(): Promise<void> {
    if (this.sessionId) {
      try {
        await api.delete(`/imageeditor/sam/session/${this.sessionId}`)
      } catch (e) {
        // Ignore errors when clearing
        console.warn('Failed to clear SAM session:', e)
      }
      this.sessionId = null
      this.embeddingImageSize = null
    }
  }

  /**
   * Convert ImageData to base64 PNG string
   */
  private imageDataToBase64(imageData: ImageData): string {
    const canvas = document.createElement('canvas')
    canvas.width = imageData.width
    canvas.height = imageData.height

    const ctx = canvas.getContext('2d')!
    ctx.putImageData(imageData, 0, 0)

    return canvas.toDataURL('image/png')
  }

  /**
   * Convert base64 PNG to ImageData
   */
  private async base64ToImageData(base64: string, width: number, height: number): Promise<ImageData> {
    return new Promise((resolve, reject) => {
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement('canvas')
        canvas.width = width
        canvas.height = height

        const ctx = canvas.getContext('2d')!
        ctx.drawImage(img, 0, 0, width, height)

        resolve(ctx.getImageData(0, 0, width, height))
      }
      img.onerror = reject
      img.src = `data:image/png;base64,${base64}`
    })
  }
}

// Export singleton instance
export const samBackendClient = new SAMBackendClient()
