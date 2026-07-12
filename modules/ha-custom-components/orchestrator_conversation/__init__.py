from __future__ import annotations

from datetime import datetime

from homeassistant.components import conversation
from homeassistant.components.conversation import AbstractConversationAgent, ConversationInput, ConversationResult
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import intent
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from .const import DEFAULT_URL, DOMAIN


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
    def supported_languages(self) -> list[str]:
        return ["en"]

    async def async_process(self, user_input: ConversationInput) -> ConversationResult:
        now = datetime.now().strftime("%A, %B %-d %Y, %-I:%M %p")
        payload = {
            "model": "orchestrator",
            "conversation_id": user_input.conversation_id,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        f"Current date and time: {now}. "
                        "You are a personal smart home and homelab voice assistant. "
                        "You do NOT have direct knowledge of the user's home infrastructure — "
                        "you must ALWAYS call homelab_query for any question involving live state: "
                        "Jellyfin playback, server status, running services, disk usage, logs, "
                        "NixOS config, network devices, who is home, media, or ANYTHING that "
                        "requires reading the actual systems. Never say you lack an integration "
                        "or can't check — just call homelab_query and let it find out. "
                        "LANtern monitors every device on the Deco router network. "
                        "For controlling the desk LED strip, use the desk_leds tool "
                        "(animations: rainbow, fire, pacifica, cylon, pride, demoreel, swell, fireworks, laser, waves; "
                        "glitter overlays: off, twinkle, drizzle, rain, snow, thunder; brightness 0-255; speed 1-10; mic on/off for audio-reactive mode). "
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
