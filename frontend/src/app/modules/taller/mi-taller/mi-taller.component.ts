import { Component, OnInit, AfterViewInit, NgZone } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import * as L from 'leaflet';
import { TallerService, TallerCreate, TallerUpdate } from '../taller.service';
import { AuthService } from '../../../core/services/auth.service';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-mi-taller',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './mi-taller.html',
  styleUrls: ['./mi-taller.css']
})
export class MiTallerComponent implements OnInit, AfterViewInit {

  tallerForm!: FormGroup;
  isLoading   = false;
  errorMsg    = '';
  successMsg  = '';
  logoPreview: string | null = null;
  logoFile:   File | null    = null;
  geoLocating = false;

  tallerExistente: any = null;
  modoEdicion          = false;

  private map!:    L.Map;
  private marker!: L.Marker;

  private readonly DEFAULT_LAT = -17.7833;
  private readonly DEFAULT_LNG = -63.1821;

  private tallerIcon = L.icon({
    iconUrl:    'https://cdn-icons-png.flaticon.com/512/3233/3233997.png',
    iconSize:   [42, 42],
    iconAnchor: [21, 42],
    popupAnchor:[0, -42]
  });

  constructor(
    private fb:            FormBuilder,
    private zone:          NgZone,
    private tallerService: TallerService,
    private auth:          AuthService,
    private http:          HttpClient,
  ) {}

  // ── LIFECYCLE ────────────────────────────────────────────────────────────

  ngOnInit(): void {
    this.buildForm();
    const usuario = this.auth.getUsuario();
    if (usuario?.taller_id) {
      this.cargarTallerExistente(usuario.taller_id);
    } else {
      this.verificarTallerEnBackend();
    }
  }

  ngAfterViewInit(): void {
    setTimeout(() => this.initMap(), 100);
  }

  // ── FORM ─────────────────────────────────────────────────────────────────

  buildForm(data?: any): void {
    this.tallerForm = this.fb.group({
      nombre:            [data?.nombre            ?? '', [Validators.required, Validators.minLength(3)]],
      email:             [data?.email             ?? '', [Validators.required, Validators.email]],
      password:          ['',                            [Validators.minLength(8)]],
      telefono:          [data?.telefono          ?? ''],
      direccion:         [data?.direccion         ?? ''],
      radio_servicio_km: [data?.radio_servicio_km ?? 10, [Validators.required, Validators.min(1), Validators.max(100)]],
      descripcion:       [data?.descripcion       ?? ''],
      latitud:           [data?.latitud           ?? this.DEFAULT_LAT, [Validators.required]],
      longitud:          [data?.longitud          ?? this.DEFAULT_LNG,  [Validators.required]]
    });
  }

  // ── VERIFICAR TALLER EN BACKEND ──────────────────────────────────────────

  verificarTallerEnBackend(): void {
    const token = this.auth.getToken();
    if (!token) return;

    const headers = new HttpHeaders({ Authorization: `Bearer ${token}` });
    this.http.get<any>(`${environment.apiUrl}/usuarios/me`, { headers })
      .subscribe({
        next: (usuario) => {
          if (usuario.taller_id) {
            const usuarioLocal = this.auth.getUsuario();
            if (usuarioLocal) {
              usuarioLocal.taller_id = usuario.taller_id;
              this.auth.setUsuario(usuarioLocal);
            }
            this.cargarTallerExistente(usuario.taller_id);
          }
        },
        error: () => {}
      });
  }

  // ── CARGAR TALLER EXISTENTE ──────────────────────────────────────────────

  cargarTallerExistente(tallerId: string): void {
    this.isLoading = true;
    this.tallerService.obtener(tallerId).subscribe({
      next: (taller) => {
        this.tallerExistente = taller;
        this.logoPreview     = taller.logo_url ?? null;
        this.buildForm(taller);
        this.deshabilitarCamposVista();
        this.modoEdicion = false;
        this.isLoading   = false;

        if (taller.latitud && taller.longitud) {
          this.moverMarcador(taller.latitud, taller.longitud);
        }
      },
      error: (err) => {
        console.error('Error cargando taller:', err);
        this.tallerExistente = null;
        this.isLoading       = false;
        if (err.status === 405 || err.status === 404) {
          this.errorMsg = 'No se pudo cargar el taller. Intenta cerrar sesión y volver a entrar.';
        }
      }
    });
  }

