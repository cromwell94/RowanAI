import logging
from dotenv import load_dotenv

from livekit.agents import (
    AutoSubscribe,
    JobContext,
    JobRequest,
    WorkerOptions,
    cli,
    llm,
)
from livekit.agents.voice_assistant import VoiceAssistant
from livekit.plugins import anthropic, deepgram, openai, silero

load_dotenv()

logger = logging.getLogger("rowan-agent")

SYSTEM_PROMPT = (
    "You are an avatar in a dating simulation app called Rowan. "
    "Stay in character based on the room name and context. "
    "Give short natural conversational responses under 2 sentences. "
    "Never break character."
)


async def entrypoint(ctx: JobContext):
    await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)
    logger.info("connected to room %s", ctx.room.name)

    initial_ctx = llm.ChatContext().append(
        role="system",
        text=f"{SYSTEM_PROMPT}\n\nRoom: {ctx.room.name}",
    )

    assistant = VoiceAssistant(
        vad=silero.VAD.load(),
        stt=deepgram.STT(),
        llm=anthropic.LLM(model="claude-haiku-4-5-20251001"),
        tts=openai.TTS(),
        chat_ctx=initial_ctx,
    )

    assistant.start(ctx.room)


async def request_fnc(req: JobRequest) -> None:
    if req.room.name.startswith("sim-"):
        await req.accept(entrypoint)
    else:
        await req.reject()


if __name__ == "__main__":
    cli.run_app(WorkerOptions(request_fnc=request_fnc))
