

# 🍚 rice — Fish Rice Manager

A **declarative, atomic rice switcher** for Hyprland and Wayland desktop environments. Built on `chezmoi` for dotfile management and `dasel` for TOML parsing.

---

## ✨ Features

- **Declarative Manifests** — Each rice describes itself in `manifest.toml`
- **Atomic Switching** — Validates before touching anything; never leaves a half-switched system
- **Inheritance System** — Rices can inherit from a base rice (layered configuration)
- **Ghost Config Cleanup** — Automatically removes configs from the previous rice that aren't in the new one
- **Chezmoi Integration** — Works seamlessly with your existing dotfile workflow
- **Validation Layer** — `rice doctor` catches issues before they cause problems
- **Idempotent Operations** — Safe to run multiple times; scripts must handle re-runs gracefully

---

## 📦 Requirements

| Dependency | Purpose |
|------------|---------|
| `fish` | Shell runtime |
| `dasel` | TOML/JSON parsing |
| `jq` | JSON processing |
| `chezmoi` | Dotfile deployment |

---

## 🚀 Installation

### 1. Install dependencies

```fish
# Arch Linux
paru -S fish dasel jq chezmoi

# Or with yay
yay -S fish dasel-bin jq chezmoi
```

### 2. Clone the rice-switcher

```fish
# Option A: Into your fish functions directory
git clone https://github.com/Kanapech/rice-switcher.git /tmp/rice-switcher
cp /tmp/rice-switcher/rice.fish ~/.config/fish/functions/rice.fish

# Option B: Source it in your config.fish
curl -sL https://raw.githubusercontent.com/Kanapech/rice-switcher/master/rice.fish \
  > ~/.config/fish/conf.d/rice.fish
```

### 3. First run

```fish
rice list
# First run — where should the rice library live?
#  1) ~/.local/share/rices (XDG standard)
#  2) ~/dotfiles/rices (in-repo)
#  3) Custom path
```

---

## 📖 Usage

```
rice [command] [arguments]

Commands:
  switch <name>    Switch to a rice (validates first)
  list, ls         List all available rices
  status           Show active rice and symlink health
  doctor [name...] Validate one or more rices (all if no args)
```

### Examples

```fish
# List all rices
rice list

#  Available rices in ~/.local/share/rices:
#  
#    default         v1.0.0    Base desktop configuration
#  * ii              v2.3.1    Illogical Impulse rice
#    minimal         v0.5.0    Lightweight setup

# Switch to a rice
rice switch ii

#  --> Validating: ii
#   [ok]
#  ==> Switching: default → ii
#  --> chezmoi apply
#   [ok]
#  --> Teardown: default
#   [unlink] ~/.config/hypr/hyprlock.conf
#   [unlink] ~/.config/swaync/config.json
#  --> Setup: ii
#   [inherit] default
#   [link] hypr/hyprlock.conf → ~/.config/hypr/hyprlock.conf
#   [link] quickshell → ~/.config/quickshell
#  ==> Active rice: ii ✓

# Check symlink health
rice status

#  Active rice : ii
#  Rice base : ~/.local/share/rices
#  Author : end-4
#  Version : 2.3.1
#  Description : Illogical Impulse rice
#  Inherits : default
#  
#  Symlinks:
#   ✓ ~/.config/hypr/hyprlock.conf
#   ✓ ~/.config/quickshell
#   ✓ ~/.config/mako/config
#   ✗ ~/.config/ashell/config.toml (broken or missing)

# Validate all rices
rice doctor

#  --> Validating: default
#   [ok]
#  --> Validating: ii
#   [ok]
#  --> Validating: minimal
#   [error] manifest declares 'hypr/colors.conf' but path does not exist
#   [error] scripts/start.sh not executable (fix: chmod +x)
#  2 error(s) found.
```

---

## 📋 Manifest Specification

Each rice requires a `manifest.toml` in its root directory:

```toml
# ── Metadata (optional but recommended) ──────────────────────────────────
[metadata]
author = "Kanapech"
description = "Default rice — base desktop configuration"
version = "1.0.0"

# ── Symlinks (required) ───────────────────────────────────────────────────
# Format: "source_path" = "target_path"
# Source is relative to the rice directory
# Target is expanded (~ → $HOME)

[symlinks]
"hypr/hyprlock.conf" = "~/.config/hypr/hyprlock.conf"
"hypr/hypridle.conf" = "~/.config/hypr/hypridle.conf"
"quickshell" = "~/.config/quickshell"
"mako/config" = "~/.config/mako/config"
"swaync/config.json" = "~/.config/swaync/config.json"
"swaync/style.css" = "~/.config/swaync/style.css"

# ── Inheritance (optional) ────────────────────────────────────────────────
# Fall back to another rice for unlisted symlinks
# Target rice symlinks overwrite inherited ones

[inherit]
base = "default"

# ── Scripts (required) ────────────────────────────────────────────────────
# Must be executable (chmod +x)
# Must be idempotent (safe to run multiple times)

[scripts]
start = "scripts/start.sh"
stop = "scripts/stop.sh"
```

---

## 📁 Directory Structure

### Rice Library

