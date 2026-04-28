# 🚀 Deploy — AutoWorks Bolivia
## Plataforma de Emergencias Vehiculares

Carpeta de scripts para despliegue en Ubuntu (sin Nginx).

---

## 📁 Estructura

```
deploy/
├── README.md                    ← Este archivo
├── deploy.sh                    ← Script maestro de despliegue completo
│
├── backend/
│   ├── 01_install_deps.sh       ← Instala Python, pip, ODBC Driver, dependencias
│   ├── 02_init_db.sh            ← Inicializa/migra la base de datos SQL Server
│   ├── 03_seed_db.sh            ← Ejecuta el seeder de datos
│   ├── 04_create_service.sh     ← Crea y habilita el servicio systemd del backend
│   ├── 05_start_backend.sh      ← Inicia / reinicia el backend
│   ├── 06_stop_backend.sh       ← Detiene el backend
│   ├── 07_logs_backend.sh       ← Muestra logs del servicio backend
│   └── 08_status_backend.sh     ← Estado del servicio backend
│
└── frontend/
    ├── 01_install_deps.sh       ← Instala Node.js, npm, dependencias Angular
    ├── 02_build.sh              ← Compila el frontend (production)
    ├── 03_create_service.sh     ← Crea y habilita el servicio systemd del frontend
    ├── 04_start_frontend.sh     ← Inicia / reinicia el frontend
    ├── 05_stop_frontend.sh      ← Detiene el frontend
    ├── 06_logs_frontend.sh      ← Muestra logs del servicio frontend
    └── 07_status_frontend.sh    ← Estado del servicio frontend
```

---

## ⚡ Despliegue Rápido (Primera vez)

```bash
# 1. Clonar/subir el proyecto al VPS
scp -r ./taller_ciclos user@185.214.134.23:/opt/

# 2. Entrar al servidor
ssh user@185.214.134.23

# 3. Dar permisos de ejecución
chmod +x /opt/taller_ciclos/deploy/*.sh
chmod +x /opt/taller_ciclos/deploy/backend/*.sh
chmod +x /opt/taller_ciclos/deploy/frontend/*.sh

# 4. Ejecutar el deploy maestro
sudo /opt/taller_ciclos/deploy/deploy.sh
```

## 🔄 Actualizaciones

```bash
# Después de subir cambios al servidor:
sudo systemctl restart autoworks-backend
sudo systemctl restart autoworks-frontend
```

---

## 🌐 Puertos

| Servicio  | Puerto | Descripción              |
|-----------|--------|--------------------------|
| Backend   | 8000   | FastAPI con Uvicorn      |
| Frontend  | 4000   | Angular SSR con Node.js  |

---

## 📋 Variables de Entorno

Editar antes de desplegar:
- `backend/.env` → Configuración de base de datos, JWT, API URL
- `frontend/src/environments/environment.prod.ts` → URL de la API

---

## 🛠️ Comandos Útiles

```bash
# Ver todos los servicios
sudo systemctl list-units --type=service | grep autoworks

# Ver logs en tiempo real
sudo journalctl -u autoworks-backend -f
sudo journalctl -u autoworks-frontend -f

# Reiniciar todo
sudo systemctl restart autoworks-backend autoworks-frontend

# Estado de ambos servicios
sudo systemctl status autoworks-backend autoworks-frontend
```
