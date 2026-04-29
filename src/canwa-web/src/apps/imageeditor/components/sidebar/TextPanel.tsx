import { useState, useMemo, useRef, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { Type, Plus, Search, Heading1, Heading2, AlignLeft, Sparkles, CircleDot, ChevronDown, Check } from 'lucide-react'
import { useLayerStore } from '@/stores/canwa'
import { generateId, DEFAULT_TEXT_EFFECTS } from '@/apps/imageeditor/types'
import type { Layer, TextEffects } from '@/apps/imageeditor/types'

// ---------- Text Template Type ----------
interface TextTemplate {
  id: string
  category: 'headline' | 'subheading' | 'body' | 'effect' | 'decorative'
  preview: string
  text: string
  fontSize: number
  fontFamily: string
  fontWeight: number
  fontColor: string
  effects: TextEffects
}

// ---------- All 54 Templates ----------
const TEXT_TEMPLATES: TextTemplate[] = [
  // === Headlines (3) ===
  {
    id: 'headline-1',
    category: 'headline',
    preview: 'Add a heading',
    text: 'Add a heading',
    fontSize: 64,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'headline-2',
    category: 'headline',
    preview: 'BOLD TITLE',
    text: 'BOLD TITLE',
    fontSize: 72,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 3, color: '#000000' } },
  },
  {
    id: 'headline-3',
    category: 'headline',
    preview: 'Elegant Header',
    text: 'Elegant Header',
    fontSize: 56,
    fontFamily: 'Georgia',
    fontWeight: 400,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },

  // === Subheadings (2) ===
  {
    id: 'subhead-1',
    category: 'subheading',
    preview: 'Add a subheading',
    text: 'Add a subheading',
    fontSize: 32,
    fontFamily: 'Arial',
    fontWeight: 400,
    fontColor: '#cccccc',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'subhead-2',
    category: 'subheading',
    preview: 'Subtitle Text',
    text: 'Subtitle Text',
    fontSize: 28,
    fontFamily: 'Helvetica',
    fontWeight: 300,
    fontColor: '#aaaaaa',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },

  // === Body (2) ===
  {
    id: 'body-1',
    category: 'body',
    preview: 'Add body text',
    text: 'Add a little bit of body text',
    fontSize: 18,
    fontFamily: 'Arial',
    fontWeight: 400,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'body-2',
    category: 'body',
    preview: 'Paragraph text',
    text: 'This is a paragraph of text that you can edit.',
    fontSize: 16,
    fontFamily: 'Georgia',
    fontWeight: 400,
    fontColor: '#dddddd',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },

  // === Effect (39) ===
  {
    id: 'effect-neon-glow',
    category: 'effect',
    preview: 'NEON GLOW',
    text: 'NEON GLOW',
    fontSize: 48,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#ff00ff',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#ff00ff', intensity: 30 } },
  },
  {
    id: 'effect-shadow-text',
    category: 'effect',
    preview: 'Drop Shadow',
    text: 'Drop Shadow',
    fontSize: 48,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 4, offsetY: 4, blur: 8, color: '#000000' } },
  },
  {
    id: 'effect-outline-only',
    category: 'effect',
    preview: 'OUTLINED',
    text: 'OUTLINED',
    fontSize: 52,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#000000',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 4, color: '#ffffff' } },
  },
  {
    id: 'effect-retro',
    category: 'effect',
    preview: 'RETRO',
    text: 'RETRO',
    fontSize: 60,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#ffcc00',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 6, offsetY: 6, blur: 0, color: '#ff6600' } },
  },
  {
    id: 'effect-gradient-look',
    category: 'effect',
    preview: 'Modern',
    text: 'Modern',
    fontSize: 54,
    fontFamily: 'Helvetica',
    fontWeight: 700,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 0, offsetY: 8, blur: 20, color: 'rgba(100,100,255,0.5)' } },
  },
  {
    id: 'effect-stamp',
    category: 'effect',
    preview: 'STAMP',
    text: 'STAMP',
    fontSize: 56,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#cc0000',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 4, color: '#cc0000' } },
  },
  {
    id: 'effect-vintage',
    category: 'effect',
    preview: 'VINTAGE',
    text: 'VINTAGE',
    fontSize: 60,
    fontFamily: 'Copperplate',
    fontWeight: 400,
    fontColor: '#8b4513',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 2, color: '#d2691e' } },
  },
  {
    id: 'effect-sticker',
    category: 'effect',
    preview: 'STICKER',
    text: 'STICKER',
    fontSize: 52,
    fontFamily: 'Arial Black',
    fontWeight: 900,
    fontColor: '#ff6b6b',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 5, color: '#ffffff' }, shadow: { enabled: true, offsetX: 3, offsetY: 3, blur: 0, color: '#333333' } },
  },
  {
    id: 'effect-grunge',
    category: 'effect',
    preview: 'GRUNGE',
    text: 'GRUNGE',
    fontSize: 68,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#4a4a4a',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 3, color: '#1a1a1a' }, shadow: { enabled: true, offsetX: 3, offsetY: 3, blur: 0, color: '#666666' } },
  },
  {
    id: 'effect-chalk',
    category: 'effect',
    preview: 'CHALK',
    text: 'CHALK',
    fontSize: 56,
    fontFamily: 'Comic Sans MS',
    fontWeight: 700,
    fontColor: '#f5f5dc',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 1, color: '#d3d3d3' } },
  },
  {
    id: 'effect-emboss',
    category: 'effect',
    preview: 'PREMIUM',
    text: 'PREMIUM',
    fontSize: 56,
    fontFamily: 'Georgia',
    fontWeight: 700,
    fontColor: '#d4a574',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 2, offsetY: 2, blur: 0, color: '#8b6914' }, outline: { enabled: true, width: 1, color: '#ffe4b5' } },
  },
  {
    id: 'effect-watercolor',
    category: 'effect',
    preview: 'Watercolor',
    text: 'Watercolor',
    fontSize: 52,
    fontFamily: 'Brush Script MT',
    fontWeight: 400,
    fontColor: '#87ceeb',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#add8e6', intensity: 15 } },
  },
  {
    id: 'effect-comic',
    category: 'effect',
    preview: 'POW!',
    text: 'POW!',
    fontSize: 80,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#ffff00',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 4, color: '#ff0000' }, shadow: { enabled: true, offsetX: 5, offsetY: 5, blur: 0, color: '#000000' } },
  },
  {
    id: 'effect-minimalist',
    category: 'effect',
    preview: 'Minimalist',
    text: 'Minimalist',
    fontSize: 48,
    fontFamily: 'Helvetica',
    fontWeight: 300,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'effect-glitch',
    category: 'effect',
    preview: 'GLITCH',
    text: 'GLITCH',
    fontSize: 56,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#00ffff',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: -4, offsetY: 2, blur: 0, color: '#ff0000' }, outline: { enabled: true, width: 1, color: '#ff00ff' } },
  },
  {
    id: 'effect-fire',
    category: 'effect',
    preview: 'FIRE',
    text: 'FIRE',
    fontSize: 72,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#ff6600',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#ff3300', intensity: 35 }, shadow: { enabled: true, offsetX: 0, offsetY: 4, blur: 15, color: '#ff0000' } },
  },
  {
    id: 'effect-ice',
    category: 'effect',
    preview: 'FROZEN',
    text: 'FROZEN',
    fontSize: 64,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#b3e0ff',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#66ccff', intensity: 25 }, outline: { enabled: true, width: 2, color: '#ffffff' } },
  },
  {
    id: 'effect-golden',
    category: 'effect',
    preview: 'LUXURY',
    text: 'LUXURY',
    fontSize: 64,
    fontFamily: 'Georgia',
    fontWeight: 700,
    fontColor: '#ffd700',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 2, offsetY: 2, blur: 4, color: 'rgba(0,0,0,0.5)' } },
  },
  {
    id: 'effect-3d',
    category: 'effect',
    preview: '3D POP',
    text: '3D POP',
    fontSize: 66,
    fontFamily: 'Arial Black',
    fontWeight: 900,
    fontColor: '#ff6b6b',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 6, offsetY: 6, blur: 0, color: '#c44569' }, outline: { enabled: true, width: 2, color: '#ffffff' } },
  },
  {
    id: 'effect-cyberpunk',
    category: 'effect',
    preview: 'CYBER',
    text: 'CYBER',
    fontSize: 56,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#00ffff',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#00ffff', intensity: 25 }, outline: { enabled: true, width: 2, color: '#003333' } },
  },
  {
    id: 'effect-terminal',
    category: 'effect',
    preview: '> terminal_',
    text: '> terminal_',
    fontSize: 36,
    fontFamily: 'Courier New',
    fontWeight: 400,
    fontColor: '#39ff14',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#39ff14', intensity: 15 } },
  },
  {
    id: 'effect-handwritten',
    category: 'effect',
    preview: 'Handwritten Note',
    text: 'Handwritten Note',
    fontSize: 40,
    fontFamily: 'Brush Script MT',
    fontWeight: 400,
    fontColor: '#1a1a80',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'effect-brush-script',
    category: 'effect',
    preview: 'Forever & Always',
    text: 'Forever & Always',
    fontSize: 48,
    fontFamily: 'Brush Script MT',
    fontWeight: 400,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'effect-art-deco',
    category: 'effect',
    preview: 'ART DECO',
    text: 'ART DECO',
    fontSize: 56,
    fontFamily: 'Copperplate',
    fontWeight: 700,
    fontColor: '#c9b037',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 3, color: '#1a1a1a' } },
  },
  {
    id: 'effect-japanese',
    category: 'effect',
    preview: 'SAKURA',
    text: 'SAKURA',
    fontSize: 52,
    fontFamily: 'Georgia',
    fontWeight: 400,
    fontColor: '#ffb7c5',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#ff69b4', intensity: 15 } },
  },
  {
    id: 'effect-bubble',
    category: 'effect',
    preview: 'BUBBLE',
    text: 'BUBBLE',
    fontSize: 58,
    fontFamily: 'Comic Sans MS',
    fontWeight: 700,
    fontColor: '#4fc3f7',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 4, color: '#ffffff' }, shadow: { enabled: true, offsetX: 3, offsetY: 3, blur: 6, color: '#0277bd' } },
  },
  {
    id: 'effect-pixel',
    category: 'effect',
    preview: 'PIXEL',
    text: 'PIXEL',
    fontSize: 48,
    fontFamily: 'Courier New',
    fontWeight: 700,
    fontColor: '#00ff00',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 2, color: '#003300' } },
  },
  {
    id: 'effect-rainbow',
    category: 'effect',
    preview: 'RAINBOW',
    text: 'RAINBOW',
    fontSize: 54,
    fontFamily: 'Arial Black',
    fontWeight: 900,
    fontColor: '#ff6b6b',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#ff6b6b', intensity: 20 }, outline: { enabled: true, width: 2, color: '#ffcc00' } },
  },
  {
    id: 'effect-metallic',
    category: 'effect',
    preview: 'CHROME',
    text: 'CHROME',
    fontSize: 62,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#c0c0c0',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 2, color: '#808080' }, shadow: { enabled: true, offsetX: 2, offsetY: 2, blur: 4, color: '#404040' } },
  },
  {
    id: 'effect-wood',
    category: 'effect',
    preview: 'RUSTIC',
    text: 'RUSTIC',
    fontSize: 56,
    fontFamily: 'Georgia',
    fontWeight: 700,
    fontColor: '#8b4513',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 3, offsetY: 3, blur: 6, color: '#3e1f00' } },
  },
  {
    id: 'effect-marble',
    category: 'effect',
    preview: 'MARBLE',
    text: 'MARBLE',
    fontSize: 58,
    fontFamily: 'Georgia',
    fontWeight: 400,
    fontColor: '#e8e0d8',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 2, offsetY: 2, blur: 8, color: '#6b5b4f' } },
  },
  {
    id: 'effect-underwater',
    category: 'effect',
    preview: 'DEEP SEA',
    text: 'DEEP SEA',
    fontSize: 54,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#006994',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#00ced1', intensity: 20 }, shadow: { enabled: true, offsetX: 0, offsetY: 4, blur: 12, color: '#001a33' } },
  },
  {
    id: 'effect-neon-outline',
    category: 'effect',
    preview: 'PARTY',
    text: 'PARTY',
    fontSize: 60,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#ff1493',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#ff1493', intensity: 40 } },
  },
  {
    id: 'effect-double-shadow',
    category: 'effect',
    preview: 'GAME ON',
    text: 'GAME ON',
    fontSize: 56,
    fontFamily: 'Arial Black',
    fontWeight: 900,
    fontColor: '#9400d3',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#9400d3', intensity: 30 }, outline: { enabled: true, width: 2, color: '#00ff00' } },
  },
  {
    id: 'effect-long-shadow',
    category: 'effect',
    preview: 'CHAMPIONS',
    text: 'CHAMPIONS',
    fontSize: 58,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#ffd700',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 3, color: '#000080' } },
  },
  {
    id: 'effect-retro-wave',
    category: 'effect',
    preview: 'SUNSET',
    text: 'SUNSET',
    fontSize: 60,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: '#ff7f50',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#ff4500', intensity: 20 } },
  },
  {
    id: 'effect-holographic',
    category: 'effect',
    preview: 'GLASS',
    text: 'GLASS',
    fontSize: 58,
    fontFamily: 'Helvetica',
    fontWeight: 300,
    fontColor: 'rgba(255,255,255,0.8)',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 1, color: 'rgba(255,255,255,0.4)' } },
  },
  {
    id: 'effect-paper-cutout',
    category: 'effect',
    preview: 'STENCIL',
    text: 'STENCIL',
    fontSize: 60,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#2d5016',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 2, color: '#1a1a1a' } },
  },
  {
    id: 'effect-engraved',
    category: 'effect',
    preview: 'Royal',
    text: 'Royal',
    fontSize: 54,
    fontFamily: 'Palatino Linotype',
    fontWeight: 700,
    fontColor: '#4169e1',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#4169e1', intensity: 15 } },
  },
  {
    id: 'effect-smoke',
    category: 'effect',
    preview: 'HORROR',
    text: 'HORROR',
    fontSize: 64,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#8b0000',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 0, offsetY: 0, blur: 20, color: '#ff0000' } },
  },

  // === Decorative (10) ===
  {
    id: 'deco-social-quote',
    category: 'decorative',
    preview: '"Quoted text"',
    text: '"The only way to do great work is to love what you do."',
    fontSize: 20,
    fontFamily: 'Georgia',
    fontWeight: 400,
    fontColor: '#cccccc',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'deco-call-to-action',
    category: 'decorative',
    preview: 'MEGA SALE',
    text: 'MEGA SALE',
    fontSize: 68,
    fontFamily: 'Impact',
    fontWeight: 400,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 4, offsetY: 4, blur: 0, color: '#ff0000' }, outline: { enabled: true, width: 3, color: '#ff0000' } },
  },
  {
    id: 'deco-caption',
    category: 'decorative',
    preview: 'Small caption',
    text: 'Small caption text for images and details',
    fontSize: 12,
    fontFamily: 'Arial',
    fontWeight: 400,
    fontColor: '#888888',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'deco-watermark',
    category: 'decorative',
    preview: 'DRAFT',
    text: 'DRAFT',
    fontSize: 72,
    fontFamily: 'Arial',
    fontWeight: 700,
    fontColor: 'rgba(255,255,255,0.15)',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 2, color: 'rgba(255,255,255,0.1)' } },
  },
  {
    id: 'deco-logo-text',
    category: 'decorative',
    preview: 'BRAND',
    text: 'BRAND',
    fontSize: 48,
    fontFamily: 'Helvetica',
    fontWeight: 700,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS },
  },
  {
    id: 'deco-title-card',
    category: 'decorative',
    preview: 'The Grand Title',
    text: 'The Grand Title',
    fontSize: 58,
    fontFamily: 'Palatino Linotype',
    fontWeight: 700,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 3, offsetY: 3, blur: 6, color: 'rgba(0,0,0,0.4)' } },
  },
  {
    id: 'deco-price-tag',
    category: 'decorative',
    preview: '$99.99',
    text: '$99.99',
    fontSize: 64,
    fontFamily: 'Arial Black',
    fontWeight: 900,
    fontColor: '#ff0000',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 3, color: '#ffff00' } },
  },
  {
    id: 'deco-badge',
    category: 'decorative',
    preview: 'NEW!',
    text: 'NEW!',
    fontSize: 48,
    fontFamily: 'Arial Black',
    fontWeight: 900,
    fontColor: '#00cc00',
    effects: { ...DEFAULT_TEXT_EFFECTS, outline: { enabled: true, width: 3, color: '#006600' } },
  },
  {
    id: 'deco-label',
    category: 'decorative',
    preview: 'COMING SOON',
    text: 'COMING SOON',
    fontSize: 52,
    fontFamily: 'Helvetica',
    fontWeight: 700,
    fontColor: '#8a2be2',
    effects: { ...DEFAULT_TEXT_EFFECTS, glow: { enabled: true, color: '#8a2be2', intensity: 20 } },
  },
  {
    id: 'deco-ribbon-banner',
    category: 'decorative',
    preview: 'BEST SELLER',
    text: 'BEST SELLER',
    fontSize: 36,
    fontFamily: 'Arial Black',
    fontWeight: 900,
    fontColor: '#ffffff',
    effects: { ...DEFAULT_TEXT_EFFECTS, shadow: { enabled: true, offsetX: 2, offsetY: 2, blur: 4, color: '#8b0000' }, outline: { enabled: true, width: 2, color: '#cc0000' } },
  },
]

