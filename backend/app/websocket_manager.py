"""
WebSocket manager for real-time features in SYNO.
Handles connections, broadcasting, and online status.
"""
import json
import asyncio
from datetime import datetime, timedelta
from typing import Dict, Set, Optional
from fastapi import WebSocket
import logging

logger = logging.getLogger("syno.websocket")


class ConnectionManager:
    """Manages WebSocket connections and broadcasting."""

    def __init__(self):
        self._connections: Dict[int, WebSocket] = {}
        self._online_users: Set[int] = set()
        self._last_heartbeat: Dict[int, datetime] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        """Accept a new WebSocket connection."""
        await websocket.accept()
        self._connections[user_id] = websocket
        self._online_users.add(user_id)
        self._last_heartbeat[user_id] = datetime.utcnow()
        logger.info(f"User {user_id} connected via WebSocket")

    def disconnect(self, user_id: int):
        """Remove a WebSocket connection."""
        self._connections.pop(user_id, None)
        self._online_users.discard(user_id)
        self._last_heartbeat.pop(user_id, None)
        logger.info(f"User {user_id} disconnected from WebSocket")

    def is_online(self, user_id: int) -> bool:
        """Check if a user is online."""
        return user_id in self._online_users

    def get_online_users(self) -> Set[int]:
        """Get all online user IDs."""
        return self._online_users.copy()

    def update_heartbeat(self, user_id: int):
        """Update heartbeat timestamp for a user."""
        self._last_heartbeat[user_id] = datetime.utcnow()

    async def cleanup_stale_connections(self, timeout_seconds: int = 60):
        """Remove connections that haven't sent a heartbeat."""
        now = datetime.utcnow()
        stale_users = [
            user_id for user_id, last_beat in self._last_heartbeat.items()
            if (now - last_beat).total_seconds() > timeout_seconds
        ]
        for user_id in stale_users:
            self.disconnect(user_id)
            logger.info(f"Cleaned up stale connection for user {user_id}")

    async def send_to_user(self, user_id: int, message: dict):
        """Send a message to a specific user."""
        websocket = self._connections.get(user_id)
        if websocket:
            try:
                await websocket.send_json(message)
            except Exception as e:
                logger.error(f"Failed to send to user {user_id}: {e}")
                self.disconnect(user_id)

    async def broadcast_to_users(self, user_ids: Set[int], message: dict):
        """Send a message to multiple users."""
        for user_id in user_ids:
            await self.send_to_user(user_id, message)

    async def notify_new_like(self, liked_user_id: int, liker_name: str, score: int):
        """Notify a user that someone liked them."""
        await self.send_to_user(liked_user_id, {
            "type": "new_like",
            "liker_name": liker_name,
            "score": score,
            "timestamp": datetime.utcnow().isoformat(),
        })

    async def notify_mutual_match(self, user_id: int, matched_user_id: int, matched_name: str):
        """Notify both users of a mutual match."""
        await self.send_to_user(user_id, {
            "type": "mutual_match",
            "matched_user_id": matched_user_id,
            "matched_name": matched_name,
            "timestamp": datetime.utcnow().isoformat(),
        })
        await self.send_to_user(matched_user_id, {
            "type": "mutual_match",
            "matched_user_id": user_id,
            "matched_name": matched_name,
            "timestamp": datetime.utcnow().isoformat(),
        })

    async def notify_new_message(self, recipient_id: int, sender_id: int, sender_name: str, content: str):
        """Notify a user of a new message."""
        await self.send_to_user(recipient_id, {
            "type": "new_message",
            "sender_id": sender_id,
            "sender_name": sender_name,
            "content": content[:100],
            "timestamp": datetime.utcnow().isoformat(),
        })

    async def notify_typing(self, recipient_id: int, sender_id: int, is_typing: bool):
        """Notify a user that someone is typing."""
        await self.send_to_user(recipient_id, {
            "type": "typing",
            "sender_id": sender_id,
            "is_typing": is_typing,
            "timestamp": datetime.utcnow().isoformat(),
        })

    async def broadcast_online_status(self, user_ids: Set[int]):
        """Broadcast online status to a set of users."""
        online_list = list(self._online_users)
        await self.broadcast_to_users(user_ids, {
            "type": "online_status",
            "online_users": online_list,
            "timestamp": datetime.utcnow().isoformat(),
        })


manager = ConnectionManager()


async def websocket_endpoint(websocket: WebSocket, user_id: int):
    """Main WebSocket endpoint handler."""
    await manager.connect(websocket, user_id)
    try:
        while True:
            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=30)
                message = json.loads(data)

                if message.get("type") == "heartbeat":
                    manager.update_heartbeat(user_id)
                    await websocket.send_json({"type": "heartbeat_ack"})

                elif message.get("type") == "typing":
                    recipient_id = message.get("recipient_id")
                    if recipient_id:
                        await manager.notify_typing(recipient_id, user_id, message.get("is_typing", False))

                elif message.get("type") == "get_online":
                    await websocket.send_json({
                        "type": "online_status",
                        "online_users": list(manager.get_online_users()),
                    })

            except asyncio.TimeoutError:
                manager.update_heartbeat(user_id)

    except Exception as e:
        logger.error(f"WebSocket error for user {user_id}: {e}")
    finally:
        manager.disconnect(user_id)
