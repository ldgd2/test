// src/app/core/services/asignacion.service.ts
import { Injectable, Inject, PLATFORM_ID } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { isPlatformBrowser } from '@angular/common';
import { Observable } from 'rxjs';
import {
  CasoDisponible,
  HistorialTecnicoItem,
  EstadoAsignacion,
} from '../models/asignacion.model';
import { environment } from '../../../environments/environment';

@Injectable({ providedIn: 'root' })
export class AsignacionService {

  private base      = `${environment.apiUrl}/asignaciones`;
  private isBrowser: boolean;

  constructor(
    private http: HttpClient,
    @Inject(PLATFORM_ID) platformId: Object
  ) {
    this.isBrowser = isPlatformBrowser(platformId);
  }

  // ✅ getter de headers con token
  private get headers(): HttpHeaders {
    const token = this.isBrowser ? localStorage.getItem('token') : '';
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }

  // ✅ Sin ID en URL — backend lee taller_id del token
  getCasosDisponibles(): Observable<CasoDisponible[]> {
    return this.http.get<CasoDisponible[]>(
      `${this.base}/disponibles`,
      { headers: this.headers }
    );
  }

  // ✅ PATCH (no POST) — backend lee usuario del token
  aceptarCaso(asignacionId: string): Observable<any> {
    return this.http.patch<any>(
      `${this.base}/${asignacionId}/aceptar`,
      {},
      { headers: this.headers }
    );
  }

  // ✅ Sin tecnicoId en URL — backend lee del token
  getHistorial(estado?: EstadoAsignacion): Observable<HistorialTecnicoItem[]> {
    let params = new HttpParams();
    if (estado) params = params.set('estado', estado);
    return this.http.get<HistorialTecnicoItem[]>(
      `${this.base}/mi-historial`,
      { headers: this.headers, params }
    );
  }

  cambiarEstado(asignacionId: string, nuevoEstado: EstadoAsignacion): Observable<any> {
    const params = new HttpParams().set('nuevo_estado', nuevoEstado);
    return this.http.patch<any>(
      `${this.base}/${asignacionId}/estado`,
      {},
      { headers: this.headers, params }
    );
  }
}