// ---------- Category Tabs ----------
const CATEGORIES = [
  { id: 'all', label: 'All', icon: <Type className="w-3.5 h-3.5" /> },
  { id: 'headline', label: 'Headlines', icon: <Heading1 className="w-3.5 h-3.5" /> },
  { id: 'subheading', label: 'Subheadings', icon: <Heading2 className="w-3.5 h-3.5" /> },
  { id: 'body', label: 'Body', icon: <AlignLeft className="w-3.5 h-3.5" /> },
  { id: 'effect', label: 'Effects', icon: <Sparkles className="w-3.5 h-3.5" /> },
  { id: 'decorative', label: 'Decorative', icon: <CircleDot className="w-3.5 h-3.5" /> },
]

// ---------- Measure text to compute proper box size ----------
function measureTextSize(text: string, fontSize: number, fontFamily: string, fontWeight: number): { width: number; height: number } {
  const canvas = document.createElement('canvas')
  const ctx = canvas.getContext('2d')!
  ctx.font = `${fontWeight} ${fontSize}px "${fontFamily}"`
  const lines = text.split('\n')
  const lineHeight = fontSize * 1.3
  let maxWidth = 0
  for (const line of lines) {
    const m = ctx.measureText(line)
    if (m.width > maxWidth) maxWidth = m.width
  }
  // Add padding so text doesn't sit on the exact edge
  return {
    width: Math.ceil(maxWidth + fontSize * 0.5),
    height: Math.ceil(lines.length * lineHeight + fontSize * 0.3),
  }
}

