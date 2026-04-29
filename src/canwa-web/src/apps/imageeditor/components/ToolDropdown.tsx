import { useState, useRef, useEffect } from 'react'
import { ChevronDown } from 'lucide-react'
import type { Tool } from '../types'

interface ToolItem {
  id: Tool
  icon: React.ReactNode
  label: string
  shortcut: string
}

interface ToolDropdownProps {
  label: string
  tools: ToolItem[]
  activeTool: Tool
  onSelectTool: (tool: Tool) => void
  groupIcon: React.ReactNode
}

export function ToolDropdown({
  label,
  tools,
  activeTool,
  onSelectTool,
  groupIcon,
}: ToolDropdownProps) {
  const [isOpen, setIsOpen] = useState(false)
  const dropdownRef = useRef<HTMLDivElement>(null)

  // Find active tool in this group
  const activeToolInGroup = tools.find((t) => t.id === activeTool)

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setIsOpen(false)
      }
    }

    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isOpen])

  // Close on Escape
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsOpen(false)
      }
    }

    if (isOpen) {
      document.addEventListener('keydown', handleKeyDown)
    }

    return () => {
      document.removeEventListener('keydown', handleKeyDown)
    }
  }, [isOpen])

  return (
    <div ref={dropdownRef} className="relative">
      {/* Dropdown Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className={`flex items-center gap-1.5 px-2 py-1.5 transition-colors ${
          activeToolInGroup
            ? 'bg-accent-600 text-white'
            : 'hover:bg-gray-700 text-gray-300'
        }`}
      >
        {/* Show active tool icon or group icon */}
        <span className="w-4 h-4 flex items-center justify-center">
          {activeToolInGroup ? activeToolInGroup.icon : groupIcon}
        </span>
        <span className="text-xs font-medium max-w-[60px] truncate">
          {activeToolInGroup ? activeToolInGroup.label : label}
        </span>
        <ChevronDown className={`w-3 h-3 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
      </button>

      {/* Dropdown Menu */}
      {isOpen && (
        <div className="absolute top-full left-0 mt-1 min-w-[160px] bg-gray-800 border border-gray-700 shadow-xl z-50 py-1">
          {tools.map((tool) => (
            <button
              key={tool.id}
              onClick={() => {
                onSelectTool(tool.id)
                setIsOpen(false)
              }}
              className={`w-full flex items-center gap-2 px-3 py-2 text-left transition-colors ${
                activeTool === tool.id
                  ? 'bg-accent-600/30 text-white'
                  : 'hover:bg-gray-700 text-gray-300'
              }`}
            >
              <span className="w-4 h-4 flex items-center justify-center">
                {tool.icon}
              </span>
              <span className="flex-1 text-sm">{tool.label}</span>
              <span className="text-xs text-gray-500 font-mono">{tool.shortcut}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
