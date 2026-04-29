# mac-tools

A collection of small CLI tools I use on macOS — short shell/Python scripts that wrap common workflows: Bluetooth, audio, Wi-Fi, displays, DNS, YouTube downloads, notes, speech-to-text, system info, scene presets, academic papers, image generation, local LLM chat, plus CLI shells **and full SwiftUI source** for a personal Mac app suite (`dash`, `kanban`, `tafel`, `zeit`, `canwa`, `literatur`, `termine`).

> The scripts print German UI text (Hilfe, Statusmeldungen). Commands and flags are English. If you don't read German you'll still figure it out from the help screens.

## Install

```bash
git clone https://github.com/dennisjanvogt/mac-tools.git
cd mac-tools
./install.sh
```

`install.sh` symlinks:
- every script in `bin/` into `~/.local/bin/` (make sure that directory is on your `PATH`)
- every SwiftUI app source folder in `src/` into `~/.local/src/` (only relevant for the ConsultingOS apps — the `<tool> build` commands `swiftc` from there)

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

### ConsultingOS apps

CLI wrappers + full SwiftUI source for a personal Mac app suite that talks to my private API at `1o618.com`. The Swift sources live in `src/<name>/main.swift`; `install.sh` symlinks each `src/<name>/` into `~/.local/src/<name>/` so the build commands work.

```bash
kanban build       # swiftc src/kanban/main.swift  ->  ~/Applications/Kanban.app
kanban open        # auto-builds if missing
```

**The apps will still not be useful to anyone but me** — every authenticated request goes to `https://1o618.com`, which is private. They're published as a reference for: keychain-shared auth across multiple Mac apps (`com.dennis.consultingos` — logging out of any one logs out of all), single-file SwiftUI apps compiled with plain `swiftc` (no Xcode project), and bash REST clients reading the same auth token.

| Tool | What it does |
| --- | --- |
| `dash` | Dashboard cards (weather, stocks, crypto, wiki, news, image search, YouTube tiles, Kanban sync, system stats). Reads `SERPER_API_KEY` from `~/.config/keys/search.env` for search-related cards. |
| `kanban` | Kanban board: list cards, todo/in-progress filter, add, move, done, archive, rm. |
| `tafel` | Whiteboard (Excalidraw via WKWebView): list/new/rm diagrams, list projects. |
| `zeit` | Time tracking: start/stop timer, log, projects, clients, add manual entry, weekly/monthly summary. |
| `canwa` | Image editor — SwiftUI shell hosting a Vite/React bundle (`src/canwa-web/`). Run `cd src/canwa-web && npm install && npx vite build` once before `canwa build`. |
| `literatur` | Literature/PDF reader (PDFKit). |
| `termine` | Calendar/appointments: list (today/week/month), next, add, rm. |

Each Swift file is a single-file SwiftUI app (30k–278k lines of source) — no Xcode project, no SPM manifest. Build with `swiftc -parse-as-library -O -framework SwiftUI <main.swift>`; the CLI does that for you.

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
