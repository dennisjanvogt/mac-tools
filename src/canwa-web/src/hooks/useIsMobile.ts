import { useState, useEffect } from 'react'

const MOBILE_BREAKPOINT = 1024

/**
 * Hook to detect if viewport is mobile/tablet (< 1024px) or desktop (>= 1024px)
 * Uses viewport width, not container width, since this is for shell-level detection.
 */
export function useIsMobile() {
  const [isMobile, setIsMobile] = useState(() => {
    // SSR-safe: default to false, will be corrected on mount
    if (typeof window === 'undefined') return false
    return window.innerWidth < MOBILE_BREAKPOINT
  })

  useEffect(() => {
    const checkSize = () => {
      setIsMobile(window.innerWidth < MOBILE_BREAKPOINT)
    }

    // Check on mount
    checkSize()

    // Listen for resize
    window.addEventListener('resize', checkSize)
    return () => window.removeEventListener('resize', checkSize)
  }, [])

  return {
    isMobile,
    isDesktop: !isMobile,
  }
}
