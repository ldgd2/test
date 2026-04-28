"""
╔══════════════════════════════════════════════════════════╗
║   SEEDER — Plataforma de Emergencias Vehiculares         ║
║   Base de datos: Microsoft SQL Server                    ║
╚══════════════════════════════════════════════════════════╝
"""

import sys
import uuid
import random
from datetime import datetime, timedelta
from decimal import Decimal

from faker import Faker
from passlib.context import CryptContext

sys.path.append(".")

from app.database import SessionLocal
from app.modules.usuarios.models     import Usuario
from app.modules.talleres.models     import Taller
from app.modules.vehiculos.models    import Vehiculo
from app.modules.incidentes.models   import Incidente
from app.modules.asignaciones.models import Asignacion, HistorialAsignacion

# ── Config ────────────────────────────────────────────────
fake    = Faker('es_ES')
pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
PASSWORD_DEFAULT = pwd_ctx.hash("Password123!")

CATEGORIAS   = ["bateria","llanta","choque","motor","llave_perdida","llave_adentro","sobrecalentamiento","incierto"]
PRIORIDADES  = ["baja","media","alta","critica"]
COMBUSTIBLES = ["gasolina","diesel","electrico","hibrido","gas"]
MARCAS       = ["Toyota","Nissan","Honda","Hyundai","Kia","Chevrolet","Mitsubishi","Suzuki","Ford","Volkswagen","Mazda","Renault","Peugeot","Jeep","Subaru"]
COLORES      = ["Blanco","Negro","Gris","Rojo","Azul","Verde","Plata","Naranja","Celeste","Morado"]
LAT_BASE     = -17.7833
LNG_BASE     = -63.1821

def lat(): return round(LAT_BASE + random.uniform(-0.15, 0.15), 7)
def lng(): return round(LNG_BASE + random.uniform(-0.15, 0.15), 7)
def fecha_pasada(dias=90): return datetime.utcnow() - timedelta(days=random.randint(1, dias))

# ══════════════════════════════════════════════════════════
# SEEDERS
# ══════════════════════════════════════════════════════════

def seed_talleres(db, n):
    print(f"\n  ⏳ Insertando {n} talleres...")
    talleres = []
    for i in range(n):
        t = Taller(
            id                = uuid.uuid4(),
            nombre            = f"Taller {fake.last_name()} & Asociados",
            email             = f"taller{i+1}_{random.randint(100,999)}@autoworks.bo",
            password_hash     = PASSWORD_DEFAULT,
            telefono          = f"7{random.randint(1000000,9999999)}",
            direccion         = fake.street_address() + ", Santa Cruz",
            latitud           = Decimal(str(lat())),
            longitud          = Decimal(str(lng())),
            radio_servicio_km = Decimal(str(random.choice([5,8,10,12,15,20]))),
            descripcion       = fake.catch_phrase(),
            activo            = True,
            verificado        = random.choice([True, False]),
            comision_pct      = Decimal(str(random.choice([8,10,12,15]))),
        )
        db.add(t)
        talleres.append(t)
    db.commit()
    print(f"  ✅ {n} talleres insertados")
    return talleres


def seed_usuarios(db, talleres, n):
    print(f"\n  ⏳ Insertando {n} usuarios...")
    clientes, tecnicos, admins = [], [], []

    # 70% clientes
    n_clientes = max(1, int(n * 0.70))
    for i in range(n_clientes):
        u = Usuario(
            id=uuid.uuid4(), nombres=fake.first_name(), apellidos=fake.last_name(),
            email=f"cliente{i+1}_{random.randint(100,999)}@gmail.com",
            telefono=f"7{random.randint(1000000,9999999)}",
            password_hash=PASSWORD_DEFAULT, tipo="cliente", activo=True, taller_id=None,
        )
        db.add(u); clientes.append(u)

    # 25% técnicos
    n_tecnicos = max(1, int(n * 0.25))
    for i in range(n_tecnicos):
        taller = random.choice(talleres)
        u = Usuario(
            id=uuid.uuid4(), nombres=fake.first_name_male(), apellidos=fake.last_name(),
            email=f"tecnico{i+1}_{random.randint(100,999)}@taller.bo",
            telefono=f"7{random.randint(1000000,9999999)}",
            password_hash=PASSWORD_DEFAULT, tipo="tecnico", activo=True, taller_id=taller.id,
        )
        db.add(u); tecnicos.append(u)

    # 5% admins
    n_admins = max(1, n - n_clientes - n_tecnicos)
    for i in range(n_admins):
        u = Usuario(
            id=uuid.uuid4(), nombres="Admin", apellidos=fake.last_name(),
            email=f"admin{i+1}_{random.randint(100,999)}@autoworks.bo",
            telefono=f"7{random.randint(1000000,9999999)}",
            password_hash=PASSWORD_DEFAULT, tipo="admin", activo=True, taller_id=None,
        )
        db.add(u); admins.append(u)

    db.commit()
    print(f"  ✅ {n_clientes} clientes, {n_tecnicos} técnicos, {n_admins} admins")
    return clientes, tecnicos, admins


