import { useEffect, useState } from 'react'
import ImageEditorApp from '@/apps/imageeditor/ImageEditorApp'
import { useConfirmStore } from '@/stores/confirmStore'

interface ToastMsg { id: number; text: string }

function ErrorToasts() {
  const [toasts, setToasts] = useState<ToastMsg[]>([])

  useEffect(() => {
    let nextId = 1
    const push = (text: string) => {
      const id = nextId++
      setToasts(prev => [...prev, { id, text }])
      setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 7000)
    }
    const onError = (e: ErrorEvent) => {
      push(`Fehler: ${e.message || e.error?.toString() || 'unbekannt'}`)
    }
    const onRejection = (e: PromiseRejectionEvent) => {
      const reason = e.reason
      const msg = reason instanceof Error ? reason.message : String(reason)
      push(`Promise-Fehler: ${msg}`)
    }
    window.addEventListener('error', onError)
    window.addEventListener('unhandledrejection', onRejection)
    return () => {
      window.removeEventListener('error', onError)
      window.removeEventListener('unhandledrejection', onRejection)
    }
  }, [])

  if (toasts.length === 0) return null
  return (
    <div className="fixed top-2 left-1/2 -translate-x-1/2 z-[9999] flex flex-col gap-1.5 pointer-events-none">
      {toasts.map(t => (
        <div
          key={t.id}
          className="bg-red-900/90 text-white text-xs px-3 py-1.5 rounded shadow-lg max-w-[600px] pointer-events-auto"
        >
          {t.text}
        </div>
      ))}
    </div>
  )
}

function ConfirmDialog() {
  const s = useConfirmStore()
  if (!s.isOpen) return null
  return (
    <div className="fixed inset-0 z-[9999] bg-black/60 flex items-center justify-center">
      <div className="bg-gray-900 border border-gray-700 rounded-lg p-5 w-[380px] shadow-2xl">
        {s.title && <div className="text-base font-semibold text-gray-100 mb-2">{s.title}</div>}
        <div className="text-sm text-gray-300 mb-5 whitespace-pre-wrap">{s.message}</div>
        <div className="flex justify-end gap-2">
          <button
            onClick={() => s.onCancel?.()}
            className="px-3 py-1.5 text-sm text-gray-300 bg-gray-800 hover:bg-gray-700 rounded"
          >
            {s.cancelLabel}
          </button>
          <button
            onClick={() => s.onConfirm?.()}
            className={
              'px-3 py-1.5 text-sm text-white rounded ' +
              (s.variant === 'danger'
                ? 'bg-red-600 hover:bg-red-500'
                : 'bg-violet-600 hover:bg-violet-500')
            }
          >
            {s.confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}

export default function App() {
  useEffect(() => {
    // Let Swift know we're mounted so it can inject the token / open project.
    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ;(window as any).webkit?.messageHandlers?.canwa?.postMessage({ type: 'ready' })
    } catch {
      /* not in WKWebView */
    }
  }, [])

  return (
    <div className="w-screen h-screen overflow-hidden text-gray-100">
      <ImageEditorApp />
      <ConfirmDialog />
      <ErrorToasts />
    </div>
  )
}
