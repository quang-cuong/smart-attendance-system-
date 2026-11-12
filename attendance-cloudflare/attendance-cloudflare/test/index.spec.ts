import { SELF } from 'cloudflare:test';
import { describe, it, expect } from 'vitest';

describe('Attendance API access controls', () => {
  it('returns 404 for an unknown route', async () => {
    const response = await SELF.fetch('https://example.com/');
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({ success: false });
  });
  it.each(['students', 'classes', 'face-data', 'attendance'])(
    'requires authentication for legacy %s', async (route) => {
      const response = await SELF.fetch(`https://example.com/api/${route}`);
      expect(response.status).toBe(401);
    },
  );
  it('allows PATCH in the close-session preflight', async () => {
    const response = await SELF.fetch('https://example.com/api/admin/sessions/1/close', {
      method: 'OPTIONS',
      headers: { Origin: 'https://admin.example.com', 'Access-Control-Request-Method': 'PATCH' },
    });
    expect(response.headers.get('Access-Control-Allow-Methods')?.split(/,\s*/)).toContain('PATCH');
  });
});
