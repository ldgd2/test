import { Component, OnInit } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';
import { CommonModule, DatePipe } from '@angular/common'; 
interface Asignacion {
  id: string;
  incidente_id: string;
  estado: string;
  distancia_km: number;
  tiempo_estimado_min: number;
  precio_cotizado: number;
  nota_taller: string;
  created_at: string;
}

@Component({
  selector: 'app-casos-disponibles',
  standalone: true,
  imports: [CommonModule, DatePipe],   // ← agrega DatePipe aquí
  templateUrl: './casos-disponibles.component.html',
  styleUrls: ['./casos-disponibles.component.css']
})
export class CasosDisponiblesComponent implements OnInit {
  casos: Asignacion[] = [];
  cargando = false;
  aceptando: string | null = null;  // ID del caso que se está aceptando

  constructor(private http: HttpClient, private router: Router) {}

  ngOnInit(): void {
    this.cargarCasos();
  }

  private getHeaders() {
    const token = localStorage.getItem('token');
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }

  cargarCasos(): void {
    this.cargando = true;
    this.http.get<Asignacion[]>('/api/asignaciones/disponibles', {
      headers: this.getHeaders()
    }).subscribe({
      next: (data) => {
        this.casos = data;
        this.cargando = false;
      },
      error: () => {
        this.cargando = false;
      }
    });
  }

  aceptarCaso(asignacionId: string): void {
    this.aceptando = asignacionId;

    this.http.patch(`/api/asignaciones/${asignacionId}/aceptar`, {}, {
      headers: this.getHeaders()
    }).subscribe({
      next: () => {
        // Quitar de la lista local inmediatamente (UX fluida)
        this.casos = this.casos.filter(c => c.id !== asignacionId);
        this.aceptando = null;
        alert('✅ Caso aceptado. Puedes verlo en tu historial.');
      },
      error: (err) => {
        this.aceptando = null;
        if (err.status === 409) {
          alert('⚠️ Este caso ya fue tomado por otro técnico.');
          this.cargarCasos();  // Recargar para sincronizar
        }
      }
    });
  }

  irAHistorial(): void {
    this.router.navigate(['/tecnico/historial']);
  }
}