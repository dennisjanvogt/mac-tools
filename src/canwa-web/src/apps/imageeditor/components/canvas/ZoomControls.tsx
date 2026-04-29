import { ZoomIn, ZoomOut, Maximize2 } from 'lucide-react'
import { useCanvasStore } from '@/stores/canwa'

export function ZoomControls() {
  const zoom = useCanvasStore(s => s.zoom)
  const setZoom = useCanvasStore(s => s.setZoom)
  const triggerFitToView = useCanvasStore(s => s.triggerFitToView)

  return (
    <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex items-center gap-1 bg-white dark:bg-gray-800 shadow-lg border border-gray-200 dark:border-gray-700 px-2 py-1">
      <button
        onClick={() => setZoom(zoom - 10)}
        disabled={zoom <= 10}
        className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-600 dark:text-gray-300 disabled:opacity-30 disabled:cursor-not-allowed"
        title="Zoom out"
      >
        <ZoomOut className="w-4 h-4" />
      </button>
      <span className="text-xs font-medium text-gray-600 dark:text-gray-300 w-12 text-center tabular-nums">
        {Math.round(zoom)}%
      </span>
      <button
        onClick={() => setZoom(zoom + 10)}
        disabled={zoom >= 400}
        className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-600 dark:text-gray-300 disabled:opacity-30 disabled:cursor-not-allowed"
        title="Zoom in"
      >
        <ZoomIn className="w-4 h-4" />
      </button>
      <div className="w-px h-4 bg-gray-300 dark:bg-gray-600 mx-0.5" />
      <button
        onClick={triggerFitToView}
        className="p-1.5 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-600 dark:text-gray-300"
        title="Fit to view"
      >
        <Maximize2 className="w-4 h-4" />
      </button>
    </div>
  )
}