// ---------- Add from template helper ----------
function addTextFromTemplate(template: TextTemplate) {
  const { currentProject } = useLayerStore.getState()
  if (!currentProject) return

  const { width, height } = measureTextSize(template.text, template.fontSize, template.fontFamily, template.fontWeight)
  const layerId = generateId()
  const newLayer: Layer = {
    id: layerId,
    name: `Text: ${template.text.slice(0, 15)}`,
    type: 'text',
    visible: true,
    locked: false,
    opacity: 100,
    blendMode: 'normal',
    x: Math.floor(currentProject.width / 2 - width / 2),
    y: Math.floor(currentProject.height / 2 - height / 2),
    width,
    height,
    rotation: 0,
    text: template.text,
    fontFamily: template.fontFamily,
    fontSize: template.fontSize,
    fontColor: template.fontColor,
    fontWeight: template.fontWeight,
    textAlign: 'center',
    textEffects: template.effects,
  }
  useLayerStore.getState().addLayer(newLayer)
  useLayerStore.getState().selectLayer(layerId)
}

function addDefaultTextBox() {
  const { currentProject } = useLayerStore.getState()
  if (!currentProject) return

  const fontSize = 32
  const text = 'Your text here'
  const { width, height } = measureTextSize(text, fontSize, 'Arial', 400)
  const layerId = generateId()
  const newLayer: Layer = {
    id: layerId,
    name: 'New Text',
    type: 'text',
    visible: true,
    locked: false,
    opacity: 100,
    blendMode: 'normal',
    x: Math.floor(currentProject.width / 2 - width / 2),
    y: Math.floor(currentProject.height / 2 - height / 2),
    width,
    height,
    rotation: 0,
    text,
    fontFamily: 'Arial',
    fontSize,
    fontColor: '#ffffff',
    fontWeight: 400,
    textAlign: 'center',
    textEffects: DEFAULT_TEXT_EFFECTS,
  }
  useLayerStore.getState().addLayer(newLayer)
  useLayerStore.getState().selectLayer(layerId)
}

