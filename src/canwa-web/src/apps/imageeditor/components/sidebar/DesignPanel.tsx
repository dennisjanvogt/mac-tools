import { useTranslation } from 'react-i18next'
import { PROJECT_PRESETS } from '@/stores/canwa/utils/constants'

export function DesignPanel() {
  const { t } = useTranslation()

  return (
    <div className="p-4 space-y-4">
      <div>
        <h4 className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-2">
          {t('canwa.presets', 'Size Presets')}
        </h4>
        <div className="grid grid-cols-2 gap-2">
          {PROJECT_PRESETS.map(preset => (
            <button
              key={preset.name}
              className="text-left p-2.5 border border-gray-200 dark:border-gray-700 hover:border-violet-400 dark:hover:border-violet-500 hover:bg-violet-50 dark:hover:bg-violet-500/10 transition-colors group"
              onClick={() => {
                // Will be wired to create new project
              }}
            >
              <div className="text-xs font-medium text-gray-800 dark:text-gray-200 group-hover:text-violet-600 dark:group-hover:text-violet-400">
                {preset.name}
              </div>
              <div className="text-[10px] text-gray-400">{preset.width} x {preset.height}</div>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
