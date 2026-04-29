// Stub: in the standalone Canwa wrapper, setting the OS wallpaper from within
// the image editor is not supported. Keep the API shape so ExportDialog still
// compiles; calls resolve to no-op.
import { create } from 'zustand'

interface WallpaperState {
  addCustomWallpaper: (dataUrl: string, name?: string) => Promise<void>
  setCustomWallpaper: (id: string) => Promise<void>
}

export const useWallpaperStore = create<WallpaperState>(() => ({
  addCustomWallpaper: async () => {},
  setCustomWallpaper: async () => {},
}))
