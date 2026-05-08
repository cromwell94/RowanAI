import logging

from dotenv import load_dotenv

from livekit.agents import (
    Agent,
    AgentSession,
    AutoSubscribe,
    JobContext,
    JobRequest,
    WorkerOptions,
    cli,
)
from livekit.plugins import anthropic, deepgram, openai, silero

load_dotenv()

logger = logging.getLogger("rowan-agent")

SYSTEM_PROMPT = (
    "You are an avatar in a dating simulation app called Rowan. "
    "Stay in character based on the room name and context. "
    "Give short natural conversational responses under 2 sentences. "
    "Never break character."
)


async def entrypoint(ctx: JobContext) -> None:
    await ctx.connect(auto_subscribe=AutoSubscribe.AUDIO_ONLY)
    logger.info("connected to room %s", ctx.room.name)

    instructions = f"{SYSTEM_PROMPT}\n\nRoom: {ctx.room.name}"

    session = AgentSession(
        vad=silero.VAD.load(),
        stt=deepgram.STT(),
        llm=anthropic.LLM(model="claude-haiku-4-5-20251001"),
        tts=openai.TTS(),
    )

    agent = Agent(instructions=instructions)

    await session.start(agent=agent, room=ctx.room)


async def request_fnc(req: JobRequest) -> None:
    if req.room.name.startswith("sim-"):
        await req.accept()
    else:
        await req.reject()


if __name__ == "__main__":
    cli.run_app(
        WorkerOptions(
            entrypoint_fnc=entrypoint,
            request_fnc=request_fnc,
        )
    )