def seed_vehiculos(db, clientes, n):
    print(f"\n  ⏳ Insertando {n} vehículos...")
    vehiculos = []
    for _ in range(n):
        marca = random.choice(MARCAS)
        v = Vehiculo(
            id=uuid.uuid4(), usuario_id=random.choice(clientes).id,
            placa=f"{fake.lexify('???').upper()}-{random.randint(100,9999)}",
            marca=marca, modelo=fake.word().capitalize(),
            anio=random.randint(2005, 2024), color=random.choice(COLORES),
            combustible=random.choice(COMBUSTIBLES), activo=True,
        )
        db.add(v); vehiculos.append(v)
    db.commit()
    print(f"  ✅ {n} vehículos insertados")
    return vehiculos


def seed_incidentes(db, clientes, vehiculos, n):
    print(f"\n  ⏳ Insertando {n} incidentes...")
    incidentes = []
    resumenes = {
        "bateria": "Posible batería descargada. Verificar voltaje y bornes.",
        "llanta":  "Desinflado o daño en llanta. No circular.",
        "motor":   "Falla en motor. Diagnóstico computarizado recomendado.",
        "sobrecalentamiento": "URGENTE: Apagar motor. Revisar refrigerante.",
        "choque":  "Impacto detectado. Evaluar daños estructurales.",
        "llave_perdida": "Pérdida de llave. Cerrajero automotriz necesario.",
        "llave_adentro": "Llaves en interior. Apertura de emergencia.",
        "incierto": "Problema no identificado. Inspección manual requerida.",
    }
    estados = ["pendiente","en_proceso","atendido","cancelado"]
    pesos   = [0.3, 0.2, 0.4, 0.1]

    for _ in range(n):
        cat       = random.choice(CATEGORIAS)
        confianza = round(random.uniform(0.60, 0.98), 4)
        inc = Incidente(
            id=uuid.uuid4(),
            usuario_id=random.choice(clientes).id,
            vehiculo_id=random.choice(vehiculos).id,
            ubicacion=f"{lat()},{lng()}",
            direccion_texto=fake.street_address() + ", Santa Cruz",
            descripcion_manual=fake.sentence(nb_words=10),
            categoria=cat, prioridad=random.choice(PRIORIDADES),
            estado=random.choices(estados, weights=pesos)[0],
            resumen_ia=resumenes.get(cat),
            confianza_ia=Decimal(str(confianza)),
            requiere_revision=confianza < 0.65,
            created_at=fecha_pasada(60),
        )
        db.add(inc); incidentes.append(inc)
    db.commit()
    print(f"  ✅ {n} incidentes insertados")
    return incidentes


def seed_asignaciones(db, incidentes, talleres, tecnicos, n):
    print(f"\n  ⏳ Insertando {n} asignaciones...")
    asignaciones = []
    estados = ["propuesta","aceptada","en_camino","completada","cancelada"]
    pesos   = [0.25, 0.15, 0.15, 0.35, 0.10]

    for _ in range(n):
        estado    = random.choices(estados, weights=pesos)[0]
        tecnico   = random.choice(tecnicos) if estado != "propuesta" else None
        distancia = round(random.uniform(0.5, 15.0), 2)
        tiempo    = int(distancia * 4)
        aceptado  = fecha_pasada(30) if estado != "propuesta" else None
        iniciado  = aceptado + timedelta(minutes=10) if aceptado and estado in ["en_camino","completada"] else None
        completado= iniciado + timedelta(minutes=tiempo) if iniciado and estado == "completada" else None

        asig = Asignacion(
            id=uuid.uuid4(),
            incidente_id=random.choice(incidentes).id,
            taller_id=random.choice(talleres).id,
            usuario_id=tecnico.id if tecnico else None,
            estado=estado,
            distancia_km=Decimal(str(distancia)),
            tiempo_estimado_min=tiempo,
            precio_cotizado=Decimal(str(round(random.uniform(50,500),2))) if estado=="completada" else None,
            nota_taller=fake.sentence() if random.random() > 0.5 else None,
            aceptado_at=aceptado, iniciado_at=iniciado, completado_at=completado,
            created_at=fecha_pasada(60),
        )
        db.add(asig); asignaciones.append(asig)
    db.commit()
    print(f"  ✅ {n} asignaciones insertadas")
    return asignaciones


def seed_historial(db, asignaciones):
    print(f"\n  ⏳ Insertando historial...")
    count  = 0
    flujos = {
        "propuesta":  [],
        "aceptada":   ["propuesta"],
        "en_camino":  ["propuesta","aceptada"],
        "completada": ["propuesta","aceptada","en_camino"],
        "cancelada":  ["propuesta","aceptada"],
    }
    for asig in asignaciones:
        pasos  = flujos.get(asig.estado, [])
        estados= pasos + [asig.estado]
        fecha  = asig.created_at or datetime.utcnow()
        for j in range(len(estados)):
            anterior = estados[j-1] if j > 0 else None
            fecha   += timedelta(minutes=random.randint(5,30))
            db.add(HistorialAsignacion(
                id=uuid.uuid4(), asignacion_id=asig.id,
                estado_anterior=anterior, estado_nuevo=estados[j],
                fuente="sistema" if anterior is None else "tecnico",
                created_at=fecha,
            ))
            count += 1
    db.commit()
    print(f"  ✅ {count} registros de historial insertados")


