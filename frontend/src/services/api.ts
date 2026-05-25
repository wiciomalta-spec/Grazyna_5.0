/**
 * GRAŻYNA 5.0 - API Service
 * Klient HTTP z interceptorami i automatycznym tokenem JWT
 */

import axios, { AxiosInstance, AxiosError } from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001/api';

class ApiService {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: API_URL,
      timeout: 10000,
      headers: { 'Content-Type': 'application/json' }
    });

    // Request interceptor - dodaj token JWT
    this.client.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('grazyna_token');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor - obsługa błędów
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        if (error.response?.status === 401) {
          localStorage.removeItem('grazyna_token');
          window.location.href = '/login';
        }
        return Promise.reject(error);
      }
    );
  }

  // ════════════════════════════════════════════
  // Auth
  // ════════════════════════════════════════════
  async login(email: string, password: string) {
    const { data } = await this.client.post('/auth/login', { email, password });
    if (data.token) {
      localStorage.setItem('grazyna_token', data.token);
    }
    return data;
  }

  async register(payload: { email: string; username: string; password: string }) {
    const { data } = await this.client.post('/auth/register', payload);
    if (data.token) {
      localStorage.setItem('grazyna_token', data.token);
    }
    return data;
  }

  async getCurrentUser() {
    const { data } = await this.client.get('/auth/me');
    return data;
  }

  logout() {
    localStorage.removeItem('grazyna_token');
    window.location.href = '/login';
  }

  // ════════════════════════════════════════════
  // Vehicles
  // ════════════════════════════════════════════
  async getVehicles(params?: { status?: string; type?: string }) {
    const { data } = await this.client.get('/vehicles', { params });
    return data;
  }

  async getVehicle(id: string) {
    const { data } = await this.client.get(`/vehicles/${id}`);
    return data;
  }

  async createVehicle(payload: any) {
    const { data } = await this.client.post('/vehicles', payload);
    return data;
  }

  async updateVehicle(id: string, payload: any) {
    const { data } = await this.client.patch(`/vehicles/${id}`, payload);
    return data;
  }

  async deleteVehicle(id: string) {
    const { data } = await this.client.delete(`/vehicles/${id}`);
    return data;
  }

  async getVehicleStats() {
    const { data } = await this.client.get('/vehicles/stats/summary');
    return data;
  }

  // ════════════════════════════════════════════
  // System
  // ════════════════════════════════════════════
  async getHealth() {
    const { data } = await this.client.get('/health');
    return data;
  }

  async getStatus() {
    const { data } = await this.client.get('/status');
    return data;
  }

  async getKernelProfile() {
    const { data } = await this.client.get('/kernel/profile');
    return data;
  }

  async getKernelBlueprint() {
    const { data } = await this.client.get('/kernel/blueprint');
    return data;
  }

  async getKernelDrivers() {
    const { data } = await this.client.get('/kernel/drivers');
    return data;
  }

  async adaptKernel(payload: { mode?: string }) {
    const { data } = await this.client.post('/kernel/adapt', payload);
    return data;
  }
}

export const api = new ApiService();
export default api;
