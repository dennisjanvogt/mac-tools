import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'
import './i18n'
import App from './App'

// Global fetch interceptor: rewrite any relative "/api/…" requests to the
// same-origin canwa://app/api/… scheme. Swift's URL-Scheme handler does the
// actual HTTPS call to the backend with the Bearer token, so we don't deal
// with CORS here at all.
;(function installFetchProxy() {
  const orig = window.fetch.bind(window)
  window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    let url: string
    if (typeof input === 'string') url = input
    else if (input instanceof URL) url = input.toString()
    else url = input.url

    if (url.startsWith('/api/') || url.startsWith('/media/') || url.startsWith('/static/')) {
      const rewritten = 'canwa://app' + url
      const headers = new Headers(init?.headers || (typeof input !== 'string' && !(input instanceof URL) ? input.headers : undefined))
      headers.delete('X-CSRFToken')
      headers.delete('Authorization')  // Swift attaches it natively.
      const newInit: RequestInit = {
        ...init,
        headers,
        credentials: 'omit',
      }
      if (typeof input === 'string' || input instanceof URL) {
        return orig(rewritten, newInit)
      }
      return orig(new Request(rewritten, {
        method: input.method,
        headers,
        body: input.bodyUsed ? undefined : (input.method === 'GET' || input.method === 'HEAD' ? undefined : input.clone().body),
        credentials: 'omit',
        cache: input.cache,
        redirect: input.redirect,
        referrer: input.referrer,
        integrity: input.integrity,
        ...newInit,
      }))
    }
    return orig(input as RequestInfo, init)
  }
})()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
