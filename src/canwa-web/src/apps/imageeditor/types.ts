// Image Editor Types (Canwa v2)

// === Tool Types ===
export type Tool =
  | 'select'
  | 'move'
  | 'freeTransform'
  | 'text'
  | 'crop'
  | 'eyedropper'

// === Blend Modes ===
export type BlendMode =
  | 'normal'
  | 'multiply'
  | 'screen'
  | 'overlay'
  | 'darken'
  | 'lighten'
  | 'color-dodge'
  | 'color-burn'
  | 'hard-light'
  | 'soft-light'
  | 'difference'
  | 'exclusion'

// === Layer Types ===
export type LayerType = 'image' | 'text'

// === Text Effects ===
export interface TextShadow {
  enabled: boolean
  offsetX: number
  offsetY: number
  blur: number
  color: string
}

export interface TextOutline {
  enabled: boolean
  width: number
  color: string
}

export interface TextGlow {
  enabled: boolean
  color: string
  intensity: number
}

export interface TextEffects {
  shadow: TextShadow
  outline: TextOutline
  glow: TextGlow
  curve: number // -100 to 100 (bend amount)
}

export const DEFAULT_TEXT_EFFECTS: TextEffects = {
  shadow: { enabled: false, offsetX: 4, offsetY: 4, blur: 8, color: '#000000' },
  outline: { enabled: false, width: 2, color: '#000000' },
  glow: { enabled: false, color: '#ff00ff', intensity: 20 },
  curve: 0,
}

// === Layer Effects (for image layers) ===
export interface DropShadow {
  enabled: boolean
  offsetX: number
  offsetY: number
  blur: number
  spread: number
  color: string
  opacity: number
}

export interface InnerShadow {
  enabled: boolean
  offsetX: number
  offsetY: number
  blur: number
  color: string
  opacity: number
}

export interface OuterGlow {
  enabled: boolean
  blur: number
  spread: number
  color: string
  opacity: number
}

export interface InnerGlow {
  enabled: boolean
  blur: number
  color: string
  opacity: number
}

export interface LayerEffects {
  dropShadow: DropShadow
  innerShadow: InnerShadow
  outerGlow: OuterGlow
  innerGlow: InnerGlow
}

export const DEFAULT_LAYER_EFFECTS: LayerEffects = {
  dropShadow: { enabled: false, offsetX: 5, offsetY: 5, blur: 10, spread: 0, color: '#000000', opacity: 50 },
  innerShadow: { enabled: false, offsetX: 2, offsetY: 2, blur: 5, color: '#000000', opacity: 50 },
  outerGlow: { enabled: false, blur: 15, spread: 5, color: '#ffffff', opacity: 75 },
  innerGlow: { enabled: false, blur: 10, color: '#ffffff', opacity: 50 },
}

// === Core Interfaces ===

export interface Layer {
  id: string
  name: string
  type: LayerType
  visible: boolean
  locked: boolean
  opacity: number
  blendMode: BlendMode
  x: number
  y: number
  width: number
  height: number
  rotation: number
  // Image data as base64 data URL
  imageData?: string
  // For caching the canvas
  canvas?: HTMLCanvasElement
  // Text-specific
  text?: string
  fontFamily?: string
  fontSize?: number
  fontColor?: string
  fontWeight?: number
  textAlign?: 'left' | 'center' | 'right'
  textEffects?: TextEffects
  // Layer effects (shadows, glows for image layers)
  layerEffects?: LayerEffects
  // Per-layer filters
  filters?: Filters
}

export interface ImageProject {
  id: string
  name: string
  width: number
  height: number
  backgroundColor: string
  layers: Layer[]
  createdAt: number
  updatedAt: number
}

export interface Filters {
  brightness: number    // -100 to 100
  contrast: number      // -100 to 100
  saturation: number    // -100 to 100
  hue: number           // -180 to 180
  blur: number          // 0-20
  sharpen: number       // 0-100
  grayscale: boolean
  sepia: boolean
  invert: boolean
  // Extended filters
  noise: number         // 0-100
  pixelate: number      // 0-50 (block size)
  posterize: number     // 2-32 (levels)
  vignette: number      // 0-100
  emboss: boolean
  edgeDetect: boolean
  tintColor: string     // hex color for tint
  tintAmount: number    // 0-100
}

export interface Selection {
  type: 'rectangle' | 'ellipse' | 'freehand' | 'mask' | 'none'
  x: number
  y: number
  width: number
  height: number
  path?: { x: number; y: number }[]  // For freehand selection
  mask?: ImageData  // For AI object selection (SAM)
  active: boolean
}

export interface CropArea {
  x: number
  y: number
  width: number
  height: number
  active: boolean
}

// === History ===
export interface HistoryEntry {
  id: string
  name: string
  timestamp: number
  // Snapshot of layers (serialized)
  snapshot: string
}

// === Export Settings ===
export interface ExportSettings {
  format: 'png' | 'jpeg' | 'webp'
  quality: number  // 0-100 (for jpeg/webp)
  scale: number    // 0.5, 1, 2
  backgroundColor: string | 'transparent'
}

// === UI State ===
export type ViewMode = 'projects' | 'editor'

export interface Point {
  x: number
  y: number
}

export interface Rect {
  x: number
  y: number
  width: number
  height: number
}

// === Default Values ===

export const DEFAULT_FILTERS: Filters = {
  brightness: 0,
  contrast: 0,
  saturation: 0,
  hue: 0,
  blur: 0,
  sharpen: 0,
  grayscale: false,
  sepia: false,
  invert: false,
  noise: 0,
  pixelate: 0,
  posterize: 0,
  vignette: 0,
  emboss: false,
  edgeDetect: false,
  tintColor: '#ff0000',
  tintAmount: 0,
}

export const DEFAULT_SELECTION: Selection = {
  type: 'none',
  x: 0,
  y: 0,
  width: 0,
  height: 0,
  active: false,
}

export const DEFAULT_CROP: CropArea = {
  x: 0,
  y: 0,
  width: 0,
  height: 0,
  active: false,
}

// === Helper Functions ===
export function createLayer(
  id: string,
  name: string,
  type: LayerType,
  width: number,
  height: number
): Layer {
  return {
    id,
    name,
    type,
    visible: true,
    locked: false,
    opacity: 100,
    blendMode: 'normal',
    x: 0,
    y: 0,
    width,
    height,
    rotation: 0,
  }
}

export function createProject(id: string, name: string, width: number, height: number): ImageProject {
  return {
    id,
    name,
    width,
    height,
    backgroundColor: 'transparent',
    layers: [
      {
        ...createLayer('layer-bg', 'Background', 'image', width, height),
        locked: true,
      },
    ],
    createdAt: Date.now(),
    updatedAt: Date.now(),
  }
}

export function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}
