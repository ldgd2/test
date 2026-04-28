import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../../environments/environment';

export interface UsuarioOut {
  id: string;
  nombres: string;
  apellidos: string;
  email: string;
  telefono: string | null;
  tipo: string;
  activo: boolean;
  foto_perfil_url: string | null;
  taller_id: string | null;  // ← necesario para técnicos
}

interface LoginResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  usuario: UsuarioOut;
}

interface RegistroPayload {
  nombres: string;
  apellidos: string;
  email: string;
  telefono?: string;
  password: string;
  tipo: string;
  taller_id?: string;  // ← al registrar un técnico
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private API_URL = `${environment.apiUrl}/usuarios`;

  constructor(private http: HttpClient) {}

  registro(data: RegistroPayload): Observable<UsuarioOut> {
    return this.http.post<UsuarioOut>(`${this.API_URL}/registro`, data);
  }

  login(email: string, password: string): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${this.API_URL}/login`, { email, password });
  }

  saveSession(res: LoginResponse) {
    localStorage.setItem('token',         res.access_token);
    localStorage.setItem('refresh_token', res.refresh_token);
    localStorage.setItem('rol',           res.usuario.tipo);
    localStorage.setItem('usuario',       JSON.stringify(res.usuario));
  }

  setUsuario(usuario: UsuarioOut) {
    localStorage.setItem('usuario', JSON.stringify(usuario));
  }

  logout()                    { localStorage.clear(); }
  getToken(): string | null   { return localStorage.getItem('token'); }
  getRol(): string | null     { return localStorage.getItem('rol'); }
  isLoggedIn(): boolean       { return !!this.getToken(); }

  getUsuario(): UsuarioOut | null {
    const u = localStorage.getItem('usuario');
    return u ? JSON.parse(u) : null;
  }
}