# TOS13 Herzieningsworkshop — Miro Board Generator

Generates a fully structured bilingual (NL/EN) Miro workshop board for the TOS13
research proposal revision required by CLICKNL before **28 mei / May 28, 2026**.

## Board structure (7 frames)

| # | Frame | Doel / Goal |
|---|-------|-------------|
| 0 | Welkom & Context | CLICKNL-voorwaarden + deadline overzicht |
| 1 | Focus — Centrale Kennisvraag | De ÉÉN centrale onderzoeksvraag kiezen |
| 2 | MKB-behoeften | Concrete behoeften per MKB-partner in kaart brengen |
| 3 | Use Cases per Werkpakket | Use case + meetbaar resultaat per WP |
| 4 | Schaalbare Toepassingen | Impact × Inspanning matrix voor deliverables |
| 5 | Data, Standaarden & Samenwerking | Governance-protocol uitwerken |
| 6 | Regie & Programmastructuur | Hiërarchie + RACI-tabel |
| 7 | Acties & Deadline | Actietabel wie/wat/wanneer vóór 28 mei |

## Setup

### 1. Miro API key
1. Go to miro.com → Profile → Settings → Apps → Developer tools
2. Create a new app, enable **boards:write** scope
3. Copy the access token

### 2. Install dependency
```bash
pip install requests
```

### 3. Run
```bash
export MIRO_API_KEY="your_api_key_here"
python3 create_board.py
```

The script prints the board URL when done. Share the link with the consortium before the workshop.

## Workshop facilitation guide

**Aanbevolen tijdsindeling / Recommended timing (3 hours)**

| Tijd / Time | Frame | Duur |
|-------------|-------|------|
| 0:00 | 0 · Welkom & Context | 10 min |
| 0:10 | 1 · Focus: centrale kennisvraag | 30 min |
| 0:40 | 2 · MKB-behoeften | 30 min |
| 1:10 | *Pauze / Break* | 10 min |
| 1:20 | 3 · Use Cases per WP | 25 min |
| 1:45 | 4 · Schaalbare Toepassingen | 20 min |
| 2:05 | 5 · Data, Standaarden & Samenwerking | 20 min |
| 2:25 | 6 · Regie & Programmastructuur | 15 min |
| 2:40 | 7 · Acties & Deadline | 20 min |
| 3:00 | Einde / End | |

**Voorbereiding deelnemers / Participant prep:**
- Lees de CLICKNL-brief vóór de workshop
- MKB-partners: bedenk 2–3 concrete problemen die TOS13 voor jullie oplost
- WP-leads: schrijf je use case al op een sticky
