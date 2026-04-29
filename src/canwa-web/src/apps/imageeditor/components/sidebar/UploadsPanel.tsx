import { useState, useCallback, useRef } from 'react'
import { Upload, ImagePlus } from 'lucide-react'
import { useLayerStore } from '@/stores/canwa'

export function UploadsPanel() {
  const [isDragOver, setIsDragOver] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const addImageAsLayer = useLayerStore(s => s.addImageAsLayer)

  const handleFiles = useCallback(async (files: FileList) => {
    for (const file of Array.from(files)) {
      if (file.type.startsWith('image/')) {
        await addImageAsLayer(file)
      }
    }
  }, [addImageAsLayer])

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    setIsDragOver(false)
    if (e.dataTransfer.files.length > 0) {
      handleFiles(e.dataTransfer.files)
    }
  }, [handleFiles])

  return (
    <div className="p-4 space-y-4">
      <div
        onDragOver={e => { e.preventDefault(); setIsDragOver(true) }}
        onDragLeave={() => setIsDragOver(false)}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
        className={`border-2 border-dashed p-8 flex flex-col items-center justify-center gap-3 cursor-pointer transition-colors
          ${isDragOver
            ? 'border-violet-500 bg-violet-50 dark:bg-violet-500/10'
            : 'border-gray-300 dark:border-gray-600 hover:border-violet-400 dark:hover:border-violet-500'
          }`}
      >
        <Upload className={`w-8 h-8 ${isDragOver ? 'text-violet-500' : 'text-gray-400'}`} />
        <div className="text-center">
          <p className="text-sm font-medium text-gray-700 dark:text-gray-300">
            Drop images here
          </p>
          <p className="text-xs text-gray-400 mt-1">or click to browse</p>
        </div>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        multiple
        className="hidden"
        onChange={e => e.target.files && handleFiles(e.target.files)}
      />

      <button
        onClick={() => fileInputRef.current?.click()}
        className="w-full flex items-center gap-2 px-3 py-2.5 bg-violet-500 hover:bg-violet-600 text-white text-sm font-medium transition-colors"
      >
        <ImagePlus className="w-4 h-4" />
        Upload Image
      </button>
    </div>
  )
}