  // ── CONTROL EDICIÓN ──────────────────────────────────────────────────────

  activarEdicion(): void {
    this.modoEdicion = true;
    this.successMsg  = '';
    this.errorMsg    = '';
    this.habilitarCamposEdicion();
  }

  cancelarEdicion(): void {
    this.modoEdicion = false;
    this.errorMsg    = '';
    this.buildForm(this.tallerExistente);
    this.deshabilitarCamposVista();
    if (this.tallerExistente?.latitud && this.tallerExistente?.longitud) {
      this.moverMarcador(this.tallerExistente.latitud, this.tallerExistente.longitud);
    }
  }

  private deshabilitarCamposVista(): void {
    ['nombre','email','telefono','direccion','radio_servicio_km','descripcion','password']
      .forEach(c => this.tallerForm.get(c)?.disable());
  }

  private habilitarCamposEdicion(): void {
    ['nombre','telefono','direccion','radio_servicio_km','descripcion','password']
      .forEach(c => this.tallerForm.get(c)?.enable());
    this.tallerForm.get('email')?.disable();
  }

  private mostrarExito(msg: string): void {
    this.successMsg = msg;
    this.errorMsg   = '';
    window.scrollTo({ top: 0, behavior: 'smooth' });
    setTimeout(() => { this.successMsg = ''; }, 4000);
  }

