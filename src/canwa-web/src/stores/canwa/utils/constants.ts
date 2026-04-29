export const AUTO_SAVE_DELAY = 2000
export const MAX_HISTORY_SIZE = 50

// Template categories
export type TemplateCategory = 'all' | 'instagram' | 'youtube' | 'facebook' | 'twitter' | 'linkedin' | 'tiktok' | 'print' | 'other'

export interface ProjectPreset {
  name: string
  width: number
  height: number
  category: TemplateCategory
}

export const TEMPLATE_CATEGORIES: { id: TemplateCategory; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'instagram', label: 'Instagram' },
  { id: 'youtube', label: 'YouTube' },
  { id: 'facebook', label: 'Facebook' },
  { id: 'twitter', label: 'X / Twitter' },
  { id: 'linkedin', label: 'LinkedIn' },
  { id: 'tiktok', label: 'TikTok' },
  { id: 'print', label: 'Print' },
  { id: 'other', label: 'Other' },
]

// Project size presets — categorized by platform
export const PROJECT_PRESETS: ProjectPreset[] = [
  // Instagram
  { name: 'Post', width: 1080, height: 1080, category: 'instagram' },
  { name: 'Story / Reel', width: 1080, height: 1920, category: 'instagram' },
  { name: 'Landscape Post', width: 1080, height: 566, category: 'instagram' },
  { name: 'Portrait Post', width: 1080, height: 1350, category: 'instagram' },
  { name: 'Profile Picture', width: 320, height: 320, category: 'instagram' },

  // YouTube
  { name: 'Thumbnail', width: 1280, height: 720, category: 'youtube' },
  { name: 'Channel Banner', width: 2560, height: 1440, category: 'youtube' },
  { name: 'Profile Picture', width: 800, height: 800, category: 'youtube' },
  { name: 'Video (1080p)', width: 1920, height: 1080, category: 'youtube' },
  { name: 'Shorts', width: 1080, height: 1920, category: 'youtube' },
  { name: 'End Screen', width: 1920, height: 1080, category: 'youtube' },

  // Facebook
  { name: 'Post', width: 1200, height: 630, category: 'facebook' },
  { name: 'Cover Photo', width: 820, height: 312, category: 'facebook' },
  { name: 'Story', width: 1080, height: 1920, category: 'facebook' },
  { name: 'Profile Picture', width: 170, height: 170, category: 'facebook' },
  { name: 'Event Cover', width: 1920, height: 1080, category: 'facebook' },
  { name: 'Ad (Landscape)', width: 1200, height: 628, category: 'facebook' },

  // X / Twitter
  { name: 'Post', width: 1200, height: 675, category: 'twitter' },
  { name: 'Header', width: 1500, height: 500, category: 'twitter' },
  { name: 'Profile Picture', width: 400, height: 400, category: 'twitter' },
  { name: 'In-Stream Photo', width: 1600, height: 900, category: 'twitter' },

  // LinkedIn
  { name: 'Post', width: 1200, height: 627, category: 'linkedin' },
  { name: 'Cover Photo', width: 1584, height: 396, category: 'linkedin' },
  { name: 'Profile Picture', width: 400, height: 400, category: 'linkedin' },
  { name: 'Company Banner', width: 1128, height: 191, category: 'linkedin' },
  { name: 'Article Cover', width: 1200, height: 644, category: 'linkedin' },

  // TikTok
  { name: 'Video', width: 1080, height: 1920, category: 'tiktok' },
  { name: 'Profile Picture', width: 200, height: 200, category: 'tiktok' },

  // Print
  { name: 'A4 Portrait', width: 2480, height: 3508, category: 'print' },
  { name: 'A4 Landscape', width: 3508, height: 2480, category: 'print' },
  { name: 'A3 Portrait', width: 3508, height: 4961, category: 'print' },
  { name: 'Letter', width: 2550, height: 3300, category: 'print' },
  { name: 'Business Card', width: 1050, height: 600, category: 'print' },
  { name: 'Poster (18×24)', width: 5400, height: 7200, category: 'print' },
  { name: 'Flyer (A5)', width: 1748, height: 2480, category: 'print' },

  // Other
  { name: 'Square', width: 1000, height: 1000, category: 'other' },
  { name: 'HD Wallpaper', width: 1920, height: 1080, category: 'other' },
  { name: '4K Wallpaper', width: 3840, height: 2160, category: 'other' },
  { name: 'Phone Wallpaper', width: 1080, height: 2340, category: 'other' },
  { name: 'Banner', width: 1920, height: 480, category: 'other' },
  { name: 'Logo', width: 500, height: 500, category: 'other' },
  { name: 'Favicon', width: 512, height: 512, category: 'other' },
  { name: 'Open Graph', width: 1200, height: 630, category: 'other' },
]

