// Bearer-token API client for Canwa native wrapper.
// Token is injected by Swift via window.canwaConfig.
declare global {
  interface Window {
    canwaConfig?: {
      apiBase: string
      token: string
      onTokenRefresh?: (token: string) => void
    }
  }
}

// Left intentionally as a no-op. The global fetch proxy rewrites /api/...
// to canwa://app/api/..., and Swift's scheme handler attaches the Bearer token
// and routes to the actual backend. Keeps CORS out of the picture.

class ApiError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
    this.name = 'ApiError'
  }
}

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'
  body?: unknown
  headers?: Record<string, string>
  timeout?: number
}

async function request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, headers = {}, timeout = 30000 } = options
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeout)

  const cfg: RequestInit = {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    signal: controller.signal,
  }
  if (body) cfg.body = JSON.stringify(body)

  try {
    // Endpoints start with /customers, /imageeditor/... — we prepend /api so the
    // global fetch proxy (see main.tsx) rewrites to canwa://app/api/... and Swift
    // attaches the Bearer token natively.
    const url = `/api${endpoint}`
    const res = await fetch(url, cfg)
    if (!res.ok) {
      const text = await res.text().catch(() => '')
      let parsed: { error?: string; detail?: string } = {}
      try { parsed = JSON.parse(text) } catch { /* not JSON */ }
      const detail = parsed.error || parsed.detail || text.slice(0, 200) || 'Request failed'
      throw new ApiError(res.status, `${method} ${url} → ${res.status} ${detail}`)
    }
    if (res.status === 204) return null as T
    const ct = res.headers.get('content-type') || ''
    if (ct.includes('application/json')) return (await res.json()) as T
    return (await res.text()) as unknown as T
  } finally {
    clearTimeout(timeoutId)
  }
}

export const api = {
  get: <T>(endpoint: string, options?: Omit<RequestOptions, 'method' | 'body'>) =>
    request<T>(endpoint, { ...options, method: 'GET' }),
  post: <T>(endpoint: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) =>
    request<T>(endpoint, { ...options, method: 'POST', body }),
  put: <T>(endpoint: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) =>
    request<T>(endpoint, { ...options, method: 'PUT', body }),
  patch: <T>(endpoint: string, body?: unknown, options?: Omit<RequestOptions, 'method' | 'body'>) =>
    request<T>(endpoint, { ...options, method: 'PATCH', body }),
  delete: <T>(endpoint: string, options?: Omit<RequestOptions, 'method' | 'body'>) =>
    request<T>(endpoint, { ...options, method: 'DELETE' }),
  postFormData: async <T>(endpoint: string, formData: FormData): Promise<T> => {
    const res = await fetch(`/api${endpoint}`, {
      method: 'POST',
      body: formData,
    })
    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: 'Upload failed' }))
      throw new ApiError(res.status, err.error || 'Upload failed')
    }
    return (await res.json()) as T
  },
}

export { ApiError }