```
~/.local/share/rices/          # or ~/dotfiles/rices
├── default/
│   ├── manifest.toml
│   ├── scripts/
│   │   ├── start.sh
│   │   └── stop.sh
│   ├── hypr/
│   │   ├── hyprlock.conf
│   │   └── hypridle.conf
│   ├── ashell/
│   │   └── config.toml
│   └── swaync/
│       ├── config.json
│       └── style.css
│
├── ii/
│   ├── manifest.toml
│   ├── scripts/
│   │   ├── start.sh
│   │   └── stop.sh
│   ├── hypr/
│   │   └── hyprlock.conf
│   └── quickshell/
│       └── modules/
│
└── minimal/
    └── ...
```

### Chezmoi Integration

```
~/.local/share/chezmoi/
├── dot_local/
│   └── share/
│       └── rices/              # Managed by chezmoi
│           ├── default/
│           └── ii/
├── dot_config/
│   └── hypr/
│       ├── hyprland.conf.tmpl  # Master template
│       ├── monitors.conf       # Rice-independent
│       └── workspaces.conf     # Rice-independent
└── .chezmoidata.toml          # Variables (rice.active)
```

---

## ⚙️ How It Works

### Switching Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         rice switch <name>                           │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  1. VALIDATE                                                        │
│     • Check manifest.toml exists                                    │
│     • Check scripts are executable                                  │
│     • Verify all symlink sources exist                              │
│     • Verify inherit target exists (if declared)                    │
│     • Abort on any error                                            │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. CHEZMOI APPLY                                                  │
│     • Update .chezmoidata.toml with new rice name                  │
│     • Deploy all files to ~/.local/share/rices/                    │
│     • Files must exist before symlinks point to them               │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. TEARDOWN (current rice)                                         │
│     • Run stop.sh                                                   │
│     • Remove ghost paths (in old, not in new)                      │
│     • Remove shared symlinks (will be re-created)                  │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. SETUP (new rice)                                               │
│     • Create inherited symlinks first (lower priority)             │
│     • Create target symlinks second (higher priority)              │
│     • Run start.sh                                                  │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│  5. PERSIST                                                         │
│     • Write rice name to ~/.config/rice-switcher/active            │
│     • Done ✓                                                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Inheritance Merge Order

```
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 1: Base Rice (e.g., "default")                               │
│           hyprlock.conf → ~/.config/hypr/hyprlock.conf              │
│           swaync → ~/.config/swaync                                 │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ (symlinks created)
┌─────────────────────────────────────────────────────────────────────┐
│  Layer 2: Target Rice (e.g., "ii")                                 │
│           hyprlock.conf → ~/.config/hypr/hyprlock.conf (OVERWRITES) │
│           quickshell → ~/.config/quickshell (NEW)                  │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                    Target rice always wins
```

---

## 📝 Script Contract

Your `start.sh` and `stop.sh` scripts **must be idempotent**:

### start.sh

```bash
#!/bin/bash
# Idempotent: safe to run multiple times

# Kill existing instances (don't fail if not running)
pkill -x ags || true
pkill -x swaync || true

# Start services
uwsm app -t service ags &
swaync &

# Wait for services to initialize
sleep 1
```

### stop.sh

```bash
#!/bin/bash
# Idempotent: safe to run multiple times

# Kill gracefully, then force
pkill -x ags || true
pkill -x swaync || true

# Clean up any leftover state
rm -f /tmp/ags.sock 2>/dev/null || true
```

---

## 🔧 Chezmoi Integration

### Master Template (`hyprland.conf.tmpl`)

```hyprlang
# ── Base config (rice-independent) ───────────────────────────────────────
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/workspaces.conf

# ── Rice entry point (symlink managed by rice-switcher) ──────────────────
source = ~/.config/hypr/rice.conf
```

### Data File (`.chezmoidata.toml`)

```toml
[rice]
active = "default"
```

---

## 🐛 Troubleshooting

### "source missing" error

```
[error] manifest declares 'hypr/colors.conf' but path does not exist
```

**Fix:** Ensure the file exists in your rice directory:
```fish
ls ~/.local/share/rices/default/hypr/colors.conf
```

### "not executable" error

```
[error] scripts/start.sh not executable (fix: chmod +x)
```

**Fix:**
```fish
chmod +x ~/.local/share/rices/default/scripts/start.sh
chmod +x ~/.local/share/rices/default/scripts/stop.sh
```

### "exists and is not a symlink" warning

```
[warn] ~/.config/quickshell exists and is not a symlink — skipping (backup manually)
```

**Fix:** The switcher refuses to overwrite real files/directories. Backup and remove:
```fish
mv ~/.config/quickshell ~/.config/quickshell.backup
rice switch default
```

### Broken symlinks after manual file deletion

```fish
rice status
# ✗ ~/.config/quickshell (broken or missing)

# Re-run chezmoi to restore files, then re-link
chezmoi apply
rice switch default
```

---

## 🙏 Acknowledgments

- [chezmoi](https://www.chezmoi.io/) — Dotfile management
- [dasel](https://github.com/TomWright/dasel) — TOML/JSON parsing
- [Fish shell](https://fishshell.com/) — The friendly interactive shell

---
