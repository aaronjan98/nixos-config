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
            "messages": [{"role": "user", "content": user_input.text}],
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
