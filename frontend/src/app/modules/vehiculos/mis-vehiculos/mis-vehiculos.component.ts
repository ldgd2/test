import { Component, OnInit, ChangeDetectorRef } from '@angular/core';  // ← agrega
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { firstValueFrom } from 'rxjs';
import { VehiculoService, Vehiculo, VehiculoCreate } from '../vehiculo.service';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-mis-vehiculos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './mis-vehiculos.html',
  styleUrls: ['./mis-vehiculos.css']
})
export class MisVehiculosComponent implements OnInit {

  vehiculos: Vehiculo[] = [];
  mostrandoForm = false;
  editando: Vehiculo | null = null;

  form: VehiculoCreate = this.formVacio();
  fotoFile: File | null = null;
  fotoPreview: string | null = null;

  cargando = false;
  error = '';
  exito = '';

  readonly combustibles = [
    { valor: 'gasolina',  label: 'Gasolina',  icono: 'fuel'   },
    { valor: 'diesel',    label: 'Diésel',    icono: 'fuel'   },
    { valor: 'electrico', label: 'Eléctrico', icono: 'bolt'   },
    { valor: 'hibrido',   label: 'Híbrido',   icono: 'hybrid' },
    { valor: 'gas',       label: 'Gas',       icono: 'drop'   },
  ];

  readonly anioActual = new Date().getFullYear();

  constructor(
    private vehiculoService: VehiculoService,
    private cdr: ChangeDetectorRef  // ← agrega
  ) {}

  ngOnInit() {
    this.cargarVehiculos();
  }

  cargarVehiculos() {
    this.vehiculoService.getMisVehiculos().subscribe({
      next: v => {
        this.vehiculos = v;
        this.cdr.detectChanges();  // ← fuerza render
      },
      error: err => {
        console.error('Error cargando vehículos:', err);
        this.error = 'No se pudieron cargar los vehículos';
      }
    });
  }

  formVacio(): VehiculoCreate {
    return {
      placa: '', marca: '', modelo: '',
      anio: new Date().getFullYear(),
      color: '', combustible: 'gasolina'
    };
  }

  abrirForm(vehiculo?: Vehiculo) {
    this.editando = vehiculo || null;
    this.form = vehiculo
      ? { placa: vehiculo.placa, marca: vehiculo.marca, modelo: vehiculo.modelo,
          anio: vehiculo.anio, color: vehiculo.color || '', combustible: vehiculo.combustible }
      : this.formVacio();
    this.fotoPreview = vehiculo?.foto_url || null;
    this.fotoFile    = null;
    this.error       = '';
    this.exito       = '';
    this.mostrandoForm = true;
    this.cdr.detectChanges();
  }

  cancelar() {
    this.mostrandoForm = false;
    this.editando    = null;
    this.fotoPreview = null;
    this.fotoFile    = null;
    this.error       = '';
    this.exito       = '';
    this.form        = this.formVacio();
    this.cdr.detectChanges();
  }

  handleFoto(event: any) {
    const file: File = event.target.files[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) { this.error = 'La imagen supera 5 MB'; return; }
    this.fotoFile = file;
    const reader  = new FileReader();
    reader.onload = () => {
      this.fotoPreview = reader.result as string;
      this.cdr.detectChanges();
    };
    reader.readAsDataURL(file);
  }

  selCombustible(valor: string) {
    this.form.combustible = valor;
    this.cdr.detectChanges();
  }

  async guardar() {
    this.error = '';
    this.exito = '';

    if (!this.form.placa.trim() || !this.form.marca.trim() || !this.form.modelo.trim()) {
      this.error = 'Placa, marca y modelo son obligatorios';
      return;
    }
    if (this.form.anio < 1900 || this.form.anio > 2100) {
      this.error = 'El año debe estar entre 1900 y 2100';
      return;
    }

    this.cargando = true;
    this.cdr.detectChanges();

    try {
      let vehiculo: Vehiculo;

      if (this.editando) {
        vehiculo = await firstValueFrom(
          this.vehiculoService.actualizar(this.editando.id, this.form)
        );
      } else {
        vehiculo = await firstValueFrom(
          this.vehiculoService.crear({
            ...this.form,
            placa: this.form.placa.toUpperCase()
          })
        );
      }

      // Subir foto con fetch nativo
      if (this.fotoFile && vehiculo?.id) {
        try {
          const token    = localStorage.getItem('token');
          const formData = new FormData();
          formData.append('foto', this.fotoFile, this.fotoFile.name);

          const res = await fetch(
            `${environment.apiUrl}/vehiculos/${vehiculo.id}/foto`,
            {
              method:  'POST',
              headers: { 'Authorization': `Bearer ${token}` },
              body:    formData
            }
          );

          if (res.ok) {
            const resFoto     = await res.json();
            vehiculo.foto_url = resFoto.foto_url;
          }
        } catch (fotoErr) {
          console.warn('Error foto:', fotoErr);
        } finally {
          this.fotoFile = null;
        }
      }

      // Actualizar lista local
      if (this.editando) {
        const idx = this.vehiculos.findIndex(v => v.id === vehiculo.id);
        if (idx !== -1) this.vehiculos[idx] = { ...vehiculo };
      } else {
        this.vehiculos.push(vehiculo);
      }

      // ← forzar render ANTES del timeout
      this.cargando          = false;
      this.mostrandoForm     = false;
      this.editando          = null;
      this.fotoPreview       = null;
      this.form              = this.formVacio();
      this.exito             = this.editando
        ? 'Vehículo actualizado ✓'
        : 'Vehículo registrado ✓';
      this.vehiculos         = [...this.vehiculos];
      this.cdr.detectChanges();  // ← fuerza Angular a re-renderizar

      setTimeout(() => {
        this.exito = '';
        this.cdr.detectChanges();
      }, 2000);

    } catch (err: any) {
      console.error('Error:', err);
      this.error    = err.error?.detail || 'Error al guardar el vehículo';
      this.cargando = false;
      this.cdr.detectChanges();
    }
  }

  async eliminar(id: string) {
    if (!confirm('¿Desactivar este vehículo?')) return;
    try {
      await firstValueFrom(this.vehiculoService.eliminar(id));
      this.vehiculos = this.vehiculos.filter(v => v.id !== id);
      this.cdr.detectChanges();
    } catch {
      this.error = 'Error al eliminar el vehículo';
    }
  }
}