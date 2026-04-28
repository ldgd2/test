// src/app/core/models/asignacion.model.ts

export interface CasoDisponible {
  asignacion_id: string;
  incidente_id: string;
  direccion_texto?: string;
  ubicacion?: string;           // "lat,lng"
  descripcion_manual?: string;
  categoria?: string;
  prioridad?: string;
  foto_evidencia?: string;
  distancia_km?: number;
  tiempo_estimado_min?: number;

  // Datos del vehículo del cliente
  placa?: string;               // ← campo que faltaba
  marca_vehiculo?: string;
  modelo_vehiculo?: string;
  color_vehiculo?: string;

  created_at?: string;
}

export interface HistorialTecnicoItem {
  asignacion_id: string;
  incidente_id: string;
  estado: EstadoAsignacion;
  direccion_texto?: string;
  descripcion_manual?: string;
  placa?: string;
  marca_vehiculo?: string;
  modelo_vehiculo?: string;
  distancia_km?: number;
  precio_cotizado?: number;
  aceptado_at?: string;
  completado_at?: string;
}

export type EstadoAsignacion =
  | 'propuesta'
  | 'aceptada'
  | 'rechazada'
  | 'en_camino'
  | 'completada'
  | 'cancelada';

export interface AceptarPayload {
   usuario_id: string; 
}