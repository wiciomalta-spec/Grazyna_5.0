import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { prisma } from '../config/database.js';

const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-change-me';
const JWT_EXPIRES_IN = '7d';

// ════════════════════════════════════════════
// Schemy walidacji
// ════════════════════════════════════════════
const loginSchema = z.object({
  email: z.string().email('Nieprawidłowy email'),
  password: z.string().min(6, 'Hasło musi mieć min. 6 znaków'),
});

const registerSchema = z.object({
  email: z.string().email('Nieprawidłowy email'),
  username: z.string().min(3, 'Username min. 3 znaki'),
  password: z.string().min(6, 'Hasło min. 6 znaków'),
  firstName: z.string().optional(),
  lastName: z.string().optional(),
});

// ════════════════════════════════════════════
// LOGIN
// ════════════════════════════════════════════
export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const validation = loginSchema.safeParse(req.body);
    if (!validation.success) {
      res.status(400).json({ error: 'Błąd walidacji', details: validation.error.errors });
      return;
    }

    const { email, password } = validation.data;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.active) {
      res.status(401).json({ error: 'Nieprawidłowy email lub hasło' });
      return;
    }

    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      res.status(401).json({ error: 'Nieprawidłowy email lub hasło' });
      return;
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLogin: new Date() }
    });

    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        firstName: user.firstName,
        lastName: user.lastName,
        role: user.role,
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Błąd serwera' });
  }
};

// ════════════════════════════════════════════
// REGISTER
// ════════════════════════════════════════════
export const register = async (req: Request, res: Response): Promise<void> => {
  try {
    const validation = registerSchema.safeParse(req.body);
    if (!validation.success) {
      res.status(400).json({ error: 'Błąd walidacji', details: validation.error.errors });
      return;
    }

    const { email, username, password, firstName, lastName } = validation.data;

    const existing = await prisma.user.findFirst({
      where: { OR: [{ email }, { username }] }
    });

    if (existing) {
      res.status(409).json({ error: 'Email lub username już istnieje' });
      return;
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        email,
        username,
        password: hashedPassword,
        firstName,
        lastName,
        role: 'OPERATOR',
      }
    });

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });

    res.status(201).json({
      success: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        role: user.role,
      }
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Błąd serwera' });
  }
};

// ════════════════════════════════════════════
// ME (current user)
// ════════════════════════════════════════════
export const me = async (req: Request & { user?: any }, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      res.status(401).json({ error: 'Wymagana autoryzacja' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        email: true,
        username: true,
        firstName: true,
        lastName: true,
        role: true,
        lastLogin: true,
        createdAt: true,
      }
    });

    res.json({ user });
  } catch (error) {
    res.status(500).json({ error: 'Błąd serwera' });
  }
};
