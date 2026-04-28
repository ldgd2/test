import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { BitacoraComponent } from '../bitacora/bitacora.component';
import { environment } from '../../../../environments/environment';
import { ReporteComponent } from '../reporte/reporte.component';
import { PerfilUsuarioComponent } from '../../perfil_usuario/perfilusuario.component';
import { MisVehiculosComponent } from '../../vehiculos/mis-vehiculos/mis-vehiculos.component';
import { MiTallerComponent } from '../../taller/mi-taller/mi-taller.component';
import { ReportarComponent } from '../../incidentes/reportar/reportar.component';
import { AtenderComponent } from '../../incidentes/atender/atender.component';
import { HistorialTecnicoComponent } from '../../asignaciones/historial-tecnico/historial-tecnico.component';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule, 
    BitacoraComponent, 
    ReporteComponent, 
    PerfilUsuarioComponent, 
    MisVehiculosComponent, 
    MiTallerComponent,
    ReportarComponent,
    AtenderComponent,
    HistorialTecnicoComponent
  ],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.css']
})
export class DashboardComponent implements OnInit {
  // 1. Propiedades de la clase
  usuario: any = null;
  seccionActiva = 'inicio';

  agenda = [
    { hora: '10:00', fin: '13:00', titulo: 'Cita de vehículo', auto: 'Toyota Corolla' },
    { hora: '13:00', fin: '17:30', titulo: 'Cita de vehículo', auto: 'Honda Civic' },
    { hora: '15:00', fin: '18:00', titulo: 'Cita de vehículo', auto: 'Nissan Sentra' },
  ];

  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  // 2. Ciclo de vida
  ngOnInit() {
    this.usuario = this.authService.getUsuario();
    if (!this.usuario) {
      this.router.navigate(['/login']);
    }
  }

  // 3. Getters para la UI
  get menuItems() {
    const items = [
      { id: 'inicio', icono: '⊞', label: 'Inicio' },
      { id: 'pedidos', icono: '📋', label: 'Pedidos' },
    
      { id: 'reporte', icono: '📊', label: 'Reporte' },
      { id: 'perfil', icono: '👤', label: 'Mi Perfil' },

    ];

    if (this.usuario?.tipo === 'admin') {
    items.push({ id: 'bitacora', icono: '📖', label: 'Bitácora' });
  }

    if (this.usuario?.tipo === 'tecnico' || this.usuario?.tipo === 'admin') {
    items.push({ id: 'taller', icono: '🔧', label: 'Mi Taller' });
    items.push({ id: 'atender', icono: '🛠️', label: 'Atender Auxilios' });
    items.push({ id: 'historial', icono: '📋', label: 'Historial de Casos' });
  }
  if (this.usuario?.tipo === 'cliente') {
    items.push({ id: 'vehiculos', icono: '🚗', label: 'Mis vehículos' });
    items.push({ id: 'reportar', icono: '🚨', label: 'Pedir Auxilio' });
  }
  return items;

  }

  get nombreCompleto() {
    return this.usuario ? `${this.usuario.nombres} ${this.usuario.apellidos}` : 'Usuario';
  }

  get rolLabel() {
    const roles: any = { admin: 'Administrador', tecnico: 'Técnico', cliente: 'Cliente' };
    return roles[this.usuario?.tipo] || this.usuario?.tipo;
  }

  get iniciales() {
    if (!this.usuario || !this.usuario.nombres) return 'U';
    const n = this.usuario.nombres[0] || '';
    const a = this.usuario.apellidos ? this.usuario.apellidos[0] : '';
    return `${n}${a}`.toUpperCase();
  }

  // 4. Métodos de acción
  setSeccion(id: string) {
    this.seccionActiva = id;
  }

  onPerfilGuardado(usuarioActualizado: any) {
    this.usuario = { ...this.usuario, ...usuarioActualizado };
    this.authService.setUsuario(this.usuario); // guarda en localStorage
  }

  logout() {
    const token = localStorage.getItem('token');
    if (token) {
      fetch(`${environment.apiUrl}/usuarios/logout`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` }
      }).finally(() => {
        this.authService.logout();
        this.router.navigate(['/login']);
      });
    } else {
      this.authService.logout();
      this.router.navigate(['/login']);
    }
  }
}