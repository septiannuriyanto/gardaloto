export default {
  async fetch(req, env) {

    // 🔴 Kill Switch
    if (env.MAINTENANCE_MODE === "true") {
      return new Response('Service temporarily unavailable', { status: 503 })
    }

    const url = new URL(req.url)

    if (req.method === 'POST' && url.pathname === '/upload') {

      // 1️⃣ Ambil IP client
      const ip = req.headers.get('cf-connecting-ip') ?? 'unknown'
      console.log('UPLOAD from IP:', ip)

      // 1-b Rate Limiting
      const LIMIT = 10
      const WINDOW = 60
      const now = Math.floor(Date.now() / 1000)
      const bucket = Math.floor(now / WINDOW)
      const rateKey = `upload:${ip}:${bucket}`
      try {
        const current = await env.RATE_LIMIT_KV.get(rateKey)
        const count = current ? Number(current) : 0
        if (count >= LIMIT) return new Response('Too many uploads', { status: 429 })
        await env.RATE_LIMIT_KV.put(rateKey, String(count + 1), { expirationTtl: WINDOW })
      } catch (e) {
        console.error("KV Error", e)
      }

      // 2️⃣ Auth: Native JWT verify (HS256)
      const authHeader = req.headers.get('Authorization')
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return new Response('Unauthorized: Missing Bearer Token', { status: 401 })
      }
      const token = authHeader.split(' ')[1]

      let decoded
      try {
        decoded = await verifyJWT(token, env.SUPABASE_JWT_SECRET)
      } catch (err) {
        return new Response('Unauthorized: Invalid JWT', { status: 401 })
      }

      console.log('Upload by user:', decoded.sub)

      // 3️⃣ Size limit (Base64 overhead ~33%)
      const MAX_SIZE = 7 * 1024 * 1024 // 7MB
      const contentLength = req.headers.get('content-length')
      if (!contentLength || Number(contentLength) > MAX_SIZE) {
        return new Response('File too large', { status: 413 })
      }

      // 4️⃣ Parse payload
      let body
      try { body = await req.json() } catch { return new Response('Invalid JSON', { status: 400 }) }

      const { year, month, day, shift, wh, unitName, image_data } = body
      if (!year || !month || !day || !shift || !wh || !unitName || !image_data) {
        return new Response('Missing required fields', { status: 400 })
      }

      // 5️⃣ Decode Base64
      const binaryString = atob(image_data)
      const len = binaryString.length
      const bytes = new Uint8Array(len)
      for (let i = 0; i < len; i++) bytes[i] = binaryString.charCodeAt(i)

      // 6️⃣ Key R2
      const ext = 'jpg' // default
      const key = `${year}/${month}/${day}/${shift}/${wh}/${unitName}.${ext}`

      // 7️⃣ Upload ke R2
      await env.R2_GARDALOTO.put(key, bytes.buffer, {
        httpMetadata: { contentType: 'image/jpeg' }
      })

      // 8️⃣ Response
      return Response.json({
        key,
        url: `https://gardaloto.septian-nuryanto.workers.dev/${key}`
      })
    }

    return new Response('Not found', { status: 404 })
  }
}

// ------------------------
// Minimal native HS256 JWT verify
async function verifyJWT(token, secret) {
  const [headerB64, payloadB64, signatureB64] = token.split('.')
  if (!headerB64 || !payloadB64 || !signatureB64) throw new Error('Invalid token')

  const encoder = new TextEncoder()
  const keyData = encoder.encode(secret)
  const cryptoKey = await crypto.subtle.importKey(
    'raw', keyData, { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']
  )

  const data = encoder.encode(`${headerB64}.${payloadB64}`)
  const sig = Uint8Array.from(atob(signatureB64.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0))

  const valid = await crypto.subtle.verify('HMAC', cryptoKey, sig, data)
  if (!valid) throw new Error('Invalid signature')

  const payloadJson = atob(payloadB64.replace(/-/g, '+').replace(/_/g, '/'))
  return JSON.parse(payloadJson)
}
