import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';

@Component({
  selector: 'app-registro',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './registro.component.html',
  styleUrls: ['./registro.component.css']
})
export class RegistroComponent {
  form = {
    nombres: '',
    apellidos: '',
    email: '',
    telefono: '',
    password: '',
    confirmar: '',
    tipo: 'cliente'
  };

  error = '';
  exito = '';
  loading = false;
  paso = 1;

  tiposUsuario = [
    {
      valor: 'cliente',
      titulo: 'Cliente',
      descripcion: 'Quiero solicitar servicios mecánicos para mi vehículo',
      icono: '🚗'
    },
    {
      valor: 'tecnico',
      titulo: 'Técnico',
      descripcion: 'Soy mecánico y quiero atender solicitudes de servicio',
      icono: '🔧'
    },
    {
      valor: 'admin',
      titulo: 'Administrador',
      descripcion: 'Tengo acceso administrativo a la plataforma',
      icono: '⚙️'
    }
  ];

  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  seleccionarTipo(tipo: string) {
    this.form.tipo = tipo;
    this.paso = 2;
  }

  volver() {
    this.paso = 1;
    this.error = '';
    this.exito = '';
  }

  tipoSeleccionado() {
    return this.tiposUsuario.find(t => t.valor === this.form.tipo);
  }

  registrar() {
    this.error = '';
    this.exito = '';

    if (!this.form.nombres || !this.form.apellidos || !this.form.email || !this.form.password) {
      this.error = 'Todos los campos obligatorios deben estar completos';
      return;
    }

    if (this.form.password !== this.form.confirmar) {
      this.error = 'Las contraseñas no coinciden';
      return;
    }

    if (this.form.password.length < 6) {
      this.error = 'La contraseña debe tener al menos 6 caracteres';
      return;
    }

    this.loading = true;

    const payload = {
      nombres: this.form.nombres,
      apellidos: this.form.apellidos,
      email: this.form.email,
      telefono: this.form.telefono || undefined,
      password: this.form.password,
      tipo: this.form.tipo
    };

    this.authService.registro(payload).subscribe({
      next: (res) => {
        // Mostrar mensaje de éxito y redirigir al login en 2 segundos
        this.exito = `✅ Usuario "${res.nombres} ${res.apellidos}" creado exitosamente. Redirigiendo al login...`;
        this.loading = false;
        setTimeout(() => {
          this.router.navigate(['/login']);
        }, 2000);
      },
      error: (err: any) => {
        this.error = err.error?.detail || 'Error al registrar. Intenta nuevamente.';
        this.loading = false;
      }
    });
  }
}