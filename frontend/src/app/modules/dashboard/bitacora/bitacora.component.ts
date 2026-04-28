import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';
import { environment } from '../../../../environments/environment';

interface BitacoraItem {
  id: string;
  usuario_id: string;
  email: string;
  nombres: string;
  tipo: string;
  accion: string;
  fecha_hora: string;
  ip: string | null;
}

@Component({
  selector: 'app-bitacora',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './bitacora.component.html',
  styleUrl: './bitacora.component.css'
})
export class BitacoraComponent implements OnInit {

  registros: BitacoraItem[] = [];
  filtrados:  BitacoraItem[] = [];
  total = 0;

  filtroTexto  = '';
  filtroAccion = '';
  filtroRol    = '';
  filtroFecha  = '';

  cargando = false;
  error    = '';

  private API = `${environment.apiUrl}/bitacora`;

  constructor(
    private http: HttpClient,
    private cdr: ChangeDetectorRef
  ) {}

  ngOnInit() { this.cargar(); }

  private get headers(): HttpHeaders {
    const token = localStorage.getItem('token') || '';
    return new HttpHeaders().set('Authorization', `Bearer ${token}`);
  }

  async cargar() {
    this.cargando = true;
    this.error    = '';
    try {
      const res: any = await firstValueFrom(
        this.http.get(this.API, { headers: this.headers })
      );
      this.registros = res.registros || [];
      this.total     = res.total || 0;
      this.aplicarFiltros();
    } catch (err: any) {
      this.error = err.error?.detail || 'Error al cargar la bitácora';
    } finally {
      this.cargando = false;
      this.cdr.detectChanges();
    }
  }

  aplicarFiltros() {
    let lista = [...this.registros];

    if (this.filtroTexto.trim()) {
      const q = this.filtroTexto.toLowerCase();
      lista = lista.filter(r =>
        r.nombres.toLowerCase().includes(q) ||
        r.email.toLowerCase().includes(q)
      );
    }
    if (this.filtroAccion) lista = lista.filter(r => r.accion === this.filtroAccion);
    if (this.filtroRol)    lista = lista.filter(r => r.tipo   === this.filtroRol);
    if (this.filtroFecha) {
      lista = lista.filter(r => r.fecha_hora.startsWith(this.filtroFecha));
    }

    this.filtrados = lista;
    this.cdr.detectChanges();
  }

  limpiarFiltros() {
    this.filtroTexto  = '';
    this.filtroAccion = '';
    this.filtroRol    = '';
    this.filtroFecha  = '';
    this.aplicarFiltros();
  }

  get totalLogin()  { return this.registros.filter(r => r.accion === 'login').length; }
  get totalLogout() { return this.registros.filter(r => r.accion === 'logout').length; }
  get usuariosUnicos() {
    return new Set(this.registros.map(r => r.usuario_id)).size;
  }

  iniciales(nombre: string): string {
    const partes = nombre.trim().split(' ');
    return partes.length >= 2
      ? (partes[0][0] + partes[1][0]).toUpperCase()
      : partes[0].slice(0, 2).toUpperCase();
  }

  formatFecha(fecha: string): string {
    return new Date(fecha).toLocaleString('es-BO', {
      day:    '2-digit', month: '2-digit', year: 'numeric',
      hour:   '2-digit', minute: '2-digit', second: '2-digit'
    });
  }

  imprimir() {
    window.print();
  }

  exportarCSV() {
    const headers = ['Nombres', 'Email', 'Rol', 'Acción', 'Fecha y hora', 'IP'];
    const filas   = this.filtrados.map(r => [
      r.nombres, r.email, r.tipo, r.accion,
      this.formatFecha(r.fecha_hora), r.ip || ''
    ]);

    const csv = [headers, ...filas]
      .map(row => row.map(v => `"${v}"`).join(','))
      .join('\n');

    const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href     = url;
    a.download = `bitacora_${new Date().toISOString().slice(0,10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }
}