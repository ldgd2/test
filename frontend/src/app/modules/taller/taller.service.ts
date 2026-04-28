import { Injectable, Inject, PLATFORM_ID } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { isPlatformBrowser } from '@angular/common';
import { Observable } from 'rxjs';
import { environment } from '../../../../environments/environment';

// ── INTERFACES ────────────────────────────────────────────────────────────────

export interface Taller {
  id:                string;
  nombre:            string;
  email:             string;
  telefono:          string | null;
  direccion:         string | null;
  radio_servicio_km: number | null;
  logo_url:          string | null;
  descripcion:       string | null;
  activo:            boolean;
  verificado:        boolean;
  comision_pct:      number;
  latitud:           number | null;
  longitud:          number | null;
}

export interface TallerCreate {
  nombre:             string;
  email:              string;
  password:           string;
  telefono?:          string;
  direccion?:         string;
  radio_servicio_km?: number;
  descripcion?:       string;
  latitud?:           number | null;
  longitud?:          number | null;
}

export interface TallerUpdate {
  nombre?:            string;
  telefono?:          string;
  direccion?:         string;
  radio_servicio_km?: number;
  descripcion?:       string;
  latitud?:           number | null;
  longitud?:          number | null;
  activo?:            boolean;
}

@Injectable({ providedIn: 'root' })
export class TallerService {

  // ✅ URL base correcta: sin /registro al final para evitar duplicación
  private API = `${environment.apiUrl}/talleres`;
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

  // ── REGISTRO Y PERFIL ─────────────────────────────────────────────────────

  // ✅ Resuelve a: POST /api/talleres/registro
  registrar(data: TallerCreate): Observable<Taller> {
    return this.http.post<Taller>(`${this.API}/registro`, data);
  }

  // GET /api/talleres/mi-taller/:id
  obtener(tallerId: string): Observable<Taller> {
    return this.http.get<Taller>(`${this.API}/mi-taller/${tallerId}`, { headers: this.headers });
  }

  // PUT /api/talleres/mi-taller/:id
  actualizar(tallerId: string, data: TallerUpdate): Observable<Taller> {
    return this.http.put<Taller>(`${this.API}/mi-taller/${tallerId}`, data, { headers: this.headers });
  }

  // POST /api/talleres/mi-taller/:id/logo
  subirLogo(tallerId: string, logo: File): Observable<any> {
    const formData = new FormData();
    formData.append('logo', logo, logo.name);
    return this.http.post(`${this.API}/mi-taller/${tallerId}/logo`, formData, { headers: this.headers });
  }

  // ── RUTAS PÚBLICAS ────────────────────────────────────────────────────────

  // GET /api/talleres/activos
  listarActivos(): Observable<Taller[]> {
    return this.http.get<Taller[]>(`${this.API}/activos`);
  }

  // GET /api/talleres/cercanos?lat=...&lon=...&radio=...
  listarCercanos(lat: number, lon: number, radio: number = 10): Observable<Taller[]> {
    const params = new HttpParams()
      .set('lat', lat.toString())
      .set('lon', lon.toString())
      .set('radio', radio.toString());
    return this.http.get<Taller[]>(`${this.API}/cercanos`, { params });
  }

  // ── ADMIN ─────────────────────────────────────────────────────────────────

  // GET /api/talleres/
  listarTodos(): Observable<Taller[]> {
    return this.http.get<Taller[]>(`${this.API}/`, { headers: this.headers });
  }

  // PATCH /api/talleres/:id/estado?activo=true|false
  cambiarEstado(tallerId: string, activo: boolean): Observable<Taller> {
    const params = new HttpParams().set('activo', activo.toString());
    return this.http.patch<Taller>(`${this.API}/${tallerId}/estado`, {}, {
      headers: this.headers,
      params
    });
  }

  // POST /api/talleres/:id/verificar
  verificar(tallerId: string): Observable<Taller> {
    return this.http.post<Taller>(`${this.API}/${tallerId}/verificar`, {}, { headers: this.headers });
  }
}