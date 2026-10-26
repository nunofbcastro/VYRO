# Local vision model setup (Windows, Ollama)

## Ollama installation

- Installed with winget: `winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements --silent`
- Installed binary: `%LOCALAPPDATA%\Programs\Ollama\ollama.exe`
- Version reported by the binary and the server API: **0.40.11** (the version winget offered at install time; it is older than current Ollama releases).
- The server was started manually with `ollama serve` (it listens on `http://localhost:11434`).

## Models pulled

| Model | Size (`ollama list`) | Accepts images |
|---|---|---|
| `gemma3n:e2b` | 7.8 GB | Yes |
| `gemma3n:e4b` | 9.8 GB | Yes |
| `gemma3:4b` | 3.4 GB | Yes |

All three tags pulled successfully. Image input was tested via `/api/generate` with a 512x512 JPEG (the VYRO app icon, converted with Pillow).

## Latency on this machine

Intel Core Ultra 7 155H, CPU only (`PROCESSOR 100% CPU`). Single runs, so treat these as rough numbers:

- `gemma3n:e2b`: about 29 s warm for a one-sentence description (about 22 s of that was prompt/image processing). About 60 s for a JSON-format request, including the model load.
- `gemma3:4b`: about 80 s for a first (cold) run including ~19 s model load; about 80 s for the JSON request.
- `gemma3n:e4b`: about 187 s on the first (cold) run, including ~105 s model load; about 59 s prompt processing.

## Image support

All three models returned plausible descriptions of the image when an `images` array was sent, so none of them is text-only in this Ollama version. Caveat: the `gemma3:4b` and `gemma3n` answers both described the logo's general look correctly but the model names it inaccurately (e.g. "Verto" for the VYRO logo), so do not treat these models as reliable for reading brand names.

## `format: "json"`

Tested on `gemma3n:e2b` and `gemma3:4b`. Both returned a parseable JSON object with the requested keys. This was tested with one prompt and one image only.

## API call format

```http
POST http://localhost:11434/api/generate
Content-Type: application/json

{
  "model": "gemma3n:e2b",
  "prompt": "Describe this image in one sentence.",
  "images": ["<base64-encoded JPEG or PNG bytes>"],
  "stream": false,
  "options": { "temperature": 0.1 }
}
```

Add `"format": "json"` to request JSON output. The response contains `response` (the text), plus `total_duration`, `load_duration`, `prompt_eval_count`, `prompt_eval_duration`, `eval_count` and `eval_duration` (durations in nanoseconds).

Smoke-test script used: `C:\Users\Nuno\AppData\Local\Temp\vyro_eval\smoke.py` (outside the repo).
