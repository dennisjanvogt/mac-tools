// Minimal stub for @/stores/aiStore — canwa/aiStore only reads
// `imageModel` and `analysisModel` from it with fallbacks.
import { create } from 'zustand'

interface AIState {
  imageModel: string
  analysisModel: string
}

export const useAIStore = create<AIState>(() => ({
  imageModel: 'google/gemini-2.0-flash-001:image-generation',
  analysisModel: 'google/gemini-2.0-flash-001',
}))
