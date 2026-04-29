import { useState, useEffect } from 'react'
import { ChevronDown, ChevronRight } from 'lucide-react'

const STORAGE_KEY = 'canwa-section-state'

function getSavedState(): Record<string, boolean> {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}')
  } catch { return {} }
}

function saveState(id: string, open: boolean) {
  const state = getSavedState()
  state[id] = open
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
}

interface PersistentSectionProps {
  id: string
  title: string
  icon?: React.ComponentType<{ className?: string }>
  children: React.ReactNode
  defaultOpen?: boolean
  /** Show checkbox for enable/disable */
  enabled?: boolean
  onToggle?: (v: boolean) => void
}

export function PersistentSection({
  id,
  title,
  icon: Icon,
  children,
  defaultOpen = false,
  enabled,
  onToggle,
}: PersistentSectionProps) {
  const [open, setOpen] = useState(() => {
    const saved = getSavedState()
    return saved[id] ?? defaultOpen
  })

  useEffect(() => {
    saveState(id, open)
  }, [id, open])

  return (
    <div className="mb-1">
      <button
        onClick={() => setOpen(!open)}
        className="w-full flex items-center gap-2 px-4 py-2.5 text-left bg-black/[0.03] dark:bg-black/40 hover:bg-black/[0.06] dark:hover:bg-black/50 transition-colors"
      >
        {onToggle !== undefined && (
          <input
            type="checkbox"
            checked={enabled}
            onChange={(e) => { e.stopPropagation(); onToggle?.(e.target.checked) }}
            onClick={(e) => e.stopPropagation()}
            className="accent-violet-500 w-3.5 h-3.5"
          />
        )}
        {Icon && <Icon className="w-4 h-4 text-gray-700 dark:text-gray-400" />}
        <span className="text-xs font-semibold text-gray-900 dark:text-gray-300 flex-1 text-center">
          {title}
        </span>
        {open ? (
          <ChevronDown className="w-3.5 h-3.5 text-gray-600 dark:text-gray-400" />
        ) : (
          <ChevronRight className="w-3.5 h-3.5 text-gray-600 dark:text-gray-400" />
        )}
      </button>
      {open && <div className="px-4 pb-3 pt-2 space-y-2">{children}</div>}
    </div>
  )
}
