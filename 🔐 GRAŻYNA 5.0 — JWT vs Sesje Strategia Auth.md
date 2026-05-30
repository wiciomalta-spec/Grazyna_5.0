# 🔐 GRAŻYNA 5.0 — JWT vs Sesje: Strategia Auth

## Twój aktualny stan
```
✅ Rejestracja działa
✅ JWT zaimplementowany (jsonwebtoken 9.0)
✅ bcrypt dla haseł
✅ Worker Threads dla bcrypt (nie blokuje EL)
Schema: User + Session + RefreshToken (zoptymalizowana)
```

---

## Porównanie JWT vs Sesje

| Kryterium | JWT (aktualny) | Sesje (alternatywa) |
|---|---|---|
| **Przechowywanie** | Klient (localStorage/cookie) | Serwer (DB/Redis) |
| **Skalowalność** | ✅ Stateless — każdy serwer weryfikuje | ❌ Wymaga shared store (Redis) |
| **Revokacja** | ❌ Trudna (do wygaśnięcia) | ✅ Natychmiastowa (usuń z DB) |
| **Rozmiar** | ⚠️ ~500B per request | ✅ ~32B (session ID) |
| **Cluster mode** | ✅ Działa bez Redis | ❌ Wymaga Redis |
| **Bezpieczeństwo** | ⚠️ XSS jeśli localStorage | ✅ HttpOnly cookie |
| **Offline support** | ✅ Tak | ❌ Nie |
| **Twój Redis** | Opcjonalny | Wymagany |
| **Dla GRAŻYNA** | ✅ **LEPSZY** (cluster mode) | ⚠️ Wymaga Redis zawsze |

---

## Rekomendacja: JWT + Refresh Token (hybrydowa)

```
Access Token:  JWT, 15 minut, w pamięci (nie localStorage!)
Refresh Token: opaque string, 7 dni, HttpOnly cookie + DB
```

### Implementacja w GRAŻYNA 5.0

