import { Injectable, Inject, PLATFORM_ID } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { isPlatformBrowser } from '@angular/common';
import { Observable } from 'rxjs';
import { environment } from '../../../../environments/environment';

// El backend devuelve descripcion_manual, no descripcion
// Actualiza la interfaz:

export interface Incidente {
  id:                 string;
  descripcion_manual: string | null;   // ← campo real del backend
  descripcion?:       string;          // ← alias para compatibilidad
  ubicacion?:         string | null;
  direccion_texto?:   string | null;
  categoria:          string;
  prioridad:          string;
  estado:             string;
  created_at:         string;
  vehiculo?: {
    marca:   string;
    modelo:  string;
    anio:    number;
    placa:   string;
    color?:  string | null;
  };
  cliente?: {
    nombres:   string;
    apellidos: string;
    email:     string;
    telefono?: string | null;
  };
}

export interface AceptarPayload {
  incidente_id:        string | number;
  taller_id:           string;
  precio_cotizado:     number;
  tiempo_estimado_min: number;
  nota_taller?:        string;
}

@Injectable({ providedIn: 'root' })
export class IncidenteService {

  private API = environment.apiUrl;
  private isBrowser: boolean;

  constructor(
    private http: HttpClient,
    @Inject(PLATFORM_ID) platformId: Object
  ) {
    this.isBrowser = isPlatformBrowser(platformId);
  }

  private get headers(): HttpHeaders {
    const token = this.isBrowser ? localStorage.getItem('token') : '';
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  // ── Cliente ───────────────────────────────────────────────────────
  crearIncidente(incidente: any): Observable<any> {
    return this.http.post(
      `${this.API}/incidentes/`,
      incidente,
      { headers: this.headers }
    );
  }

  getIncidentesPendientes(): Observable<any[]> {
    return this.http.get<any[]>(
      `${this.API}/incidentes/pendientes`,
      { headers: this.headers }
    );
  }

  // ── Técnico ───────────────────────────────────────────────────────
  getDisponibles(): Observable<Incidente[]> {
    return this.http.get<Incidente[]>(
      `${this.API}/asignaciones/disponibles`,
      { headers: this.headers }  // ← faltaba el token
    );
  }

  aceptarIncidente(data: AceptarPayload): Observable<any> {
    return this.http.post(
      `${this.API}/asignaciones/`,  // ← faltaba la / al final
      data,
      { headers: this.headers }    // ← faltaba el token
    );
  }
  
}