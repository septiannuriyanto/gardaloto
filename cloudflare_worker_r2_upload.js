export default {
  async fetch(req, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    try {
      const url = new URL(req.url)

      // 0️⃣ Preflight
      if (req.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders })
      }

      // 🔴 Maintenance
      if (env.MAINTENANCE_MODE === "true") {
        return new Response('Service temporarily unavailable', {
          status: 503,
          headers: corsHeaders
        })
      }

      // 1️⃣ UPLOAD
      if (req.method === 'POST' && url.pathname === '/upload') {

        /* === Rate Limit === */
        const ip = req.headers.get('cf-connecting-ip') ?? 'unknown'
        const LIMIT = 100, WINDOW = 60
        const now = Math.floor(Date.now() / 1000)
        const windowKey = Math.floor(now / WINDOW)
        const rateKey = `upload:${ip}:${windowKey}`

        try {
          const count = Number(await env.RATE_LIMIT_KV.get(rateKey) || 0)
          if (count >= LIMIT)
            return new Response('Too many uploads', { status: 429, headers: corsHeaders })

          await env.RATE_LIMIT_KV.put(rateKey, String(count + 1), {
            expirationTtl: WINDOW
          })
        } catch (e) {
          console.error('KV Error', e)
        }

        /* === JWT Auth (1 JWT) === */
        const token = req.headers.get('Authorization')?.split(' ')[1]
        if (!token)
          return new Response('Unauthorized', { status: 401, headers: corsHeaders })

        try {
          await verifyJWT(token, env.SUPABASE_JWT_SECRET)
        } catch {
          return new Response('Unauthorized', { status: 401, headers: corsHeaders })
        }

        /* === Parse Payload === */
        let body
        try {
          body = await req.json()
        } catch {
          return new Response('Invalid JSON', { status: 400, headers: corsHeaders })
        }

        const {
          bucket,   // optional (backward compatible)
          year,
          month,
          day,
          shift,
          wh,
          unitName,
          image_data
        } = body

        if (!year || !month || !day || !shift || !wh || !unitName || !image_data) {
          return new Response('Missing fields', { status: 400, headers: corsHeaders })
        }

        /* === Select Bucket (DEFAULT → loto) === */
        let bucketName = bucket || 'loto'
        let targetBucket

        if (bucketName === 'loto') {
          targetBucket = env.R2_GARDALOTO
        } else if (bucketName === 'ritation') {
          targetBucket = env.R2_RITATION
        } else {
          return new Response('Invalid bucket', { status: 400, headers: corsHeaders })
        }

        /* === Decode Base64 === */
        const bytes = Uint8Array.from(
          atob(image_data),
          c => c.charCodeAt(0)
        )

        /* === Upload === */
        const key = `${year}/${month}/${day}/${shift}/${wh}/${unitName}.jpg`

        await targetBucket.put(key, bytes.buffer, {
          httpMetadata: { contentType: 'image/jpeg' }
        })

        const publicUrl = `${url.origin}/files/${bucketName}/${key}`

        return Response.json(
          { bucket: bucketName, key, url: publicUrl },
          { headers: corsHeaders }
        )
      }

      // 2️⃣ PUBLIC FILE
      if (req.method === 'GET' && url.pathname.startsWith('/files/')) {
        // /files/{bucket}/{path...}
        const [, , bucketName, ...pathParts] = url.pathname.split('/')
        const key = pathParts.join('/')

        let targetBucket
        if (bucketName === 'loto') {
          targetBucket = env.R2_GARDALOTO
        } else if (bucketName === 'ritation') {
          targetBucket = env.R2_RITATION
        } else {
          return new Response('Invalid bucket', { status: 400, headers: corsHeaders })
        }

        const obj = await targetBucket.get(key)
        if (!obj)
          return new Response('Not found', { status: 404, headers: corsHeaders })

        const headers = new Headers(obj.httpMetadata)
        headers.set('etag', obj.httpEtag)
        headers.set('Access-Control-Allow-Origin', '*')

        return new Response(obj.body, { headers })
      }

      return new Response('Not found', { status: 404, headers: corsHeaders })

    } catch (err) {
      console.error(err)
      return new Response(
        'Internal Server Error',
        { status: 500, headers: { 'Access-Control-Allow-Origin': '*' } }
      )
    }
  }
}

/* === Minimal HS256 JWT verify === */
async function verifyJWT(token, secret) {
  const [h, p, s] = token.split('.')
  if (!h || !p || !s) throw new Error()

  const enc = new TextEncoder()
  const key = enc.encode(secret)

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify']
  )

  const data = enc.encode(`${h}.${p}`)
  const sig = Uint8Array.from(
    atob(s.replace(/-/g, '+').replace(/_/g, '/')),
    c => c.charCodeAt(0)
  )

  const valid = await crypto.subtle.verify('HMAC', cryptoKey, sig, data)
  if (!valid) throw new Error()

  return JSON.parse(atob(p.replace(/-/g, '+').replace(/_/g, '/')))
}
