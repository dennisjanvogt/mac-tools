import { useState, useRef, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { useCanvasStore, type SidebarPanel as SidebarPanelType } from '@/stores/canwa'

// Lazy imports for panel content
import { DesignPanel } from './DesignPanel'
import { UploadsPanel } from './UploadsPanel'
import { TextPanel } from './TextPanel'
import { AIPanel } from './AIPanel'
import { AdjustPanel } from './AdjustPanel'
import { ShadowPanel } from './ShadowPanel'
import { LayersPanel } from './LayersPanel'
import { LibraryPanel } from './LibraryPanel'
import { PropertiesPanel } from '../canvas/ContextToolbar'

const PANEL_COMPONENTS: Record<NonNullable<SidebarPanelType>, React.ComponentType> = {
  design: DesignPanel,
  uploads: UploadsPanel,
  text: TextPanel,
  ai: AIPanel,
  adjust: AdjustPanel,
  shadow: ShadowPanel,
  layers: LayersPanel,
  library: LibraryPanel,
  properties: PropertiesPanel,
}

const PANEL_TITLES: Record<NonNullable<SidebarPanelType>, string> = {
  design: 'canwa.design',
  uploads: 'canwa.uploads',
  text: 'canwa.text',
  ai: 'canwa.ai',
  adjust: 'canwa.adjust',
  shadow: 'canwa.shadow',
  layers: 'canwa.layers',
  library: 'canwa.library',
  properties: 'canwa.properties',
}

// ---------------------------------------------------------------------------
// Left sidebar panel (properties, text, adjust, ai, library — NOT layers)
// ---------------------------------------------------------------------------
export function LeftSidebarPanel() {
  const { t } = useTranslation()
  const activePanel = useCanvasStore(s => s.activePanel)
  const [panelWidth, setPanelWidth] = useState(280)
  const isResizing = useRef(false)
  const startX = useRef(0)
  const startWidth = useRef(280)

  const handleResizeStart = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    isResizing.current = true
    startX.current = e.clientX
    startWidth.current = panelWidth
    const onMove = (ev: MouseEvent) => {
      if (!isResizing.current) return
      const delta = ev.clientX - startX.current
      const newWidth = Math.max(200, Math.min(500, startWidth.current + delta))
      setPanelWidth(newWidth)
    }
    const onUp = () => {
      isResizing.current = false
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('mouseup', onUp)
    }
    document.addEventListener('mousemove', onMove)
    document.addEventListener('mouseup', onUp)
  }, [panelWidth])

  // Don't render for layers (layers has its own panel on the right)
  if (!activePanel || activePanel === 'layers') return null

  const PanelComponent = PANEL_COMPONENTS[activePanel]

  return (
    <div
      className="flex-shrink-0 flex flex-col relative"
      style={{ width: panelWidth, maxWidth: `min(${panelWidth}px, calc(100vw - 200px))` }}
    >
      <div className="flex items-center justify-center px-4 py-3 mb-1">
        <h3 className="text-sm font-semibold text-gray-800 dark:text-gray-200 text-center">
          {t(PANEL_TITLES[activePanel])}
        </h3>
      </div>
      <div className="flex-1 overflow-y-auto overflow-x-hidden">
        {PanelComponent ? <PanelComponent /> : null}
      </div>
      {/* Resize handle on right edge */}
      <div
        onMouseDown={handleResizeStart}
        className="absolute top-0 right-0 w-1.5 h-full cursor-col-resize hover:bg-violet-500/30 active:bg-violet-500/50 transition-colors z-10"
      />
    </div>
  )
}

// ---------------------------------------------------------------------------
// Right layers panel (always visible)
// ---------------------------------------------------------------------------
export function RightLayersPanel() {
  const { t } = useTranslation()
  const [panelWidth, setPanelWidth] = useState(260)
  const isResizing = useRef(false)
  const startX = useRef(0)
  const startWidth = useRef(260)

  const handleResizeStart = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    isResizing.current = true
    startX.current = e.clientX
    startWidth.current = panelWidth
    const onMove = (ev: MouseEvent) => {
      if (!isResizing.current) return
      const delta = startX.current - ev.clientX
      const newWidth = Math.max(180, Math.min(400, startWidth.current + delta))
      setPanelWidth(newWidth)
    }
    const onUp = () => {
      isResizing.current = false
      document.removeEventListener('mousemove', onMove)
      document.removeEventListener('mouseup', onUp)
    }
    document.addEventListener('mousemove', onMove)
    document.addEventListener('mouseup', onUp)
  }, [panelWidth])

  return (
    <div
      className="flex-shrink-0 bg-black/[0.03] dark:bg-black/40 flex flex-col relative"
      style={{ width: panelWidth, maxWidth: `min(${panelWidth}px, calc(100vw - 200px))` }}
    >
      <div className="flex items-center justify-center px-4 py-3 mb-1">
        <h3 className="text-sm font-semibold text-gray-800 dark:text-gray-200 text-center">
          {t('canwa.layers')}
        </h3>
      </div>
      <div className="flex-1 overflow-y-auto overflow-x-hidden">
        <LayersPanel />
      </div>
      {/* Resize handle on left edge */}
      <div
        onMouseDown={handleResizeStart}
        className="absolute top-0 left-0 w-1.5 h-full cursor-col-resize hover:bg-violet-500/30 active:bg-violet-500/50 transition-colors z-10"
      />
    </div>
  )
}
