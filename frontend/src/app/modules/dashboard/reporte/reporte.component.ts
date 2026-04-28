import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { environment } from '../../../../environments/environment';

@Component({
  selector: 'app-reporte',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './reporte.component.html',
  styleUrls: ['./reporte.component.css']
})
export class ReporteComponent implements OnInit {
  registros: any[] = [];
  total = 0;
  loading = true;
  generando = false;

  private API = `${environment.apiUrl}/bitacora`;

  constructor(private http: HttpClient) {}

  ngOnInit() {
    this.cargarDatos();
  }

  cargarDatos() {
    const token = localStorage.getItem('token');
    const headers = new HttpHeaders({ Authorization: `Bearer ${token}` });
    this.http.get<any>(this.API, { headers }).subscribe({
      next: (res) => {
        this.registros = res.registros;
        this.total = res.total;
        this.loading = false;
      },
      error: () => { this.loading = false; }
    });
  }

  get totalLogin()  { return this.registros.filter(r => r.accion === 'login').length; }
  get totalLogout() { return this.registros.filter(r => r.accion === 'logout').length; }

  formatFecha(fecha: string): string {
    return new Date(fecha).toLocaleString('es-BO', {
      day: '2-digit', month: '2-digit', year: 'numeric',
      hour: '2-digit', minute: '2-digit', second: '2-digit'
    });
  }

  generarPDF() {
    this.generando = true;

    const usuario = JSON.parse(localStorage.getItem('usuario') || '{}');
    const ahora = new Date().toLocaleString('es-BO');

    const filas = this.registros.map((r, i) => `
      <tr>
        <td>${i + 1}</td>
        <td>${r.nombres}</td>
        <td>${r.email}</td>
        <td>${r.tipo}</td>
        <td class="${r.accion}">${r.accion === 'login' ? '▶ Login' : '◼ Logout'}</td>
        <td>${this.formatFecha(r.fecha_hora)}</td>
        <td>${r.ip || '—'}</td>
      </tr>
    `).join('');

    const html = `
      <!DOCTYPE html>
      <html lang="es">
      <head>
        <meta charset="UTF-8"/>
        <title>Reporte Bitácora — AutoWorks Bolivia</title>
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: Arial, sans-serif; font-size: 11px; color: #222; background: #fff; padding: 2rem; }
          .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 1.5rem; padding-bottom: 1rem; border-bottom: 2px solid #e67e22; }
          .logo { font-size: 1.4rem; font-weight: 900; letter-spacing: 0.05em; color: #111; }
          .logo span { color: #e67e22; }
          .header-info { text-align: right; font-size: 10px; color: #888; }
          .title { font-size: 1rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.1em; color: #333; margin-bottom: 1rem; }
          .stats { display: flex; gap: 1rem; margin-bottom: 1.5rem; }
          .stat { flex: 1; border: 1px solid #ddd; border-radius: 4px; padding: 0.6rem 1rem; }
          .stat-num { font-size: 1.4rem; font-weight: 900; color: #e67e22; }
          .stat-lbl { font-size: 9px; color: #888; text-transform: uppercase; letter-spacing: 0.08em; }
          table { width: 100%; border-collapse: collapse; font-size: 10px; }
          thead tr { background: #111; color: #fff; }
          th { padding: 8px 10px; text-align: left; font-size: 9px; letter-spacing: 0.08em; text-transform: uppercase; }
          tbody tr { border-bottom: 1px solid #f0f0f0; }
          tbody tr:nth-child(even) { background: #fafafa; }
          td { padding: 7px 10px; color: #444; }
          .login  { color: #27ae60; font-weight: 700; }
          .logout { color: #c0392b; font-weight: 700; }
          .footer { margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #eee; font-size: 9px; color: #aaa; display: flex; justify-content: space-between; }
          @media print {
            body { padding: 1rem; }
            .no-print { display: none; }
          }
        </style>
      </head>
      <body>
        <div class="header">
          <div>
            <div class="logo">Auto<span>Works</span> Bolivia</div>
            <div style="font-size:10px;color:#888;margin-top:4px">Sistema de gestión de taller mecánico</div>
          </div>
          <div class="header-info">
            <div><strong>Reporte generado:</strong> ${ahora}</div>
            <div><strong>Generado por:</strong> ${usuario.nombres || 'Sistema'}</div>
            <div><strong>Rol:</strong> ${usuario.tipo || '—'}</div>
          </div>
        </div>

        <div class="title">Reporte de Bitácora — Sesiones del Sistema</div>

        <div class="stats">
          <div class="stat">
            <div class="stat-num">${this.total}</div>
            <div class="stat-lbl">Total registros</div>
          </div>
          <div class="stat">
            <div class="stat-num" style="color:#27ae60">${this.totalLogin}</div>
            <div class="stat-lbl">Inicios de sesión</div>
          </div>
          <div class="stat">
            <div class="stat-num" style="color:#c0392b">${this.totalLogout}</div>
            <div class="stat-lbl">Cierres de sesión</div>
          </div>
        </div>

        <table>
          <thead>
            <tr>
              <th>#</th>
              <th>Usuario</th>
              <th>Email</th>
              <th>Rol</th>
              <th>Acción</th>
              <th>Fecha y hora</th>
              <th>IP</th>
            </tr>
          </thead>
          <tbody>${filas}</tbody>
        </table>

        <div class="footer">
          <span>AutoWorks Bolivia — Sistema de gestión de taller</span>
          <span>Total: ${this.total} registros</span>
        </div>
      </body>
      </html>
    `;

    const ventana = window.open('', '_blank', 'width=900,height=700');
    if (ventana) {
      ventana.document.write(html);
      ventana.document.close();
      ventana.focus();
      setTimeout(() => {
        ventana.print();
        this.generando = false;
      }, 500);
    } else {
      this.generando = false;
    }
  }
}