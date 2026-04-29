// OpenRouter Proxy - calls backend instead of direct API (keeps API key secure)

export interface OpenRouterRequest {
  model: string
  messages: Array<{ role: string; content: string | Array<unknown> }>
  max_tokens?: number
  temperature?: number
  response_format?: { type: string }
}

export interface OpenRouterResponse {
  choices?: Array<{
    message?: {
      content?: unknown
      images?: Array<{
        type?: string
        image_url?: { url?: string }
        url?: string
      }>
      image_url?: string
      tool_calls?: Array<{
        function?: { name?: string; arguments?: string }
      }>
    }
  }>
  data?: Array<{
    b64_json?: string
    url?: string
  }>
}

// Allowed domains for fetching external images (SSRF protection)
const ALLOWED_IMAGE_DOMAINS = [
  'oaidalleapiprodscus.blob.core.windows.net',
  'replicate.delivery',
  'pbxt.replicate.delivery',
  'cdn.openai.com',
  'images.openai.com',
  'storage.googleapis.com',
  'generativelanguage.googleapis.com',
  'lh3.googleusercontent.com',
  'fal.media',
  'v3.fal.media',
]

function isAllowedImageUrl(url: string): boolean {
  try {
    const parsed = new URL(url)
    if (parsed.protocol !== 'https:') return false
    return ALLOWED_IMAGE_DOMAINS.some(domain =>
      parsed.hostname === domain || parsed.hostname.endsWith('.' + domain)
    )
  } catch {
    return false
  }
}

export async function fetchExternalImage(url: string, timeoutMs = 30000): Promise<string> {
  if (!isAllowedImageUrl(url)) {
    console.warn('Blocked fetch to non-whitelisted domain:', url)
    throw new Error('Image URL is not from an allowed domain')
  }
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs)
  try {
    const response = await fetch(url, { signal: controller.signal })
    clearTimeout(timeoutId)
    if (!response.ok) throw new Error(`Failed to fetch image: ${response.status}`)
    const contentType = response.headers.get('content-type')
    if (!contentType?.startsWith('image/')) throw new Error('URL did not return an image')
    const blob = await response.blob()
    return new Promise<string>((resolve, reject) => {
      const reader = new FileReader()
      reader.onloadend = () => resolve(reader.result as string)
      reader.onerror = reject
      reader.readAsDataURL(blob)
    })
  } catch (error) {
    clearTimeout(timeoutId)
    if (error instanceof Error && error.name === 'AbortError') throw new Error('Image download timed out')
    throw error
  }
}

export async function callOpenRouterProxy(request: OpenRouterRequest): Promise<OpenRouterResponse> {
  const response = await fetch('/api/ai/openrouter/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(request),
  })
  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }))
    throw new Error(error.error || `API error: ${response.status}`)
  }
  return response.json()
}

export function safeJsonParse<T>(json: string, fallback: T): T {
  try { return JSON.parse(json) as T } catch (e) { console.warn('Failed to parse JSON:', e); return fallback }
}
