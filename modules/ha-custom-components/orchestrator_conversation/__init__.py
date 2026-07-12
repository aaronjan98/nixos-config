from __future__ import annotations

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
        payload = {
            "model": "orchestrator",
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "You are a smart home and homelab voice assistant. "
                        "For any question about the homelab — servers, services, disk, logs, NixOS config, "
                        "or network devices (LANtern monitors all devices on the Deco router network) — "
                        "always call the homelab_query tool instead of guessing. "
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
                timeout=60,
            ) as resp:
                data = await resp.json()
                text = data["choices"][0]["message"]["content"]
        except Exception as exc:  # noqa: BLE001
            text = f"Sorry, I couldn't reach the orchestrator: {exc}"

        response = intent.IntentResponse(language=user_input.language)
        response.async_set_speech(text)
        return ConversationResult(
            response=response,
            conversation_id=user_input.conversation_id,
        )
