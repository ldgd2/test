import { Component, Input, Output, EventEmitter, OnInit, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-perfil-usuario',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './perfilusuario.html',
  styleUrls: ['./perfilusuario.css']
})
export class PerfilUsuarioComponent implements OnInit {
  @Input() usuario: any;
  @Output() onGuardado = new EventEmitter<any>();
  @ViewChild('fileInput') fileInput!: ElementRef;

  private API_BASE = environment.apiUrl;

  form: any = {};
  passForm = { passActual: '', passNueva: '', passConfirm: '' };

  fotoPreview: string | null = null;
  fotoFile: File | null = null;
  cargando = false;
  error = '';
  exito = '';

  constructor(private http: HttpClient) {}

  ngOnInit() {
    this.form = {
      nombres:   this.usuario?.nombres   || '',
      apellidos: this.usuario?.apellidos || '',
      email:     this.usuario?.email     || '',
      telefono:  this.usuario?.telefono  || '',
      activo:    this.usuario?.activo    ?? true,
    };
    this.fotoPreview = this.usuario?.foto_perfil_url || null;
  }

  get iniciales(): string {
    const n = this.form.nombres?.[0]   || '';
    const a = this.form.apellidos?.[0] || '';
    return (n + a).toUpperCase() || '?';
  }

  handleFoto(event: any) {
    const file = event.target.files[0];
    if (!file) return;

    if (file.size > 5 * 1024 * 1024) {
      this.error = 'La imagen debe pesar menos de 5 MB';
      return;
    }

    this.fotoFile = file;
    const reader = new FileReader();
    reader.onload = () => (this.fotoPreview = reader.result as string);
    reader.readAsDataURL(file);
  }

  cancelar() {
    this.ngOnInit();
    this.error = '';
    this.exito = '';
    this.passForm = { passActual: '', passNueva: '', passConfirm: '' };
  }

  getBadgeClass(): string {
    const tipos: any = {
      cliente: 'badge-cliente',
      admin:   'badge-admin',
      tecnico: 'badge-tecnico',
    };
    return tipos[this.usuario?.tipo] || 'badge-cliente';
  }

  async handleGuardar() {
    this.error = '';
    this.exito = '';

    if (this.passForm.passNueva && this.passForm.passNueva !== this.passForm.passConfirm) {
      this.error = 'Las contraseñas nuevas no coinciden';
      return;
    }

    if (this.passForm.passNueva && this.passForm.passNueva.length < 8) {
      this.error = 'La contraseña nueva debe tener al menos 8 caracteres';
      return;
    }

    this.cargando = true;
    const token = localStorage.getItem('token');
    const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);

    try {
      // 1. Subir foto si hay nueva
      if (this.fotoFile) {
        const formData = new FormData();
        formData.append('foto', this.fotoFile);

        const resFoto: any = await this.http
          .post(`${this.API_BASE}/usuarios/me/foto`, formData, { headers })
          .toPromise();

        this.fotoPreview = resFoto.foto_perfil_url;
        this.form.foto_perfil_url = resFoto.foto_perfil_url;
        this.fotoFile = null;
      }

      // 2. Actualizar datos del perfil
      const bodyPerfil = {
        nombres:         this.form.nombres,
        apellidos:       this.form.apellidos,
        email:           this.form.email,
        telefono:        this.form.telefono,
        foto_perfil_url: this.form.foto_perfil_url || this.usuario?.foto_perfil_url,
      };

      const actualizado: any = await this.http
        .put(`${this.API_BASE}/usuarios/me`, bodyPerfil, { headers })
        .toPromise();

      // 3. Cambiar contraseña si se rellenó
      if (this.passForm.passActual && this.passForm.passNueva) {
        await this.http
          .put(
            `${this.API_BASE}/usuarios/me/password`,
            {
              password_actual: this.passForm.passActual,
              password_nueva:  this.passForm.passNueva,
            },
            { headers }
          )
          .toPromise();

        this.passForm = { passActual: '', passNueva: '', passConfirm: '' };
      }

      this.exito = 'Perfil actualizado correctamente ✓';
      this.onGuardado.emit(actualizado);

    } catch (err: any) {
      this.error = err.error?.detail || 'Error al actualizar el perfil';
    } finally {
      this.cargando = false;
    }
  }
}