```typescript
// backend/src/controllers/auth.controller.ts

import jwt from 'jsonwebtoken';
import { hashPassword, comparePassword } from '../worker-pool';
import { getPrisma } from '../config/database';

const ACCESS_TOKEN_TTL  = '15m';
const REFRESH_TOKEN_TTL = '7d';
const JWT_SECRET        = process.env.JWT_SECRET || 'grazyna_secret_2026';

// ── GENERUJ TOKENY ────────────────────────────────────────
function generateTokens(userId: string, role: string) {
  const accessToken = jwt.sign(
    { sub: userId, role, type: 'access' },
    JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_TTL, issuer: 'grazyna-5.0' }
  );

  const refreshToken = crypto.randomUUID() + '-' + crypto.randomUUID();

  return { accessToken, refreshToken };
}

// ── REJESTRACJA ───────────────────────────────────────────
export async function register(req: Request, res: Response) {
  const { email, username, password, firstName, lastName } = req.body;
  const prisma = getPrisma();

  try {
    // Sprawdź czy użytkownik istnieje
    const existing = await prisma.user.findFirst({
      where: { OR: [{ email }, { username }] }
    });
    if (existing) {
      return res.status(409).json({
        error: 'Użytkownik już istnieje',
        field: existing.email === email ? 'email' : 'username'
      });
    }

    // Hash hasła w Worker Thread (nie blokuje EL!)
    const passwordHash = await hashPassword(password, 12);

    // Utwórz użytkownika
    const user = await prisma.user.create({
      data: { email, username, passwordHash, firstName, lastName, role: 'OPERATOR' },
      select: { id: true, email: true, username: true, role: true, createdAt: true }
    });

    // Generuj tokeny
    const { accessToken, refreshToken } = generateTokens(user.id, user.role);

    // Zapisz refresh token w DB
    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      }
    });

    // Refresh token w HttpOnly cookie (bezpieczniejszy niż localStorage)
    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000
    });

    res.status(201).json({ user, token: accessToken });

  } catch (err: any) {
    console.error('[Auth] Register error:', err.message);
    res.status(500).json({ error: 'Błąd serwera' });
  }
}

// ── LOGOWANIE ─────────────────────────────────────────────
export async function login(req: Request, res: Response) {
  const { email, password } = req.body;
  const prisma = getPrisma();

  try {
    const user = await prisma.user.findUnique({
      where: { email },
      select: { id: true, email: true, username: true, role: true, passwordHash: true, active: true }
    });

    if (!user || !user.active) {
      return res.status(401).json({ error: 'Nieprawidłowe dane logowania' });
    }

    // Porównaj hasło w Worker Thread
    const valid = await comparePassword(password, user.passwordHash);
    if (!valid) {
      return res.status(401).json({ error: 'Nieprawidłowe dane logowania' });
    }

    // Aktualizuj lastLoginAt
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() }
    });

    const { accessToken, refreshToken } = generateTokens(user.id, user.role);

    // Zapisz refresh token
    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      }
    });

    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000
    });

    const { passwordHash: _, ...userSafe } = user;
    res.json({ user: userSafe, token: accessToken });

  } catch (err: any) {
    console.error('[Auth] Login error:', err.message);
    res.status(500).json({ error: 'Błąd serwera' });
  }
}

// ── REFRESH TOKEN ─────────────────────────────────────────
export async function refreshAccessToken(req: Request, res: Response) {
  const refreshToken = req.cookies?.refreshToken || req.body?.refreshToken;
  if (!refreshToken) return res.status(401).json({ error: 'Brak refresh token' });

  const prisma = getPrisma();

  try {
    const stored = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: { user: { select: { id: true, role: true, active: true } } }
    });

    if (!stored || stored.used || stored.expiresAt < new Date() || !stored.user.active) {
      return res.status(401).json({ error: 'Nieprawidłowy refresh token' });
    }

    // Oznacz stary token jako użyty (rotation)
    await prisma.refreshToken.update({
      where: { id: stored.id },
      data: { used: true }
    });

    // Generuj nowe tokeny
    const { accessToken, refreshToken: newRefresh } = generateTokens(stored.user.id, stored.user.role);

    await prisma.refreshToken.create({
      data: {
        userId: stored.user.id,
        token: newRefresh,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      }
    });

    res.cookie('refreshToken', newRefresh, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000
    });

    res.json({ token: accessToken });

  } catch (err: any) {
    res.status(500).json({ error: 'Błąd serwera' });
  }
}

// ── WYLOGOWANIE ───────────────────────────────────────────
export async function logout(req: Request, res: Response) {
  const refreshToken = req.cookies?.refreshToken;
  const prisma = getPrisma();

  if (refreshToken) {
    await prisma.refreshToken.updateMany({
      where: { token: refreshToken },
      data: { used: true }
    }).catch(() => {});
  }

  res.clearCookie('refreshToken');
  res.json({ message: 'Wylogowano pomyślnie' });
}
```

---

## Middleware JWT (zaktualizowany)

```typescript
// backend/src/middleware/auth.ts
import jwt from 'jsonwebtoken';

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Brak tokenu autoryzacji' });
  }

  const token = authHeader.slice(7);
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET || 'grazyna_secret_2026') as any;
    if (payload.type !== 'access') throw new Error('Wrong token type');
    req.user = { id: payload.sub, role: payload.role };
    next();
  } catch (err: any) {
    const msg = err.name === 'TokenExpiredError' ? 'Token wygasł' : 'Nieprawidłowy token';
    res.status(401).json({ error: msg });
  }
}

export function requireRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!roles.includes(req.user?.role)) {
      return res.status(403).json({ error: 'Brak uprawnień' });
    }
    next();
  };
}
```

---

## Endpointy Auth (dodaj do routes)

```typescript
// POST /api/auth/register  → rejestracja
// POST /api/auth/login     → logowanie
// POST /api/auth/refresh   → odśwież access token
// POST /api/auth/logout    → wylogowanie
// GET  /api/auth/me        → dane zalogowanego użytkownika
```