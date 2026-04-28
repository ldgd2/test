import {
  Component, OnInit, OnDestroy, signal, computed,
  ChangeDetectionStrategy, ChangeDetectorRef, NgZone,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import * as L from 'leaflet';

import { AsignacionService } from '../../../core/services/asignacion.service';
import { AuthService }       from '../../../core/services/auth.service';
import { CasoDisponible, EstadoAsignacion } from '../../../core/models/asignacion.model';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-atender',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './atender.component.html',
  styleUrls:  ['./atender.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AtenderComponent implements OnInit, OnDestroy {

  // ── LISTA DE CASOS ──────────────────────────────────────────────────────
  casos          = signal<CasoDisponible[]>([]);
  cargando       = signal(false);
  error          = signal<string | null>(null);
  mensaje        = signal<string | null>(null);
  aceptando      = signal<string | null>(null);
  filtroCategoria = signal<string>('');

  casosFiltrados = computed(() => {
    const f = this.filtroCategoria();
    return f ? this.casos().filter(c => c.categoria === f) : this.casos();
  });

  categorias = computed(() =>
    [...new Set(this.casos().map(c => c.categoria ?? 'otro'))]
  );

  // ── MODAL DE DETALLE ────────────────────────────────────────────────────
  modalAbierto   = signal(false);
  detalleCaso    = signal<any>(null);
  cargandoDetalle = signal(false);
  private modalMap?: L.Map;

  constructor(
    private svc:  AsignacionService,
    private auth: AuthService,
    private http: HttpClient,
    private cd:   ChangeDetectorRef,
    private zone: NgZone,
  ) {}

  ngOnInit(): void { this.cargar(); }

  ngOnDestroy(): void { this.destruirMapa(); }

  // ── CARGAR CASOS ────────────────────────────────────────────────────────

  cargar(): void {
    this.cargando.set(true);
    this.error.set(null);
    this.mensaje.set(null);

    this.svc.getCasosDisponibles().subscribe({
      next: (data) => {
        this.casos.set(data);
        this.cargando.set(false);
        this.cd.markForCheck();
      },
      error: (err) => {
        this.error.set(
          err.status === 400
            ? 'Aún no tienes un taller registrado. Ve a "Mi Taller" para crearlo.'
            : 'Error al cargar casos. Intenta cerrar sesión y volver a entrar.'
        );
        this.cargando.set(false);
        this.cd.markForCheck();
      },
    });
  }

  // ── ACEPTAR CASO ────────────────────────────────────────────────────────

  aceptar(asignacionId: string): void {
    this.aceptando.set(asignacionId);
    this.mensaje.set(null);
    this.error.set(null);

    this.svc.aceptarCaso(asignacionId).subscribe({
      next: () => {
        this.mensaje.set('✅ Caso aceptado. Ya aparece en tu historial.');
        this.casos.update(l => l.filter(c => c.asignacion_id !== asignacionId));
        this.aceptando.set(null);
        this.cerrarModal();
        this.cd.markForCheck();
      },
      error: (err) => {
        this.error.set(
          err.status === 409
            ? '⚠️ Ya fue tomado por otro técnico.'
            : 'Error al aceptar. Intenta de nuevo.'
        );
        this.aceptando.set(null);
        this.cd.markForCheck();
      },
    });
  }

  // ── MODAL: ABRIR DETALLE ────────────────────────────────────────────────

  verDetalle(caso: CasoDisponible): void {
    this.modalAbierto.set(true);
    this.detalleCaso.set(null);
    this.cargandoDetalle.set(true);
    this.cd.markForCheck();

    const token   = localStorage.getItem('token');
    const headers = new HttpHeaders({ Authorization: `Bearer ${token}` });

    this.http.get<any>(
      `${environment.apiUrl}/incidentes/${caso.incidente_id}/detalle`,
      { headers }
    ).subscribe({
      next: (detalle) => {
        // Enriquecer con datos que ya tenemos en la tarjeta
        detalle.asignacion_id = caso.asignacion_id;
        detalle.distancia_km  = detalle.distancia_km ?? caso.distancia_km;
        this.detalleCaso.set(detalle);
        this.cargandoDetalle.set(false);
        this.cd.markForCheck();

        // Iniciar mapa si hay ubicación
        if (detalle.ubicacion) {
          setTimeout(() => this.initModalMap(detalle.ubicacion), 200);
        }
      },
      error: () => {
        this.cargandoDetalle.set(false);
        this.cd.markForCheck();
      }
    });
  }

  cerrarModal(): void {
    this.destruirMapa();
    this.modalAbierto.set(false);
    this.detalleCaso.set(null);
  }

  // ── MAPA DEL MODAL ──────────────────────────────────────────────────────

  private initModalMap(ubicacion: string): void {
    this.destruirMapa();

    const partes = ubicacion.split(',');
    if (partes.length < 2) return;

    const lat = parseFloat(partes[0].trim());
    const lng = parseFloat(partes[1].trim());
    if (isNaN(lat) || isNaN(lng)) return;

    this.zone.runOutsideAngular(() => {
      const mapEl = document.getElementById('modal-map');
      if (!mapEl) return;

      this.modalMap = L.map('modal-map', { zoomControl: true }).setView([lat, lng], 15);

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap'
      }).addTo(this.modalMap);

      const clienteIcon = L.icon({
        iconUrl:    'https://cdn-icons-png.flaticon.com/512/684/684908.png',
        iconSize:   [38, 38],
        iconAnchor: [19, 38],
        popupAnchor:[0, -38]
      });

      L.marker([lat, lng], { icon: clienteIcon })
        .addTo(this.modalMap)
        .bindPopup('📍 Ubicación del cliente')
        .openPopup();
    });
  }

  private destruirMapa(): void {
    if (this.modalMap) {
      this.modalMap.remove();
      this.modalMap = undefined;
    }
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────

  setFiltro(cat: string): void {
    this.filtroCategoria.set(cat === this.filtroCategoria() ? '' : cat);
  }

  prioridadClass(p?: string): string {
    const map: Record<string, string> = {
      critica: 'badge--critica',
      alta:    'badge--alta',
      media:   'badge--media',
      baja:    'badge--baja',
    };
    return map[p ?? ''] ?? 'badge--media';
  }

  getFotoUrl(ruta?: string): string {
    if (!ruta) return '';
    if (ruta.startsWith('http')) return ruta;
    return `${environment.apiBase}/${ruta.replace(/\\/g, '/')}`;
  }

  trackById(_: number, c: CasoDisponible): string {
    return c.asignacion_id;
  }
}