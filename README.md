# mac-tools

A collection of small CLI tools I use on macOS — short shell/Python scripts that wrap common workflows: Bluetooth, audio, Wi-Fi, displays, DNS, YouTube downloads, notes, speech-to-text, system info, scene presets, academic papers, image generation, local LLM chat.

> The scripts print German UI text (Hilfe, Statusmeldungen). Commands and flags are English. If you don't read German you'll still figure it out from the help screens.

## Install

```bash
git clone https://github.com/dennisjanvogt/mac-tools.git
cd mac-tools
./install.sh
```

`install.sh` symlinks every script in `bin/` into `~/.local/bin/`. Make sure that directory is on your `PATH`.

To uninstall: `./install.sh --uninstall`.

## Tools

Run `<tool> help` (or `--help`) on any of these for the full command list.

### System & terminal
| Tool | What it does |
| --- | --- |
| `cs` | Pretty grid of which CLI tools you have installed (development, AI, cloud, editors, search, network, db, system, smart home, custom). |
| `pc` | One-screen system dashboard: hostname, OS, CPU, RAM, network, disk, battery, top processes, Ollama models, Docker containers. |

### Smart home / hardware
| Tool | Requires | What it does |
| --- | --- | --- |
| `bt` | `blueutil` | Bluetooth: list/connect/disconnect/switch devices, on/off/toggle, status. |
| `audio` | `switchaudio-osx` | Audio routing: switch input/output, list devices, set volume, mute. |
| `wifi` | — | Wi-Fi: status, list, connect, disconnect, on/off, password of current network, internal+external IP, speedtest. |
| `screen` | `brightness` (optional) | Display: dark/light mode, mirror, brightness, resolution, lock. |
| `elgato` | — | Elgato Key Light (mDNS auto-discovery): on/off, brightness, color temperature, favorites, fades. |
| `scene` | — | Cross-tool presets — chain `screen`, `elgato`, `bt`, `audio` etc. into named scenes (`movie`, `work`, `sleep`, …). Stored in `~/.config/scenes/`. |

### Network
| Tool | What it does |
| --- | --- |
| `dns` | DNS toolkit: lookup (A/AAAA/MX/NS/TXT), resolve, flush cache, current server, switch provider (Cloudflare / Google / Quad9 / DHCP), speed test. |

### Media & downloads
| Tool | Requires | What it does |
| --- | --- | --- |
| `dl` | `yt-dlp`, `ffmpeg` | Download presets: video, audio (mp3), best-quality, with subtitles, thumbnail-only, list formats. Files go to `~/Downloads`. |
| `dictate` | `whisper-cpp` | Push-to-talk speech-to-text. Records, transcribes via local Whisper, copies result to clipboard. |
| `whisper` | `whisper-cpp` | Plain whisper.cpp wrapper for any audio file. Models stored in `~/.whisper/`. |

### Notes & papers
| Tool | What it does |
| --- | --- |
| `note` | Quick markdown notes: add, edit, list, search, show, delete. Stored in `~/Documents/Notizen/`. |
| `paper` | Academic paper helper: search Semantic Scholar, fetch arXiv PDFs + auto-generated BibTeX, look up by DOI, list/open local papers. Files go to `~/Documents/Paper/`. |

### AI / ML (need Python + GPU/MPS)
| Tool | Requires | What it does |
| --- | --- | --- |
| `translate` | `transformers`, `sentencepiece`, `torch` | Many-to-many translation via mBART-50. |
| `generate-image` | `diffusers`, `torch` | Stable Diffusion 3 Medium image generation. |
| `llama` | `transformers`, `torch` | Local Llama 3.2-3B chat. |

## Dependencies in one shot

```bash
# Smart home / media
brew install blueutil switchaudio-osx brightness yt-dlp ffmpeg whisper-cpp

# AI tools (in a venv ideally)
pip install transformers sentencepiece torch diffusers
```

For `dictate` and `whisper`, drop ggml models into `~/.whisper/` (e.g. `ggml-base.bin`, `ggml-large-v3.bin`). See [whisper.cpp models](https://github.com/ggerganov/whisper.cpp/tree/master/models).

## Notes on `cs`

`cs` only displays tools that are actually on `$PATH`. The catalog inside `bin/cs` is opinionated — feel free to edit it (add/remove/rename rows) to match what you actually use.

## Notes on `scene`

On first run `scene` writes three example presets to `~/.config/scenes/` (`movie.sh`, `work.sh`, `sleep.sh`). Edit them, or `scene add <name>` to make new ones. Each preset is a plain shell script, so any CLI on your `PATH` works.

## License

MIT — see [LICENSE](LICENSE).
