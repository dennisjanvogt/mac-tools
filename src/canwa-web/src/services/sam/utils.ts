/**
 * SAM Service Utilities
 *
 * Postprocessing functions for mask manipulation.
 */

/**
 * Get bounding box of mask selection
 */
export function getMaskBoundingBox(
  maskData: ImageData
): { x: number; y: number; width: number; height: number } | null {
  let minX = maskData.width
  let minY = maskData.height
  let maxX = 0
  let maxY = 0
  let hasSelection = false

  for (let y = 0; y < maskData.height; y++) {
    for (let x = 0; x < maskData.width; x++) {
      const idx = (y * maskData.width + x) * 4
      if (maskData.data[idx + 3] > 0) {
        hasSelection = true
        minX = Math.min(minX, x)
        minY = Math.min(minY, y)
        maxX = Math.max(maxX, x)
        maxY = Math.max(maxY, y)
      }
    }
  }

  if (!hasSelection) return null

  return {
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  }
}

/**
 * Convert mask ImageData to a binary mask array
 * Returns true for selected pixels, false for background
 */
export function maskToBinary(maskData: ImageData): boolean[] {
  const result: boolean[] = []
  for (let i = 0; i < maskData.data.length; i += 4) {
    // Check alpha channel for selection
    result.push(maskData.data[i + 3] > 0)
  }
  return result
}

/**
 * Apply mask to ImageData - returns only the masked pixels
 * Useful for copy/cut operations
 */
export function applyMaskToImage(
  imageData: ImageData,
  maskData: ImageData
): ImageData {
  const result = new ImageData(imageData.width, imageData.height)

  for (let i = 0; i < imageData.data.length; i += 4) {
    // Check if mask pixel is selected (has alpha)
    if (maskData.data[i + 3] > 0) {
      result.data[i] = imageData.data[i]
      result.data[i + 1] = imageData.data[i + 1]
      result.data[i + 2] = imageData.data[i + 2]
      result.data[i + 3] = imageData.data[i + 3]
    } else {
      // Transparent for non-selected pixels
      result.data[i] = 0
      result.data[i + 1] = 0
      result.data[i + 2] = 0
      result.data[i + 3] = 0
    }
  }

  return result
}
