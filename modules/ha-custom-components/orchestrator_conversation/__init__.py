from __future__ import annotations

from datetime import datetime
from typing import Literal

from homeassistant.components import conversation
from homeassistant.components.conversation import AbstractConversationAgent, ConversationInput, ConversationResult
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import MATCH_ALL
from homeassistant.core import HomeAssistant
from homeassistant.helpers import entity_registry as er, intent
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from .const import DEFAULT_URL, DOMAIN


def _resolve_location(hass: HomeAssistant, device_id: str | None) -> str:
    """Best-effort physical location of the device that asked.

    A phone (HA Companion app) carries its own location entities, so a question
    asked from it should be answered relative to wherever the phone is. A fixed
    satellite (Atom Echo) has none, so we fall back to HA's configured home.
    Preference order: geocoded human-readable address > device GPS coordinates >
    home. This lets place/time-relative questions ("what's in the sky", local
    time/weather) follow the user as they travel — without hardcoding a city.
    """
    if device_id:
        entries = er.async_entries_for_device(
            er.async_get(hass), device_id, include_disabled_entities=False
        )
        # 1) Companion "geocoded location" sensor -> human-readable address.
        for entry in entries:
            if entry.entity_id.startswith("sensor.") and "geocoded_location" in entry.entity_id:
                state = hass.states.get(entry.entity_id)
                if state and state.state not in ("unknown", "unavailable", "", "None"):
                    return state.state
        # 2) A device_tracker on the device with live GPS coordinates.
        for entry in entries:
            if entry.entity_id.startswith("device_tracker."):
                state = hass.states.get(entry.entity_id)
                if not state:
                    continue
                lat = state.attributes.get("latitude")
                lon = state.attributes.get("longitude")
                if lat is not None and lon is not None:
                    zone = state.state if state.state not in ("not_home", "unknown", "unavailable") else None
                    coords = f"latitude {lat}, longitude {lon}"
                    return f"{zone} ({coords})" if zone and zone != "home" else coords
    # 3) Fixed device / unknown -> HA's configured home location.
    parts = [hass.config.location_name or "home"]
    if hass.config.latitude and hass.config.longitude:
        parts.append(f"latitude {hass.config.latitude}, longitude {hass.config.longitude}")
    if hass.config.time_zone:
        parts.append(f"timezone {hass.config.time_zone}")
    return ", ".join(parts)


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    agent = OrchestratorAgent(hass, entry)
    conversation.async_set_agent(hass, entry, agent)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    conversation.async_unset_agent(hass, entry)
    return True


class OrchestratorAgent(AbstractConversationAgent):
    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self.entry = entry
        self._url = entry.data.get("url", DEFAULT_URL)

    @property
    def supported_languages(self) -> list[str] | Literal["*"]:
        # The orchestrator forwards to Gemini, which is fully multilingual, so
        # accept any language HA hands us. This lets HA pair this agent with a
        # non-English Assist pipeline (e.g. a Portuguese one) — without it, HA
        # rejects the agent for any pipeline whose language isn't English, even
        # though Whisper (small-int8) already understands the speech.
        return MATCH_ALL

    async def async_process(self, user_input: ConversationInput) -> ConversationResult:
        now = datetime.now().strftime("%A, %B %-d %Y, %-I:%M %p")
        location = _resolve_location(self.hass, user_input.device_id)
        payload = {
            "model": "orchestrator",
            "conversation_id": user_input.conversation_id,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        f"Current date and time: {now}. "
                        f"The user is asking from this location: {location}. "
                        "Use it for any place- or time-relative question — local time, "
                        "weather, sunrise/sunset, what's in the sky, nearby places — "
                        "rather than assuming home. "
                        "You are a personal smart home and homelab voice assistant. "
                        "For general knowledge, translations, definitions, calculations, or anything "
                        "you can answer from your own knowledge or web search — answer directly, no tools needed. "
                        "Only call homelab_query for questions that require reading live state from the user's actual systems: "
                        "Jellyfin playback, server/service status, disk usage, logs, NixOS config, "
                        "network devices, Docker containers, or anything else that requires SSH or API access to the homelab. "
                        "Never say you lack an integration or can't check — just call homelab_query and let it find out. "
                        "If homelab_query returns an error or timeout, tell the user the homelab is unreachable and answer from what you know if possible. "
                        "LANtern monitors every device on the Deco router network. "
                        "For controlling the desk LED strip, use the desk_leds tool "
                        "(animations: rainbow, fire, pacifica, cylon, pride, demoreel, swell, fireworks, laser, waves; "
                        "glitter overlays: off, twinkle, drizzle, rain, snow, thunder; brightness 0-255; speed 1-10; mic on/off for audio-reactive mode). "
                        "Always respond in the same language the user spoke or wrote in "
                        "(e.g. reply in Portuguese if the user spoke Portuguese). "
                        "Keep spoken responses concise; you are answering via text-to-speech."
                    ),
                },
                {"role": "user", "content": user_input.text},
            ],
        }
        try:
            session = async_get_clientsession(self.hass)
            async with session.post(
                f"{self._url}/v1/chat/completions",
                json=payload,
                timeout=200,
            ) as resp:
                data = await resp.json()
                text = data["choices"][0]["message"]["content"]
                conv_id = data.get("conversation_id") or user_input.conversation_id
        except Exception as exc:  # noqa: BLE001
            text = f"Sorry, I couldn't reach the orchestrator: {exc}"
            conv_id = user_input.conversation_id

        response = intent.IntentResponse(language=user_input.language)
        response.async_set_speech(text)
        return ConversationResult(
            response=response,
            conversation_id=conv_id,
        )
