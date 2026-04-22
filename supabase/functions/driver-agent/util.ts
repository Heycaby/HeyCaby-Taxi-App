export function ok(body?: string) {
  return new Response(body ?? 'OK', { status: 200, headers: { 'Content-Type': 'text/plain' } })
}

export function json(obj: object, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

export async function safeCompare(a: string, b: string): Promise<boolean> {
  const encoder = new TextEncoder()
  const aBytes = encoder.encode(a)
  const bBytes = encoder.encode(b)
  if (aBytes.length !== bBytes.length) return false
  const aKey = await crypto.subtle.importKey('raw', aBytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const bKey = await crypto.subtle.importKey('raw', bBytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const dummy = encoder.encode('rydtap')
  const [aSig, bSig] = await Promise.all([
    crypto.subtle.sign('HMAC', aKey, dummy),
    crypto.subtle.sign('HMAC', bKey, dummy),
  ])
  const aArr = new Uint8Array(aSig)
  const bArr = new Uint8Array(bSig)
  let diff = 0
  for (let i = 0; i < aArr.length; i++) diff |= aArr[i] ^ bArr[i]
  return diff === 0
}