  private mostrarError(msg: string): void {
    this.errorMsg   = msg;
    this.successMsg = '';
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  // ── GEOLOCALIZACIÓN ──────────────────────────────────────────────────────

  usarUbicacionActual(): void {
    if (!navigator.geolocation) {
      this.mostrarError('Tu navegador no soporta geolocalización.');
      return;
    }

    this.geoLocating = true;
    this.errorMsg    = '';

    navigator.geolocation.getCurrentPosition(
      (position) => {
        this.zone.run(() => {
          const lat = parseFloat(position.coords.latitude.toFixed(6));
          const lng = parseFloat(position.coords.longitude.toFixed(6));
          this.updateCoords(lat, lng);
          this.moverMarcador(lat, lng);
          this.geoLocating = false;
        });
      },
      (error) => {
        this.zone.run(() => {
          this.geoLocating = false;
          switch (error.code) {
            case error.PERMISSION_DENIED:
              this.mostrarError('❌ Permiso de ubicación denegado. Actívalo en tu navegador.');
              break;
            case error.POSITION_UNAVAILABLE:
              this.mostrarError('❌ Ubicación no disponible en este momento.');
              break;
            default:
              this.mostrarError('❌ No se pudo obtener la ubicación.');
          }
        });
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }

  // ── SUBMIT ───────────────────────────────────────────────────────────────

  onSubmit(): void {
    if (this.tallerForm.invalid) {
      this.tallerForm.markAllAsTouched();
      return;
    }

    this.isLoading  = true;
    this.errorMsg   = '';
    this.successMsg = '';

    if (this.tieneTaller) {
      this.actualizarTaller();
    } else {
      this.crearTaller();
    }
  }

  private actualizarTaller(): void {
    const rawValue = this.tallerForm.getRawValue();
    if (!rawValue.password) delete rawValue.password;
    const payload: TallerUpdate = rawValue;

    this.tallerService.actualizar(this.tallerExistente.id, payload).subscribe({
      next: (taller) => {
        this.tallerExistente = taller;
        this.logoPreview     = taller.logo_url ?? null;
        this.modoEdicion     = false;
        this.isLoading       = false;
        this.buildForm(taller);
        this.deshabilitarCamposVista();
        this.mostrarExito('✅ Taller actualizado correctamente');

        if (this.logoFile) {
          this.tallerService.subirLogo(taller.id, this.logoFile!).subscribe({
            next: (res) => { this.logoPreview = res.logo_url ?? this.logoPreview; },
            error: () => {}
          });
        }
      },
      error: (err) => {
        this.isLoading = false;
        this.mostrarError(err?.error?.detail ?? 'Error al actualizar el taller.');
      }
    });
  }

  private crearTaller(): void {
    const payload: TallerCreate = this.tallerForm.getRawValue();

    this.tallerService.registrar(payload).subscribe({
      next: (taller) => {
        this.isLoading       = false;
        this.tallerExistente = taller;
        this.logoPreview     = taller.logo_url ?? null;
        this.modoEdicion     = false;
        this.buildForm(taller);
        this.deshabilitarCamposVista();
        this.mostrarExito(`¡Taller "${taller.nombre}" registrado con éxito!`);

        // Vincular taller_id al usuario en localStorage y backend
        const usuario = this.auth.getUsuario();
        if (usuario) {
          usuario.taller_id = taller.id;
          this.auth.setUsuario(usuario);

          const token   = this.auth.getToken();
          const headers = new HttpHeaders({ Authorization: `Bearer ${token}` });
          this.http.patch(
            `${environment.apiUrl}/usuarios/${usuario.id}/taller`,
            { taller_id: taller.id },
            { headers }
          ).subscribe({
            next: () => console.log('✅ taller_id vinculado en backend'),
            error: (e) => console.warn('⚠️ Error vinculando taller_id:', e)
          });
        }

        // Subir logo si hay
        if (this.logoFile) {
          this.tallerService.subirLogo(taller.id, this.logoFile!).subscribe({
            next: (res) => { this.logoPreview = res.logo_url ?? this.logoPreview; },
            error: () => {}
          });
        }
      },
      error: (err) => {
        this.isLoading = false;
        this.mostrarError(err?.error?.detail ?? 'Error al registrar el taller.');
      }
    });
  }

  // ── MAPA ─────────────────────────────────────────────────────────────────

  private initMap(): void {
    this.map = L.map('map-taller').setView([this.DEFAULT_LAT, this.DEFAULT_LNG], 13);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(this.map);

    this.marker = L.marker([this.DEFAULT_LAT, this.DEFAULT_LNG], {
      icon:      this.tallerIcon,
      draggable: true
    }).addTo(this.map);

    this.marker.bindPopup('📍 Arrastra para mover la ubicación de tu taller').openPopup();

    this.marker.on('dragend', () => {
      const pos = this.marker.getLatLng();
      this.zone.run(() => this.updateCoords(pos.lat, pos.lng));
    });

    this.map.on('click', (e: L.LeafletMouseEvent) => {
      if (this.modoEdicion || !this.tieneTaller) {
        this.marker.setLatLng(e.latlng);
        this.zone.run(() => this.updateCoords(e.latlng.lat, e.latlng.lng));
      }
    });
  }

  private moverMarcador(lat: number, lng: number): void {
    if (this.map && this.marker) {
      this.marker.setLatLng([lat, lng]);
      this.map.setView([lat, lng], 15);
    }
  }

  private updateCoords(lat: number, lng: number): void {
    this.tallerForm.patchValue({
      latitud:  parseFloat(lat.toFixed(6)),
      longitud: parseFloat(lng.toFixed(6))
    });
  }

  // ── LOGO ─────────────────────────────────────────────────────────────────

  onLogoSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      this.logoFile = input.files[0];
      const reader  = new FileReader();
      reader.onload = (e) => this.logoPreview = e.target?.result as string;
      reader.readAsDataURL(this.logoFile);
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  get f() { return this.tallerForm.controls; }

  isInvalid(field: string): boolean {
    const ctrl = this.tallerForm.get(field);
    return !!(ctrl && ctrl.invalid && ctrl.enabled && (ctrl.dirty || ctrl.touched));
  }

  getRadioValue(): number {
    return this.tallerForm.get('radio_servicio_km')?.value ?? 10;
  }

  get tieneTaller(): boolean {
    return !!this.tallerExistente;
  }
}