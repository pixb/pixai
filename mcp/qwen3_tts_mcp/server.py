#!/usr/bin/env python3
"""
Qwen3-TTS MCP Server

MCP Server for Qwen3-TTS API, exposing TTS functionality to AI tools.
"""
import os
import json
import shutil
import tempfile
from pathlib import Path
from typing import Optional, List, Dict, Any

import httpx
from pydantic import BaseModel, Field, ConfigDict
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("qwen3_tts")

TTS_BASE_URL = os.environ.get("TTS_BASE_URL", "http://localhost:8001")


class TextSplitInput(BaseModel):
    text: str = Field(..., description="Text to split into chunks", min_length=1)
    max_length: int = Field(default=100, description="Maximum characters per chunk", ge=10, le=2000)
    min_chunk_length: int = Field(default=50, description="Minimum chunk length for merging short chunks", ge=1, le=500)

    model_config = ConfigDict(str_strip_whitespace=True)


class ReferenceListInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)


class TTSGenerateInput(BaseModel):
    text: str = Field(..., description="Text to convert to speech", min_length=1)
    reference_name: Optional[str] = Field(default=None, description="Reference audio name (use either reference_name or reference_id)")
    reference_id: Optional[int] = Field(default=None, description="Reference audio ID (use either reference_name or reference_id)")
    language: str = Field(default="Auto", description="Language code (Auto, Chinese, English, etc.)")
    ref_text: str = Field(..., description="Reference text describing the audio content")
    exaggeration: Optional[float] = Field(default=None, description="Exaggeration level 0.0-1.0", ge=0.0, le=1.0)
    temperature: Optional[float] = Field(default=None, description="Sampling temperature 0.0-1.0", ge=0.0, le=1.0)
    instruct: Optional[str] = Field(default=None, description="Voice style instruction")
    speed_rate: Optional[float] = Field(default=None, description="Speech speed rate 0.5-2.0", ge=0.5, le=2.0)
    output_dir: Optional[str] = Field(default=None, description="Directory to save output audio file")

    model_config = ConfigDict(str_strip_whitespace=True)


class AudioMergeInput(BaseModel):
    files: List[str] = Field(..., description="List of audio file paths to merge (at least 2)", min_length=2)
    output_dir: Optional[str] = Field(default=None, description="Directory to save merged audio file")

    model_config = ConfigDict(str_strip_whitespace=True)


