import { useTranslation } from 'react-i18next'
import {
  Type,
  Sparkles,
  SlidersHorizontal,
  Layers,
  FolderOpen,
  Eclipse,
} from 'lucide-react'
import { useCanvasStore, type SidebarPanel } from '@/stores/canwa'

const RAIL_ITEMS: { id: SidebarPanel; icon: React.ComponentType<{ className?: string }>; labelKey: string }[] = [
  { id: 'layers', icon: Layers, labelKey: 'canwa.layers' },
  { id: 'text', icon: Type, labelKey: 'canwa.text' },
  { id: 'adjust', icon: SlidersHorizontal, labelKey: 'canwa.adjust' },
  { id: 'shadow', icon: Eclipse, labelKey: 'canwa.shadow' },
  { id: 'ai', icon: Sparkles, labelKey: 'canwa.ai' },
  { id: 'library', icon: FolderOpen, labelKey: 'canwa.library' },
]

export function SidebarRail() {
  const { t } = useTranslation()
  const activePanel = useCanvasStore(s => s.activePanel)
  const setActivePanel = useCanvasStore(s => s.setActivePanel)

  return (
    <div className="w-14 flex-shrink-0 bg-black/[0.03] dark:bg-black/40 flex flex-col items-center pt-2 gap-1">
      {RAIL_ITEMS.map(({ id, icon: Icon, labelKey }) => {
        const isActive = activePanel === id
        return (
          <button
            key={id}
            onClick={() => setActivePanel(id)}
            className={`w-11 h-11 flex flex-col items-center justify-center gap-0.5 transition-colors
              ${isActive
                ? 'bg-violet-100 dark:bg-violet-500/20 text-violet-600 dark:text-violet-400'
                : 'text-gray-700 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-gray-300'
              }`}
            title={t(labelKey)}
          >
            <Icon className="w-5 h-5" />
            <span className="text-[9px] font-medium leading-none truncate max-w-[36px]">{t(labelKey)}</span>
          </button>
        )
      })}
    </div>
  )
}
