import { Injectable, Inject, PLATFORM_ID } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { isPlatformBrowser } from '@angular/common';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Vehiculo {
  id: string;
  usuario_id: string;
  placa: string;
  marca: string;
  modelo: string;
  anio: number;
  color: string | null;
  combustible: string;
  foto_url: string | null;
  activo: boolean;
}

export interface VehiculoCreate {
  placa: string;
  marca: string;
  modelo: string;
  anio: number;
  color?: string;
  combustible: string;
}

@Injectable({ providedIn: 'root' })
export class VehiculoService {

  private API = `${environment.apiUrl}/vehiculos`;
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

  getMisVehiculos(): Observable<Vehiculo[]> {
    return this.http.get<Vehiculo[]>(`${this.API}/mis-vehiculos`, { headers: this.headers });
  }

  crear(data: VehiculoCreate): Observable<Vehiculo> {
    return this.http.post<Vehiculo>(this.API, data, { headers: this.headers });
  }

  actualizar(id: string, data: Partial<VehiculoCreate>): Observable<Vehiculo> {
    return this.http.put<Vehiculo>(`${this.API}/${id}`, data, { headers: this.headers });
  }

  eliminar(id: string): Observable<any> {
    return this.http.delete(`${this.API}/${id}`, { headers: this.headers });
  }

  subirFoto(id: string, foto: File): Observable<any> {
  const formData = new FormData();
  formData.append('foto', foto, foto.name);
  
  // ← headers SOLO con Authorization, sin Content-Type
  // El browser setea automáticamente multipart/form-data con el boundary correcto
  const token = this.isBrowser ? localStorage.getItem('token') : '';
  const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
  
  return this.http.post(`${this.API}/${id}/foto`, formData, { headers });
}
}