async def _make_request(method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
    url = f"{TTS_BASE_URL}{endpoint}"
    async with httpx.AsyncClient(timeout=1200.0) as client:
        response = await client.request(method, url, **kwargs)
        response.raise_for_status()
        content_type = response.headers.get("content-type", "")
        if "application/json" in content_type:
            return response.json()
        elif "audio" in content_type:
            return {"_binary": response.content, "_filename": response.headers.get("content-disposition", "audio.wav")}
        return {"_raw": response.text}


def _save_binary(content: bytes, filename: str, output_dir: Optional[str] = None) -> Dict[str, Any]:
    if output_dir:
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        file_path = output_path / filename
        with open(file_path, "wb") as f:
            f.write(content)
        return {"success": True, "file_path": str(file_path), "size": len(content)}
    else:
        import base64
        return {"success": True, "audio_base64": base64.b64encode(content).decode(), "size": len(content)}


@mcp.tool(
    name="text_split",
    annotations={
        "title": "Split Text into Chunks",
        "readOnlyHint": True,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": False
    }
)
async def text_split(params: TextSplitInput) -> str:
    """Split long text into smaller chunks suitable for TTS processing.

    This tool divides long text into shorter segments based on the max_length
    parameter. It attempts to split at natural boundaries like paragraphs,
    sentences, and clauses.

    Args:
        params (TextSplitInput): Input parameters containing:
            - text (str): The text to split
            - max_length (int): Maximum characters per chunk (default: 100)
            - min_chunk_length (int): Minimum chunk length for merging (default: 50)

    Returns:
        str: JSON-formatted result with success status and chunks array:
            {
                "success": true,
                "chunks": ["chunk1", "chunk2", ...],
                "chunk_count": 5,
                "original_length": 1000,
                "max_length": 100
            }
    """
    try:
        result = await _make_request(
            "POST",
            "/text/split",
            json={
                "text": params.text,
                "max_length": params.max_length,
                "min_chunk_length": params.min_chunk_length
            }
        )
        return json.dumps(result, indent=2, ensure_ascii=False)
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


@mcp.tool(
    name="reference_list",
    annotations={
        "title": "List Reference Audios",
        "readOnlyHint": True,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": False
    }
)
async def reference_list(params: ReferenceListInput) -> str:
    """List all saved reference audio presets.

    This tool retrieves all reference audio profiles that have been saved,
    including their parameters like language, exaggeration, temperature, etc.

    Args:
        params (ReferenceListInput): Empty input (no parameters required)

    Returns:
        str: JSON-formatted result with reference audio list:
            {
                "success": true,
                "data": [
                    {
                        "id": 1,
                        "name": "tianyuan",
                        "language": "Chinese",
                        "ref_text": "...",
                        "exaggeration": 0.5,
                        "temperature": 0.8,
                        "speed_rate": 1.0,
                        "instruct": "..."
                    }
                ]
            }
    """
    try:
        result = await _make_request("GET", "/tts/reference/list")
        if result.get("success") and result.get("data"):
            data = result["data"]
            result["default"] = next((r for r in data if r.get("is_default")), data[0] if data else None)
            result["choices"] = [{"id": r["id"], "name": r["name"]} for r in data]
        return json.dumps(result, indent=2, ensure_ascii=False)
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


@mcp.tool(
    name="tts_generate",
    annotations={
        "title": "Generate Speech from Text",
        "readOnlyHint": False,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": True
    }
)
async def tts_generate(params: TTSGenerateInput) -> str:
    """Generate speech audio from text using a saved reference audio.

    This tool converts text to speech using a reference audio profile.
    You must provide either reference_name or reference_id.

    Args:
        params (TTSGenerateInput): Input parameters containing:
            - text (str): Text to convert to speech (required)
            - reference_name (str): Name of reference audio (required if reference_id not provided)
            - reference_id (int): ID of reference audio (required if reference_name not provided)
            - language (str): Language code (default: Auto)
            - ref_text (str): Reference text describing the audio content
            - exaggeration (float): Emotion exaggeration 0.0-1.0 (optional)
            - temperature (float): Sampling temperature 0.0-1.0 (optional)
            - instruct (str): Voice style instruction (optional)
            - speed_rate (float): Speech speed 0.5-2.0 (optional)
            - output_dir (str): Directory to save output (optional, returns binary if not specified)

    Returns:
        str: JSON-formatted result:
            - With output_dir: {"success": true, "file_path": "/path/to/file.wav", "size": 12345}
            - Without output_dir: {"success": true, "audio_base64": "...", "size": 12345}
    """
    if not params.reference_name and not params.reference_id:
        return json.dumps({"success": False, "error": "Either reference_name or reference_id is required"})

    data = {"text": params.text, "language": params.language}
    if params.reference_name:
        data["reference_name"] = params.reference_name
    if params.reference_id:
        data["reference_id"] = params.reference_id
    if params.exaggeration is not None:
        data["exaggeration"] = params.exaggeration
    if params.temperature is not None:
        data["temperature"] = params.temperature
    if params.instruct:
        data["instruct"] = params.instruct
    if params.speed_rate is not None:
        data["speed_rate"] = params.speed_rate

    if params.ref_text:
        data["ref_text"] = params.ref_text
    else:
        try:
            ref_result = await _make_request("GET", "/tts/reference/list")
            if ref_result.get("success") and ref_result.get("data"):
                refs = ref_result["data"]
                target_ref = None
                if params.reference_id:
                    target_ref = next((r for r in refs if r.get("id") == params.reference_id), None)
                elif params.reference_name:
                    target_ref = next((r for r in refs if r.get("name") == params.reference_name), None)
                if target_ref:
                    data["ref_text"] = target_ref.get("ref_text", "")
                    if params.exaggeration is None and target_ref.get("exaggeration") is not None:
                        data["exaggeration"] = target_ref.get("exaggeration")
                    if params.temperature is None and target_ref.get("temperature") is not None:
                        data["temperature"] = target_ref.get("temperature")
                    if not params.instruct and target_ref.get("instruct"):
                        data["instruct"] = target_ref.get("instruct")
                    if params.speed_rate is None and target_ref.get("speed_rate") is not None:
                        data["speed_rate"] = target_ref.get("speed_rate")
                else:
                    return json.dumps({"success": False, "error": f"Reference not found: {params.reference_name or params.reference_id}"})
            else:
                return json.dumps({"success": False, "error": "Failed to fetch reference list"})
        except Exception as e:
            return json.dumps({"success": False, "error": f"Failed to get reference: {str(e)}"})

    try:
        response = await _make_request("POST", "/tts/generate", data=data)
        
        if "_binary" in response:
            import time
            filename = f"tts_{int(time.time())}.wav"
            output_dir = params.output_dir if params.output_dir else "output"
            result = _save_binary(response["_binary"], filename, output_dir)
            result["download_url"] = f"{TTS_BASE_URL}/audio/{filename}"
            return json.dumps(result, indent=2)
        
        return json.dumps(response, indent=2, ensure_ascii=False)
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


@mcp.tool(
    name="audio_merge",
    annotations={
        "title": "Merge Audio Files",
        "readOnlyHint": False,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": False
    }
)
async def audio_merge(params: AudioMergeInput) -> str:
    """Merge multiple audio files into a single audio file.

    This tool combines multiple audio segments into one file using ffmpeg.
    At least 2 files are required.

    Args:
        params (AudioMergeInput): Input parameters containing:
            - files (List[str]): List of audio file paths to merge (required, at least 2)
            - output_dir (str): Directory to save merged audio (optional)

    Returns:
        str: JSON-formatted result:
            - With output_dir: {"success": true, "file_path": "/path/to/merged.wav", "size": 12345}
            - Without output_dir: {"success": true, "audio_base64": "...", "size": 12345}
    """
    if len(params.files) < 2:
        return json.dumps({"success": False, "error": "At least 2 audio files are required"})

    output_dir = params.output_dir if params.output_dir else "output"

    try:
        files = []
        for file_path in params.files:
            files.append(("files", open(file_path, "rb")))
        
        url = f"{TTS_BASE_URL}/audio/merge"
        async with httpx.AsyncClient(timeout=1200.0) as client:
            response = await client.post(url, files=files)
            response.raise_for_status()
            
            content_type = response.headers.get("content-type", "")
            if "audio" in content_type:
                content_disposition = response.headers.get("content-disposition", "merged.wav")
                if "filename=" in content_disposition:
                    filename = content_disposition.split("filename=")[-1].strip('"')
                else:
                    filename = "merged.wav"
                result = _save_binary(response.content, filename, output_dir)
                result["download_url"] = f"{TTS_BASE_URL}/audio/{filename}"
                return json.dumps(result, indent=2)
            
            return json.dumps(response.json(), indent=2, ensure_ascii=False)
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})
    finally:
        for (_, f) in files:
            f.close()


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--help":
        print("Qwen3-TTS MCP Server")
        print("")
        print("Usage:")
        print("  python -m qwen3_tts_api.mcp.server")
        print("")
        print("Environment:")
        print("  TTS_BASE_URL  - Base URL of TTS service (default: http://localhost:8001)")
        print("  PYTHONPATH    - Path to project root (required)")
        print("")
        print("OpenCode Configuration:")
        print('  "mcp": {')
        print('    "qwen3-tts": {')
        print('      "type": "local",')
        print('      "command": ["uv", "run", "python", "-m", "qwen3_tts_mcp.server"],')
        print('      "environment": {')
        print('        "PYTHONPATH": "/path/to/qwen3-tts-api",')
        print('        "TTS_BASE_URL": "http://localhost:8001"')
        print("      }")
        print("    }")
        print("  }")
        print("")
        print("Start the TTS service first:")
        print("  python -m uvicorn src.qwen3_tts_api.main:app --host 0.0.0.0 --port 8001")
    else:
        mcp.run()
