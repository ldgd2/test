import {
  Component, OnInit, signal,
  ChangeDetectionStrategy, ChangeDetectorRef,
  ViewChild, ElementRef,
} from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from '../../../../environments/environment';

type TabEstado = 'pendientes' | 'proceso' | 'terminados';

interface CasoHistorial {
  asignacion_id:      string;
  incidente_id:       string;
  estado:             string;
  categoria:          string;
  prioridad:          string;
  descripcion_manual: string;
  direccion_texto:    string;
  distancia_km:       number;
  precio_cotizado:    number;
  foto_evidencia:     string;
  aceptado_at:        string;
  completado_at:      string;
  created_at:         string;
  resumen_ia:         string | null;
  confianza_ia:       number | null;
  requiere_revision:  boolean | null;
  vehiculo: {
    placa:  string;
    marca:  string;
    modelo: string;
    color:  string;
  } | null;
}

interface FormCobro {
  monto_total:   number | null;
  descripcion:   string;
  metodo:        string;
  qr_imagen_url: string;
}

@Component({
  selector: 'app-historial-tecnico',
  standalone: true,
  imports: [CommonModule, DatePipe, FormsModule],
  templateUrl: './historial-tecnico.component.html',
  styleUrls:  ['./historial-tecnico.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class HistorialTecnicoComponent implements OnInit {

  // ── ViewChild para el input de QR ────────────────────────
  @ViewChild('qrInput') qrInputRef!: ElementRef<HTMLInputElement>;

  tabActiva     = signal<TabEstado>('pendientes');
  casos         = signal<CasoHistorial[]>([]);
  cargando      = signal(false);
  error         = signal<string | null>(null);
  mensaje       = signal<string | null>(null);
  cambiando     = signal<string | null>(null);

  // Modal detalle
  modalCaso     = signal<CasoHistorial | null>(null);

  // Modal cobro
  modalCobro    = signal<CasoHistorial | null>(null);
  enviandoCobro = signal(false);
  errorCobro    = signal<string | null>(null);
  qrImagenPreview = signal<string | null>(null);

  formCobro: FormCobro = {
    monto_total:   null,
    descripcion:   '',
    metodo:        'efectivo',
    qr_imagen_url: '',
  };

  readonly tabs: { id: TabEstado; label: string; icono: string }[] = [
    { id: 'pendientes', label: 'Pendientes', icono: '⏳' },
    { id: 'proceso',    label: 'En Proceso', icono: '🚗' },
    { id: 'terminados', label: 'Terminados', icono: '✅' },
  ];

  readonly metodos = [
    { valor: 'efectivo',          label: '💵 Efectivo'          },
    { valor: 'qr',                label: '📱 QR'                },
    { valor: 'transferencia',     label: '🏦 Transferencia'     },
    { valor: 'billetera_digital', label: '💳 Billetera digital' },
  ];

  constructor(private http: HttpClient, private cd: ChangeDetectorRef) {}

  ngOnInit(): void { this.cargar(); }

  private get headers(): HttpHeaders {
    const token = localStorage.getItem('token');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }

  // ── CARGAR ────────────────────────────────────────────────

  cargar(tab?: TabEstado): void {
    if (tab) this.tabActiva.set(tab);
    this.cargando.set(true);
    this.error.set(null);
    const url = `${environment.apiUrl}/asignaciones/mi-historial?estado=${this.tabActiva()}`;
    this.http.get<CasoHistorial[]>(url, { headers: this.headers }).subscribe({
      next: (data) => { this.casos.set(data); this.cargando.set(false); this.cd.markForCheck(); },
      error: ()     => { this.error.set('Error al cargar el historial.'); this.cargando.set(false); this.cd.markForCheck(); },
    });
  }

  // ── CAMBIAR ESTADO ────────────────────────────────────────

  cambiarEstado(asignacionId: string, nuevoEstado: string, nota?: string): void {
    this.cambiando.set(asignacionId);
    this.mensaje.set(null);
    this.http.patch(
      `${environment.apiUrl}/asignaciones/${asignacionId}/estado`,
      { nuevo_estado: nuevoEstado, nota: nota ?? null },
      { headers: this.headers }
    ).subscribe({
      next: (res: any) => {
        this.mensaje.set(`✅ Estado actualizado: ${res.estado}`);
        this.cambiando.set(null);
        this.cerrarModal();
        this.cargar();
        this.cd.markForCheck();
      },
      error: (err) => {
        this.error.set(err?.error?.detail ?? 'Error al cambiar estado.');
        this.cambiando.set(null);
        this.cd.markForCheck();
      },
    });
  }

  // ── MODAL COBRO ───────────────────────────────────────────

  abrirModalCobro(caso: CasoHistorial): void {
    this.formCobro = { monto_total: null, descripcion: '', metodo: 'efectivo', qr_imagen_url: '' };
    this.qrImagenPreview.set(null);
    this.errorCobro.set(null);
    this.modalCobro.set(caso);
  }

  cerrarModalCobro(): void {
    this.modalCobro.set(null);
    this.qrImagenPreview.set(null);
  }

  // ── QR DESDE GALERÍA ──────────────────────────────────────

  abrirGaleriaQR(): void {
    this.qrInputRef.nativeElement.click();
  }

  onQrImagenSeleccionada(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input.files?.length) return;

    const file   = input.files[0];
    const reader = new FileReader();

    reader.onload = () => {
      const base64 = reader.result as string;
      this.qrImagenPreview.set(base64);
      this.formCobro.qr_imagen_url = base64;
      this.cd.markForCheck();
    };
    reader.readAsDataURL(file);
  }

  quitarQR(): void {
    this.qrImagenPreview.set(null);
    this.formCobro.qr_imagen_url = '';
    if (this.qrInputRef?.nativeElement) {
      this.qrInputRef.nativeElement.value = '';
    }
  }

  // ── ENVIAR COBRO ──────────────────────────────────────────

  enviarCobro(): void {
    const caso = this.modalCobro();
    if (!caso) return;

    if (!this.formCobro.monto_total || this.formCobro.monto_total <= 0) {
      this.errorCobro.set('Ingresa un monto válido mayor a 0.'); return;
    }
    if (!this.formCobro.descripcion.trim()) {
      this.errorCobro.set('Ingresa una descripción del servicio.'); return;
    }
    if (this.formCobro.metodo === 'qr' && !this.formCobro.qr_imagen_url) {
      this.errorCobro.set('Selecciona una imagen QR de tu galería.'); return;
    }

    this.enviandoCobro.set(true);
    this.errorCobro.set(null);

    const body = {
      asignacion_id: caso.asignacion_id,
      monto_total:   this.formCobro.monto_total,
      descripcion:   this.formCobro.descripcion,
      metodo:        this.formCobro.metodo,
      qr_imagen_url: this.formCobro.metodo === 'qr' ? this.formCobro.qr_imagen_url : null,
    };

    this.http.post(`${environment.apiUrl}/pagos/cobrar`, body, { headers: this.headers })
      .subscribe({
        next: () => {
          this.enviandoCobro.set(false);
          this.cerrarModalCobro();
          this.mensaje.set('✅ Cobro enviado al cliente correctamente.');
          this.cargar();
          this.cd.markForCheck();
        },
        error: (err) => {
          this.errorCobro.set(err?.error?.detail ?? 'Error al enviar el cobro.');
          this.enviandoCobro.set(false);
          this.cd.markForCheck();
        },
      });
  }

  // ── MODAL DETALLE ─────────────────────────────────────────

  abrirModal(caso: CasoHistorial): void { this.modalCaso.set(caso); }
  cerrarModal(): void                    { this.modalCaso.set(null); }

  // ── HELPERS ───────────────────────────────────────────────

  mostrarBotonCobro(caso: CasoHistorial): boolean {
    return this.tabActiva() === 'terminados' && caso.estado === 'completada';
  }

  prioridadClass(p?: string): string {
    return ({ critica: 'badge--critica', alta: 'badge--alta', media: 'badge--media', baja: 'badge--baja' })[p ?? ''] ?? 'badge--media';
  }

  estadoClass(e: string): string {
    return ({ aceptada: 'estado--aceptada', en_camino: 'estado--proceso', completada: 'estado--completada', cancelada: 'estado--cancelada' })[e] ?? '';
  }

  estadoLabel(e: string): string {
    return ({ aceptada: '⏳ Aceptado', en_camino: '🚗 En camino', completada: '✅ Completado', cancelada: '❌ Cancelado' })[e] ?? e;
  }

  getFotoUrl(ruta?: string): string {
    if (!ruta) return '';
    return ruta.startsWith('http') ? ruta : `${environment.apiBase}/${ruta.replace(/\\/g, '/')}`;
  }

  accionesPosibles(estado: string): { label: string; estado: string; clase: string }[] {
    if (estado === 'aceptada')  return [
      { label: '🚗 Ir en camino',      estado: 'en_camino',  clase: 'btn-proceso'   },
      { label: '❌ Cancelar',           estado: 'cancelada',  clase: 'btn-cancelar'  },
    ];
    if (estado === 'en_camino') return [
      { label: '✅ Marcar completado', estado: 'completada', clase: 'btn-completar' },
      { label: '❌ Cancelar',          estado: 'cancelada',  clase: 'btn-cancelar'  },
    ];
    return [];
  }
}