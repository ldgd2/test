import { Component, OnInit, AfterViewInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { IncidenteService } from '../../../core/services/incidente.service';
import { VehiculoService } from '../../vehiculos/vehiculo.service';
import * as L from 'leaflet';

// Declaramos la interfaz para el reconocimiento de voz del navegador
const { webkitSpeechRecognition }: any = window as any;

@Component({
  selector: 'app-reportar-incidente',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './reportar.component.html',
  styleUrls: ['./reportar.component.css']
})
export class ReportarComponent implements OnInit, AfterViewInit {
  incidenteForm: FormGroup;
  misVehiculos: any[] = [];
  cargando: boolean = false;

  // Variables para la Foto
  fotoSeleccionada: File | null = null;
  imagePreview: string | null = null;

  // Variables para el reconocimiento de voz
  isListening: boolean = false;
  private recognition: any;

  // Variables para el Mapa
  private map: any;
  private marker: any;
  private defaultIcon = L.icon({
    iconUrl: 'https://unpkg.com/leaflet@1.7.1/dist/images/marker-icon.png',
    shadowUrl: 'https://unpkg.com/leaflet@1.7.1/dist/images/marker-shadow.png',
    iconSize: [25, 41],
    iconAnchor: [12, 41]
  });

  constructor(
    private fb: FormBuilder,
    private incidenteService: IncidenteService,
    private vehiculoService: VehiculoService
  ) {
    this.incidenteForm = this.fb.group({
      vehiculo_id: ['', Validators.required],
      categoria: ['motor', Validators.required],
      direccion_texto: ['', [Validators.required, Validators.minLength(5)]],
      descripcion_manual: ['', [Validators.required, Validators.maxLength(500)]],
      ubicacion: ['0,0'], 
      prioridad: ['media']
    });

    // Inicializamos el motor de voz
    this.initSpeechRecognition();
  }

  ngOnInit(): void {
    this.cargarVehiculos();
  }

  ngAfterViewInit(): void {
    this.initMap();
  }

  cargarVehiculos(): void {
    this.vehiculoService.getMisVehiculos().subscribe({
      next: (data) => this.misVehiculos = data,
      error: (err) => console.error('Error al cargar vehículos:', err)
    });
  }

  // --- LÓGICA DE RECONOCIMIENTO DE VOZ ---
  initSpeechRecognition() {
    if ('webkitSpeechRecognition' in window) {
      this.recognition = new webkitSpeechRecognition();
      this.recognition.continuous = false; 
      this.recognition.lang = 'es-BO'; // Español de Bolivia
      this.recognition.interimResults = false;

      this.recognition.onstart = () => {
        this.isListening = true;
      };

      this.recognition.onresult = (event: any) => {
        const transcript = event.results[0][0].transcript;
        const valorActual = this.incidenteForm.get('descripcion_manual')?.value || '';
        this.incidenteForm.patchValue({
          descripcion_manual: valorActual + (valorActual ? ' ' : '') + transcript
        });
        this.isListening = false;
      };

      this.recognition.onerror = (event: any) => {
        console.error('Error en reconocimiento:', event.error);
        this.isListening = false;
      };

      this.recognition.onend = () => {
        this.isListening = false;
      };
    }
  }

  toggleDictado() {
    if (this.isListening) {
      this.recognition.stop();
    } else {
      this.recognition.start();
    }
  }

  // --- LÓGICA DE LA FOTO ---
  onFileSelected(event: any): void {
    const file = event.target.files[0];
    if (file) {
      this.fotoSeleccionada = file;

      const reader = new FileReader();
      reader.onload = () => {
        this.imagePreview = reader.result as string;
      };
      reader.readAsDataURL(file);
    }
  }

  // --- LÓGICA DEL MAPA ---
  private initMap(): void {
    const lat = -17.7833;
    const lng = -63.1821;

    this.map = L.map('map').setView([lat, lng], 13);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors'
    }).addTo(this.map);

    this.marker = L.marker([lat, lng], {
      icon: this.defaultIcon,
      draggable: true
    }).addTo(this.map);

    this.marker.on('dragend', () => {
      const position = this.marker.getLatLng();
      this.actualizarUbicacionForm(position.lat, position.lng);
    });

    this.map.locate({ setView: true, maxZoom: 16 });
    this.map.on('locationfound', (e: any) => {
      this.marker.setLatLng(e.latlng);
      this.actualizarUbicacionForm(e.latlng.lat, e.latlng.lng);
    });
  }

  actualizarUbicacionForm(lat: number, lng: number) {
    this.incidenteForm.patchValue({
      ubicacion: `${lat},${lng}`
    });
  }

  // --- ENVÍO DEL FORMULARIO ---
  enviarIncidente(): void {
    if (this.incidenteForm.valid) {
      this.cargando = true;

      const formData = new FormData();
      
      Object.keys(this.incidenteForm.value).forEach(key => {
        formData.append(key, this.incidenteForm.value[key]);
      });

      if (this.fotoSeleccionada) {
        formData.append('foto', this.fotoSeleccionada);
      }

      this.incidenteService.crearIncidente(formData).subscribe({
        next: (res) => {
          alert('¡Incidente reportado con éxito!');
          this.resetearTodo();
          this.cargando = false;
        },
        error: (err) => {
          this.cargando = false;
          console.error('Error al guardar:', err);
          alert('Error al reportar: Revisa la conexión o los campos.');
        }
      });
    } else {
      Object.values(this.incidenteForm.controls).forEach(control => control.markAsTouched());
    }
  }

  resetearTodo() {
    this.incidenteForm.reset({
      categoria: 'motor',
      ubicacion: '0,0',
      prioridad: 'media'
    });
    this.fotoSeleccionada = null;
    this.imagePreview = null;
    this.isListening = false;
  }
}