// Preset gradients for AI/Magic panel
export const PRESET_GRADIENTS = [
  { name: 'Sunset', startColor: '#ff512f', endColor: '#dd2476', type: 'linear' as const, angle: 135 },
  { name: 'Ocean', startColor: '#2193b0', endColor: '#6dd5ed', type: 'linear' as const, angle: 90 },
  { name: 'Forest', startColor: '#134e5e', endColor: '#71b280', type: 'linear' as const, angle: 180 },
  { name: 'Purple', startColor: '#7f00ff', endColor: '#e100ff', type: 'linear' as const, angle: 45 },
  { name: 'Peach', startColor: '#ffecd2', endColor: '#fcb69f', type: 'linear' as const, angle: 90 },
  { name: 'Night', startColor: '#0f0c29', endColor: '#302b63', type: 'linear' as const, angle: 180 },
  { name: 'Mint', startColor: '#00b09b', endColor: '#96c93d', type: 'linear' as const, angle: 135 },
  { name: 'Fire', startColor: '#f12711', endColor: '#f5af19', type: 'linear' as const, angle: 45 },
  { name: 'Cool', startColor: '#2980b9', endColor: '#6dd5fa', type: 'radial' as const },
  { name: 'Warm', startColor: '#f5af19', endColor: '#f12711', type: 'radial' as const },
  { name: 'Galaxy', startColor: '#0f0c29', endColor: '#24243e', type: 'radial' as const },
  { name: 'Rose', startColor: '#ee9ca7', endColor: '#ffdde1', type: 'radial' as const },
]

// Preset patterns
export const PRESET_PATTERNS = [
  { name: 'Stripes', type: 'stripes', colors: ['#333333', '#666666'] },
  { name: 'Candy', type: 'stripes', colors: ['#ff6b6b', '#ffffff'] },
  { name: 'Dots', type: 'dots', colors: ['#ffffff', '#333333'] },
  { name: 'Grid', type: 'grid', colors: ['#ffffff', '#cccccc'] },
  { name: 'Checkerboard', type: 'checkerboard', colors: ['#000000', '#ffffff'] },
  { name: 'Waves', type: 'waves', colors: ['#2193b0', '#6dd5ed'] },
]

// Filter presets
export const FILTER_PRESETS = [
  { name: 'Original', filters: {} },
  { name: 'B&W', filters: { grayscale: true } },
  { name: 'Sepia', filters: { sepia: true } },
  { name: 'Vivid', filters: { saturation: 40, contrast: 20 } },
  { name: 'Cool', filters: { hue: -30, saturation: -10 } },
  { name: 'Warm', filters: { hue: 15, saturation: 10 } },
  { name: 'Dramatic', filters: { contrast: 40, saturation: -20, brightness: -10 } },
]

// AI filter types
export const AI_FILTER_TYPES = [
  'vintage', 'cinematic', 'hdr', 'noir', 'dreamy',
  'pop', 'cool', 'warm', 'fade', 'dramatic',
] as const
