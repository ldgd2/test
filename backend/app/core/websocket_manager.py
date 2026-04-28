from fastapi import WebSocket
from typing import Dict, List
import json

class WebSocketManager:
    def __init__(self):
        # { usuario_id: [WebSocket, ...] }
        self.conexiones: Dict[str, List[WebSocket]] = {}

    async def conectar(self, websocket: WebSocket, usuario_id: str):
        await websocket.accept()
        if usuario_id not in self.conexiones:
            self.conexiones[usuario_id] = []
        self.conexiones[usuario_id].append(websocket)
        print(f"🔌 WebSocket conectado: usuario {usuario_id}")

    def desconectar(self, websocket: WebSocket, usuario_id: str):
        if usuario_id in self.conexiones:
            self.conexiones[usuario_id].remove(websocket)
            if not self.conexiones[usuario_id]:
                del self.conexiones[usuario_id]
        print(f"🔌 WebSocket desconectado: usuario {usuario_id}")

    async def enviar_a_usuario(self, usuario_id: str, mensaje: dict):
        """Envía notificación a todas las pestañas del usuario."""
        if usuario_id in self.conexiones:
            for ws in self.conexiones[usuario_id]:
                try:
                    await ws.send_json(mensaje)
                except Exception:
                    pass

    async def broadcast_talleres(self, taller_ids: List[str], mensaje: dict):
        """Envía a múltiples talleres a la vez."""
        for taller_id in taller_ids:
            await self.enviar_a_usuario(taller_id, mensaje)


# Instancia global
ws_manager = WebSocketManager()