import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./modules/home/home.component')
        .then(m => m.HomeComponent)
  },
  {
    path: 'login',
    loadComponent: () =>
      import('./modules/login/login.component')
        .then(m => m.LoginComponent)
  },
  {
    path: 'registro',
    loadComponent: () =>
      import('./modules/auth/registro/registro.component')
        .then(m => m.RegistroComponent)
  },
  {
    path: 'admin',
    loadComponent: () =>
      import('./modules/admin/admin/admin.component')
        .then(m => m.AdminComponent)
  },
  {
    path: 'tecnico',
    loadComponent: () =>
      import('./modules/tecnico/tecnico/tecnico.component')
        .then(m => m.TecnicoComponent)
  },
  {
    path: 'cliente',
    loadComponent: () =>
      import('./modules/cliente/cliente/cliente.component')
        .then(m => m.ClienteComponent)
  },
  {
    path: 'dashboard',
    loadComponent: () =>
      import('./modules/dashboard/dashboard/dashboard.component')
        .then(m => m.DashboardComponent)
  },
  {
  path: 'casos-disponibles',
  loadComponent: () =>
    import('./modules/casos-disponibles/casos-disponibles.component')
    .then(m => m.CasosDisponiblesComponent)
},
{
  path: 'historial',
  loadComponent: () =>
    import('./modules/asignaciones/historial-tecnico/historial-tecnico.component')
    .then(m => m.HistorialTecnicoComponent)
},
  {
    path: '**',
    redirectTo: ''
  }
];