// ---------- Category Picker (dropdown) ----------
function CategoryPicker({ selected, onSelect, filteredCount }: { selected: string; onSelect: (id: string) => void; filteredCount: number }) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [open])

  const selectedCat = CATEGORIES.find(c => c.id === selected)
  const totalCount = TEXT_TEMPLATES.length

  return (
    <div className="px-3 pb-2" ref={ref}>
      <div className="relative">
        <button
          onClick={() => setOpen(!open)}
          className={`w-full flex items-center justify-between px-2.5 py-1.5 text-xs border transition-colors ${
            selected !== 'all'
              ? 'border-violet-400 dark:border-violet-500 bg-violet-50 dark:bg-violet-500/10 text-violet-700 dark:text-violet-300'
              : 'border-gray-300 dark:border-gray-600 bg-black/[0.03] dark:bg-black/40 text-gray-900 dark:text-gray-300'
          }`}
        >
          <span className="flex items-center gap-1.5 truncate">
            {selectedCat?.icon}
            {selectedCat?.label} ({filteredCount})
          </span>
          <ChevronDown className={`w-3.5 h-3.5 flex-shrink-0 ml-1 transition-transform ${open ? 'rotate-180' : ''}`} />
        </button>

        {open && (
          <div className="absolute left-0 right-0 top-full mt-1 bg-white dark:bg-gray-800 shadow-xl border border-gray-200 dark:border-gray-700 py-1 z-30">
            {CATEGORIES.map(cat => {
              const count = cat.id === 'all' ? totalCount : TEXT_TEMPLATES.filter(t => t.category === cat.id).length
              return (
                <button
                  key={cat.id}
                  onClick={() => { onSelect(cat.id); setOpen(false) }}
                  className="w-full flex items-center justify-between px-3 py-1.5 text-xs text-gray-900 dark:text-gray-300 hover:bg-black/[0.05] dark:hover:bg-gray-700"
                >
                  <span className="flex items-center gap-1.5">{cat.icon} {cat.label}</span>
                  <span className="flex items-center gap-1.5 flex-shrink-0">
                    <span className="text-gray-600 dark:text-gray-400">{count}</span>
                    {selected === cat.id && <Check className="w-3.5 h-3.5 text-violet-500" />}
                  </span>
                </button>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}

// ---------- Component ----------
export function TextPanel() {
  const { i18n } = useTranslation()
  const isGerman = i18n.language === 'de'
  const [selectedCategory, setSelectedCategory] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')

  const filteredTemplates = useMemo(() => {
    return TEXT_TEMPLATES.filter(tpl => {
      const matchesCategory = selectedCategory === 'all' || tpl.category === selectedCategory
      const matchesSearch = !searchQuery || tpl.preview.toLowerCase().includes(searchQuery.toLowerCase())
      return matchesCategory && matchesSearch
    })
  }, [selectedCategory, searchQuery])

  return (
    <div className="flex flex-col h-full">
      {/* Add text box button */}
      <div className="p-3 border-b border-gray-200 dark:border-gray-700">
        <button
          onClick={addDefaultTextBox}
          className="w-full flex items-center justify-center gap-2 py-2.5 bg-violet-500 hover:bg-violet-600 text-white text-sm font-semibold transition-colors"
        >
          <Plus className="w-4 h-4" />
          {isGerman ? 'Textfeld hinzufugen' : 'Add a text box'}
        </button>
      </div>

      {/* Search */}
      <div className="px-3 pt-3 pb-2">
        <div className="relative">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-900 dark:text-gray-400" />
          <input
            type="text"
            placeholder={isGerman ? 'Suchen...' : 'Search templates...'}
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            onKeyDown={e => e.stopPropagation()}
            className="w-full pl-8 pr-3 py-1.5 bg-black/[0.03] dark:bg-black/40 border border-gray-300 dark:border-gray-700 text-sm text-gray-900 dark:text-gray-200 placeholder-gray-500 focus:outline-none focus:border-violet-500 dark:focus:border-violet-500"
          />
        </div>
      </div>

      {/* Category picker */}
      <CategoryPicker selected={selectedCategory} onSelect={setSelectedCategory} filteredCount={filteredTemplates.length} />

      {/* Templates grid */}
      <div className="flex-1 overflow-y-auto p-2">
        <div className="space-y-0.5">
          {filteredTemplates.map(template => (
            <button
              key={template.id}
              onClick={() => addTextFromTemplate(template)}
              className="w-full px-2.5 py-1 hover:bg-gray-50 dark:hover:bg-gray-800 text-center transition-all group"
            >
              <div
                className="truncate"
                style={{
                  fontFamily: template.fontFamily,
                  fontSize: 14,
                  fontWeight: template.fontWeight,
                  color: template.fontColor,
                  textShadow: template.effects.shadow.enabled
                    ? `${template.effects.shadow.offsetX * 0.3}px ${template.effects.shadow.offsetY * 0.3}px ${template.effects.shadow.blur * 0.3}px ${template.effects.shadow.color}`
                    : template.effects.glow.enabled
                    ? `0 0 ${template.effects.glow.intensity * 0.3}px ${template.effects.glow.color}`
                    : 'none',
                  WebkitTextStroke: template.effects.outline.enabled
                    ? `${template.effects.outline.width * 0.3}px ${template.effects.outline.color}`
                    : undefined,
                }}
              >
                {template.preview}
              </div>
            </button>
          ))}
          {filteredTemplates.length === 0 && (
            <div className="text-center py-8 text-sm text-gray-400">
              {isGerman ? 'Keine Vorlagen gefunden' : 'No templates found'}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
