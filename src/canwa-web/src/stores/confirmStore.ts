import { create } from 'zustand'

interface ConfirmState {
  isOpen: boolean
  title: string
  message: string
  confirmLabel: string
  cancelLabel: string
  variant: 'danger' | 'warning' | 'default'
  onConfirm: (() => void) | null
  onCancel: (() => void) | null

  confirm: (options: {
    title?: string
    message: string
    confirmLabel?: string
    cancelLabel?: string
    variant?: 'danger' | 'warning' | 'default'
  }) => Promise<boolean>

  close: () => void
}

export const useConfirmStore = create<ConfirmState>((set) => ({
  isOpen: false,
  title: '',
  message: '',
  confirmLabel: 'Bestätigen',
  cancelLabel: 'Abbrechen',
  variant: 'default',
  onConfirm: null,
  onCancel: null,

  confirm: (options) => {
    return new Promise((resolve) => {
      set({
        isOpen: true,
        title: options.title || '',
        message: options.message,
        confirmLabel: options.confirmLabel || 'Bestätigen',
        cancelLabel: options.cancelLabel || 'Abbrechen',
        variant: options.variant || 'default',
        onConfirm: () => {
          set({ isOpen: false })
          resolve(true)
        },
        onCancel: () => {
          set({ isOpen: false })
          resolve(false)
        },
      })
    })
  },

  close: () => set({ isOpen: false }),
}))