def limpiar_bd(db):
    print("\n  ⚠️  LIMPIANDO BASE DE DATOS...")
    conf = input("  ¿Confirmas? Esto borrará TODOS los datos (s/n): ").strip().lower()
    if conf != 's':
        print("  Cancelado.")
        return False
    for tabla in [HistorialAsignacion, Asignacion, Incidente, Vehiculo, Usuario, Taller]:
        c = db.query(tabla).delete()
        print(f"  🗑️  {tabla.__tablename__}: {c} eliminados")
    db.commit()
    print("  ✅ BD limpiada")
    return True


# ══════════════════════════════════════════════════════════
# MENÚ INTERACTIVO
# ══════════════════════════════════════════════════════════

def pedir_cantidad(tabla):
    while True:
        try:
            n = int(input(f"\n  ¿Cuántos registros insertar en '{tabla}'? (1-1000): "))
            if 1 <= n <= 1000:
                return n
            print("  ⚠️  Ingresa un número entre 1 y 1000.")
        except ValueError:
            print("  ⚠️  Ingresa un número válido.")


def mostrar_menu():
    print("\n" + "═"*50)
    print("  📋  MENÚ SEEDER — AutoAsistencia")
    print("═"*50)
    print("  1. Poblar TODAS las tablas")
    print("  2. Solo Talleres")
    print("  3. Solo Usuarios")
    print("  4. Solo Vehículos")
    print("  5. Solo Incidentes")
    print("  6. Solo Asignaciones")
    print("  7. Solo Historial de asignaciones")
    print("  8. 🗑️  Limpiar base de datos")
    print("  0. Salir")
    print("═"*50)


def main():
    print("\n╔══════════════════════════════════════════════════╗")
    print("║   SEEDER — Plataforma Emergencias Vehiculares   ║")
    print("║   Todos los registros se insertan en producción ║")
    print("╚══════════════════════════════════════════════════╝")

    db = SessionLocal()

    try:
        while True:
            mostrar_menu()
            opcion = input("\n  Selecciona una opción: ").strip()

            if opcion == "0":
                print("\n  👋 Saliendo del seeder. ¡Hasta luego!")
                break

            elif opcion == "1":
                n = pedir_cantidad("todas las tablas")
                print(f"\n  🚀 Iniciando seeder completo con {n} registros por tabla...")
                talleres = seed_talleres(db, n=max(5, n//5))
                clientes, tecnicos, _ = seed_usuarios(db, talleres, n=n)
                vehiculos    = seed_vehiculos(db, clientes, n=n)
                incidentes   = seed_incidentes(db, clientes, vehiculos, n=n)
                asignaciones = seed_asignaciones(db, incidentes, talleres, tecnicos, n=n)
                seed_historial(db, asignaciones)
                print(f"\n  🎉 ¡Seeder completo! {n} registros por tabla.")

            elif opcion == "2":
                n = pedir_cantidad("talleres")
                seed_talleres(db, n)

            elif opcion == "3":
                talleres = db.query(Taller).all()
                if not talleres:
                    print("  ⚠️  No hay talleres. Inserta talleres primero (opción 2).")
                    continue
                n = pedir_cantidad("usuarios")
                seed_usuarios(db, talleres, n)

            elif opcion == "4":
                clientes = db.query(Usuario).filter(Usuario.tipo=="cliente").all()
                if not clientes:
                    print("  ⚠️  No hay clientes. Inserta usuarios primero (opción 3).")
                    continue
                n = pedir_cantidad("vehículos")
                seed_vehiculos(db, clientes, n)

            elif opcion == "5":
                clientes  = db.query(Usuario).filter(Usuario.tipo=="cliente").all()
                vehiculos = db.query(Vehiculo).all()
                if not clientes or not vehiculos:
                    print("  ⚠️  Faltan clientes o vehículos. Inserta primero (opciones 3 y 4).")
                    continue
                n = pedir_cantidad("incidentes")
                seed_incidentes(db, clientes, vehiculos, n)

            elif opcion == "6":
                incidentes = db.query(Incidente).all()
                talleres   = db.query(Taller).all()
                tecnicos   = db.query(Usuario).filter(Usuario.tipo=="tecnico").all()
                if not incidentes or not talleres:
                    print("  ⚠️  Faltan incidentes o talleres.")
                    continue
                n = pedir_cantidad("asignaciones")
                seed_asignaciones(db, incidentes, talleres, tecnicos, n)

            elif opcion == "7":
                asignaciones = db.query(Asignacion).all()
                if not asignaciones:
                    print("  ⚠️  No hay asignaciones. Inserta primero (opción 6).")
                    continue
                seed_historial(db, asignaciones)

            elif opcion == "8":
                limpiar_bd(db)

            else:
                print("  ⚠️  Opción no válida. Elige entre 0 y 8.")

    except Exception as e:
        db.rollback()
        print(f"\n  ❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()


if __name__ == "__main__":
    main()