#!/usr/bin/env python3
"""
TOS13 Herzieningsworkshop — Miro Board Generator
Fieldlab Circulair Textiel / CLICKNL

Creates a fully structured bilingual (NL/EN) Miro workshop board
with 7 frames addressing each CLICKNL revision condition.

Usage:
    export MIRO_API_KEY="your_api_key_here"
    python3 create_board.py

Requirements:
    pip install requests
"""

import os
import sys
import time
import requests

# ─── Configuration ────────────────────────────────────────────────────────────

API_KEY  = os.environ.get("MIRO_API_KEY", "")
BASE_URL = "https://api.miro.com/v2"

BOARD_NAME = "TOS13 Herzieningsworkshop | Revision Workshop — Fieldlab Circulair Textiel"
BOARD_DESC = (
    "Workshop om het TOS13 onderzoeksvoorstel te herzien op basis van de CLICKNL-voorwaarden. "
    "Deadline: 28 mei 2026 | Workshop to revise the TOS13 research proposal per CLICKNL conditions. "
    "Deadline: May 28, 2026."
)

# Frame grid: 2 columns, rows of frames
FRAME_W = 1800
FRAME_H = 1100
GAP_X   = 250
GAP_Y   = 200

# Color palette (frame accent colors)
COLORS = {
    "welcome":     "#1a237e",   # deep navy
    "focus":       "#6a1b9a",   # purple
    "mkb":         "#e65100",   # deep orange
    "usecases":    "#00695c",   # teal
    "scalable":    "#1b5e20",   # dark green
    "data":        "#01579b",   # dark blue
    "governance":  "#b71c1c",   # dark red
    "actions":     "#263238",   # blue grey
}

# Sticky note fill colors (Miro palette names)
STICKY = {
    "yellow":     "light_yellow",
    "green":      "light_green",
    "blue":       "light_blue",
    "pink":       "light_pink",
    "orange":     "light_orange",
    "cyan":       "cyan",
    "violet":     "violet",
    "gray":       "gray",
}


# ─── API Helpers ──────────────────────────────────────────────────────────────

def headers():
    return {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type":  "application/json",
        "Accept":        "application/json",
    }


def post(path: str, body: dict) -> dict:
    url = f"{BASE_URL}{path}"
    resp = requests.post(url, json=body, headers=headers())
    if not resp.ok:
        print(f"  ERROR {resp.status_code}: {resp.text[:300]}")
        resp.raise_for_status()
    time.sleep(0.15)   # respect rate limits
    return resp.json()


def create_board() -> str:
    body = {
        "name":        BOARD_NAME,
        "description": BOARD_DESC,
        "policy": {
            "permissionsPolicy": {
                "collaborationToolsStartAccess": "all_editors",
                "copyAccess": "anyone",
                "sharingAccess": "team_members_with_editing_rights",
            },
            "sharingPolicy": {
                "access": "edit",
                "teamAccess": "edit",
            },
        },
    }
    data = post("/boards", body)
    board_id  = data["id"]
    board_url = data.get("viewLink") or data.get("shareLink") or f"https://miro.com/app/board/{board_id}/"
    print(f"  Board created: {board_url}")
    return board_id


def add_frame(board_id: str, title: str, x: float, y: float,
              w: float = FRAME_W, h: float = FRAME_H, color: str = "#f5f5f5") -> str:
    body = {
        "type":  "frame",
        "title": title,
        "style": {"fillColor": color},
        "geometry": {"width": w, "height": h},
        "position": {"x": x, "y": y, "origin": "center"},
    }
    return post(f"/boards/{board_id}/frames", body)["id"]


def add_text(board_id: str, content: str, x: float, y: float,
             width: float = 800, font_size: int = 18,
             color: str = "#1a1a1a", bold: bool = False, align: str = "left") -> str:
    style = {
        "color":     color,
        "fontSize":  str(font_size),
        "textAlign": align,
        "fontFamily": "open_sans",
    }
    if bold:
        style["fontWeight"] = "bold"
    body = {
        "data":     {"content": content},
        "style":    style,
        "geometry": {"width": width},
        "position": {"x": x, "y": y, "origin": "center"},
    }
    return post(f"/boards/{board_id}/texts", body)["id"]


def add_sticky(board_id: str, content: str, x: float, y: float,
               color: str = "light_yellow", width: float = 220) -> str:
    body = {
        "data":     {"content": content, "shape": "square"},
        "style":    {"fillColor": color, "textAlign": "left", "textAlignVertical": "top"},
        "geometry": {"width": width},
        "position": {"x": x, "y": y, "origin": "center"},
    }
    return post(f"/boards/{board_id}/sticky_notes", body)["id"]


def add_shape(board_id: str, shape: str, x: float, y: float,
              w: float, h: float, fill: str = "#e3f2fd",
              border: str = "#1565c0", content: str = "") -> str:
    body = {
        "data":     {"shape": shape, "content": content},
        "style":    {"fillColor": fill, "borderColor": border, "borderWidth": "2",
                     "textAlign": "center", "textAlignVertical": "middle",
                     "fontSize": "16", "fontFamily": "open_sans"},
        "geometry": {"width": w, "height": h},
        "position": {"x": x, "y": y, "origin": "center"},
    }
    return post(f"/boards/{board_id}/shapes", body)["id"]


# ─── Frame Builders ───────────────────────────────────────────────────────────

def frame_origin(col: int, row: int):
    """Top-left corner of a frame in the 2-column grid."""
    x = col * (FRAME_W + GAP_X)
    y = row * (FRAME_H + GAP_Y)
    cx = x + FRAME_W / 2
    cy = y + FRAME_H / 2
    return x, y, cx, cy


def build_welcome(board_id: str, col: int, row: int):
    """Frame 0 — Welkom & Context / Welcome & Context"""
    x0, y0, cx, cy = frame_origin(col, row)
    color = "#e8eaf6"
    add_frame(board_id, "0 · Welkom & Context | Welcome & Context",
              cx, cy, color=color)

    add_text(board_id,
             "TOS13 — Fieldlab Circulair Textiel",
             cx, y0 + 70, width=1600, font_size=32, bold=True, align="center", color=COLORS["welcome"])

    add_text(board_id,
             "Herzieningsworkshop | Revision Workshop",
             cx, y0 + 130, width=1600, font_size=22, align="center", color="#5c6bc0")

    conditions_nl = (
        "📋 CLICKNL-voorwaarden voor definitieve toekenning:\n\n"
        "1. Breng meer focus — wat is de centrale kennisvraag?\n"
        "2. Werk uit hoe afspraken over data & standaarden tot stand komen\n"
        "3. Laat concreet zien wat MKB-bedrijven eraan hebben\n"
        "4. Borgen van concrete MKB-behoeften in het voorstel\n"
        "5. Duidelijkheid over use cases & meetbare resultaten per werkpakket\n"
        "6. Inzicht in direct inzetbare, schaalbare toepassingen\n"
        "7. Concreetheid over regie & programmastructuur"
    )
    add_text(board_id, conditions_nl,
             x0 + 50 + 450, y0 + 230, width=880, font_size=15, color="#1a237e")

    conditions_en = (
        "📋 CLICKNL conditions for final approval:\n\n"
        "1. Add focus — what is the single main research question?\n"
        "2. Explain how data sharing, standards & collaboration agreements are formed\n"
        "3. Concretely show what SME businesses get from the project\n"
        "4. Anchor concrete SME needs in the proposal\n"
        "5. Clarify use cases & measurable results per work package\n"
        "6. Show which directly deployable, scalable applications will be delivered\n"
        "7. Concreteness on governance & program structure"
    )
    add_text(board_id, conditions_en,
             x0 + 50 + 1350, y0 + 230, width=880, font_size=15, color="#283593")

    # Deadline banner
    add_shape(board_id, "rectangle",
              cx, y0 + FRAME_H - 80, w=700, h=60,
              fill="#b71c1c", border="#b71c1c",
              content="⏰  Deadline: 28 mei / May 28, 2026")

    add_text(board_id,
             "Deelnemers / Participants: heel consortium  |  Facilitator: Troy, Jaap, Borre",
             cx, y0 + FRAME_H - 30, width=1400, font_size=13,
             color="#757575", align="center")


def build_focus(board_id: str, col: int, row: int):
    """Frame 1 — Focus: Centrale Kennisvraag / Main Research Question"""
    x0, y0, cx, cy = frame_origin(col, row)
    color = "#f3e5f5"
    add_frame(board_id, "1 · Focus — Centrale Kennisvraag | Main Research Question",
              cx, cy, color=color)

    add_text(board_id,
             "Wat is de ÉÉNE centrale kennisvraag van TOS13?\n"
             "What is the ONE central research question of TOS13?",
             cx, y0 + 60, width=1600, font_size=20, bold=True,
             align="center", color=COLORS["focus"])

    add_text(board_id,
             "Instructie / Instruction: Plak je sticky op de meest passende thema-zone. "
             "Voteer daarna met een dot op jouw top-3. Sluit af met één gezamenlijke beslissing.\n"
             "Stick your note in the most fitting zone. Vote with a dot for your top-3. Close with one shared decision.",
             cx, y0 + 120, width=1600, font_size=13, color="#6a1b9a")

    zones = [
        ("💾 Data Delen\nData Sharing",   "#e8eaf6", "#5c6bc0"),
        ("🤝 Sectorale Samenwerking\nSector Collaboration", "#e1f5fe", "#0277bd"),
        ("🤖 AI & Digitalisering\nAI & Digitalisation", "#e8f5e9", "#2e7d32"),
        ("♻️ Circulair Werken\nCircular Working", "#fff3e0", "#e65100"),
    ]
    zone_w, zone_h = 380, 480
    zone_gap = 30
    total_w = 4 * zone_w + 3 * zone_gap
    zone_start_x = cx - total_w / 2 + zone_w / 2

    for i, (label, fill, border) in enumerate(zones):
        zx = zone_start_x + i * (zone_w + zone_gap)
        add_shape(board_id, "rectangle", zx, y0 + 390,
                  w=zone_w, h=zone_h, fill=fill, border=border, content=label)
        # Two blank stickies per zone as prompts
        add_sticky(board_id, "Voeg hier toe / Add here…",
                   zx - 70, y0 + 370, color=list(STICKY.values())[i], width=180)
        add_sticky(board_id, "Voeg hier toe / Add here…",
                   zx + 70, y0 + 420, color=list(STICKY.values())[i], width=180)

    # Decision box
    add_shape(board_id, "rectangle",
              cx, y0 + FRAME_H - 100, w=1400, h=100,
              fill="#ede7f6", border="#6a1b9a",
              content="✅  Besluit / Decision: Onze centrale kennisvraag is… | Our central research question is…")


def build_mkb(board_id: str, col: int, row: int):
    """Frame 2 — MKB-behoeften / SME Needs"""
    x0, y0, cx, cy = frame_origin(col, row)
    color = "#fff3e0"
    add_frame(board_id, "2 · MKB-behoeften | SME Needs",
              cx, cy, color=color)

    add_text(board_id,
             "Wat zijn de concrete behoeften van MKB-bedrijven in dit project?\n"
             "What are the concrete needs of SME businesses in this project?",
             cx, y0 + 60, width=1600, font_size=20, bold=True,
             align="center", color=COLORS["mkb"])

    add_text(board_id,
             "Instructie / Instruction: Elke MKB-partner vult zijn eigen kolom in. "
             "Gebruik de 4 vragen als leidraad. | Each SME partner fills their own column. "
             "Use the 4 questions as a guide.",
             cx, y0 + 120, width=1600, font_size=13, color="#e65100")

    headers_row = [
        "Vraag / Question",
        "MKB Partner A",
        "MKB Partner B",
        "MKB Partner C",
        "MKB Partner D",
    ]
    col_w = 300
    header_x = x0 + 50 + col_w / 2
    row_qs = [
        "1. Welk probleem lost dit op?\nWhat problem does this solve?",
        "2. Welke data wil je delen?\nWhat data will you share?",
        "3. Wat levert het op (€/€)?\nWhat is your ROI?",
        "4. Wat heb je nodig om mee te doen?\nWhat do you need to participate?",
    ]
    row_h = 120
    table_top = y0 + 175

    # Column headers
    for i, h in enumerate(headers_row):
        hx = header_x + i * col_w
        add_shape(board_id, "rectangle", hx, table_top,
                  w=col_w - 10, h=50,
                  fill="#e65100" if i == 0 else "#fff8f5",
                  border="#e65100",
                  content=h)

    # Row questions + empty cells
    for r, q in enumerate(row_qs):
        ry = table_top + 50 + r * row_h + row_h / 2
        add_shape(board_id, "rectangle",
                  header_x, ry, w=col_w - 10, h=row_h - 10,
                  fill="#fff3e0", border="#e65100", content=q)
        for c in range(1, 5):
            cx_ = header_x + c * col_w
            add_sticky(board_id, "", cx_, ry,
                       color=STICKY["orange"], width=200)

    # Synthesis box
    add_shape(board_id, "rectangle",
              cx, y0 + FRAME_H - 90, w=1500, h=80,
              fill="#ffe0b2", border="#e65100",
              content="🔑  Top-3 gemeenschappelijke MKB-behoeften | Top-3 shared SME needs:\n"
                      "  1.                     2.                     3.")


def build_usecases(board_id: str, col: int, row: int):
    """Frame 3 — Use Cases per Werkpakket / Use Cases per Work Package"""
    x0, y0, cx, cy = frame_origin(col, row)
    color = "#e0f2f1"
    add_frame(board_id, "3 · Use Cases per Werkpakket | Use Cases per Work Package",
              cx, cy, color=color)

    add_text(board_id,
             "Welke concrete use case en meetbaar resultaat heeft elk werkpakket?\n"
             "What concrete use case and measurable result does each work package have?",
             cx, y0 + 60, width=1600, font_size=20, bold=True,
             align="center", color=COLORS["usecases"])

    add_text(board_id,
             "Instructie / Instruction: Vul per WP een use case in, het meetbare resultaat en de doorlooptijd. "
             "| Fill in per WP a use case, the measurable result, and the timeline.",
             cx, y0 + 120, width=1600, font_size=13, color="#00695c")

    wps = ["WP1", "WP2", "WP3", "WP4"]
    wp_labels = {
        "WP1": "Datadeling\nData Sharing",
        "WP2": "Standaardisering\nStandardisation",
        "WP3": "AI & Tools\nAI & Tools",
        "WP4": "Implementatie\nImplementation",
    }
    wp_colors = ["#e8f5e9", "#e1f5fe", "#f3e5f5", "#fff3e0"]
    wp_borders = ["#2e7d32", "#0277bd", "#6a1b9a", "#e65100"]

    wp_w = 400
    total_wp = 4 * wp_w + 3 * 20
    wp_start = cx - total_wp / 2 + wp_w / 2

    sub_rows = [
        ("🎯 Use Case", STICKY["green"]),
        ("📏 Meetbaar resultaat\nMeasurable result", STICKY["blue"]),
        ("⏱ Tijdlijn / Timeline", STICKY["yellow"]),
        ("👤 Verantwoordelijke\nResponsible party", STICKY["pink"]),
    ]
    wp_top = y0 + 175

    for i, wp in enumerate(wps):
        wpx = wp_start + i * (wp_w + 20)
        # Header
        add_shape(board_id, "rectangle", wpx, wp_top,
                  w=wp_w - 10, h=60,
                  fill=wp_colors[i], border=wp_borders[i],
                  content=f"{wp}\n{wp_labels[wp]}")
        # Sub rows
        for j, (label, sc) in enumerate(sub_rows):
            ry = wp_top + 60 + j * 165 + 82
            add_shape(board_id, "rectangle", wpx, ry,
                      w=wp_w - 10, h=30,
                      fill=wp_borders[i], border=wp_borders[i],
                      content=label)
            add_sticky(board_id, "", wpx, ry + 80, color=sc, width=300)

    add_shape(board_id, "rectangle",
              cx, y0 + FRAME_H - 60, w=1500, h=55,
              fill="#e0f2f1", border="#00695c",
              content="💡 Welke WP-resultaten zijn het meest concreet en meetbaar? "
                      "| Which WP results are most concrete and measurable?")


def build_scalable(board_id: str, col: int, row: int):
    """Frame 4 — Schaalbare Toepassingen / Scalable Applications"""
    x0, y0, cx, cy = frame_origin(col, row)
    color = "#e8f5e9"
    add_frame(board_id, "4 · Schaalbare Toepassingen | Scalable Applications",
              cx, cy, color=color)

    add_text(board_id,
             "Welke direct inzetbare, schaalbare toepassingen leveren we op?\n"
             "Which immediately deployable, scalable applications will we deliver?",
             cx, y0 + 60, width=1600, font_size=20, bold=True,
             align="center", color=COLORS["scalable"])

    add_text(board_id,
             "Instructie / Instruction: Plot elke toepassing op de Impact × Inspanning matrix. "
             "Bespreek de top-3 quick wins. | Plot each application on the Impact × Effort matrix. "
             "Discuss the top-3 quick wins.",
             cx, y0 + 120, width=1600, font_size=13, color="#1b5e20")

    # 2×2 matrix
    matrix_cx, matrix_cy = cx - 350, cy + 30
    matrix_half = 280

    add_shape(board_id, "rectangle", matrix_cx - matrix_half / 2, matrix_cy - matrix_half / 2,
              w=matrix_half, h=matrix_half,
              fill="#c8e6c9", border="#2e7d32",
              content="⭐ Quick Wins\nHoge impact, lage inspanning\nHigh impact, low effort")
    add_shape(board_id, "rectangle", matrix_cx + matrix_half / 2, matrix_cy - matrix_half / 2,
              w=matrix_half, h=matrix_half,
              fill="#f1f8e9", border="#558b2f",
              content="🏗 Grote projecten\nHoge impact, hoge inspanning\nHigh impact, high effort")
    add_shape(board_id, "rectangle", matrix_cx - matrix_half / 2, matrix_cy + matrix_half / 2,
              w=matrix_half, h=matrix_half,
              fill="#fff9c4", border="#f9a825",
              content="✓ Invullers\nLage impact, lage inspanning\nLow impact, low effort")
    add_shape(board_id, "rectangle", matrix_cx + matrix_half / 2, matrix_cy + matrix_half / 2,
              w=matrix_half, h=matrix_half,
              fill="#ffccbc", border="#e64a19",
              content="✗ Vermijden\nLage impact, hoge inspanning\nLow impact, high effort")

    add_text(board_id, "⬆ Impact", matrix_cx - matrix_half - 40, matrix_cy,
             width=100, font_size=13, bold=True, color="#1b5e20")
    add_text(board_id, "➡ Inspanning / Effort", matrix_cx, matrix_cy + matrix_half + 30,
             width=400, font_size=13, bold=True, color="#1b5e20", align="center")

    # Application list on the right
    list_x = cx + 280
    add_text(board_id, "📱 Lijst van toepassingen / Application list\n(kopieer sticky's naar de matrix)",
             list_x, y0 + 200, width=600, font_size=15, bold=True, color="#1b5e20")
    for i in range(6):
        add_sticky(board_id, f"Toepassing {i+1} / Application {i+1}…",
                   list_x + (i % 2) * 220 - 110, y0 + 300 + (i // 2) * 160,
                   color=STICKY["green"], width=200)

    add_shape(board_id, "rectangle",
              cx, y0 + FRAME_H - 60, w=1500, h=55,
              fill="#dcedc8", border="#558b2f",
              content="🚀 Top-3 quick wins die we toezeggen in het herziene voorstel: "
                      "| Top-3 quick wins we commit to in the revised proposal:  1.  2.  3.")


def build_data_standards(board_id: str, col: int, row: int):
    """Frame 5 — Data, Standaarden & Samenwerking / Data, Standards & Collaboration"""
    x0, y0, cx, cy = frame_origin(col, row)
    color = "#e3f2fd"
    add_frame(board_id, "5 · Data, Standaarden & Samenwerking | Data, Standards & Collaboration",
              cx, cy, color=color)

    add_text(board_id,
             "Hoe komen afspraken over data, standaarden en samenwerking tot stand?\n"
             "How are agreements on data, standards, and collaboration formed?",
             cx, y0 + 60, width=1600, font_size=20, bold=True,
             align="center", color=COLORS["data"])

    add_text(board_id,
             "Instructie / Instruction: Beantwoord de 3 kernvragen in de kolommen. "
             "Gebruik de governance-rollen voor wie beslist. "
             "| Answer the 3 core questions in the columns. Use governance roles for who decides.",
             cx, y0 + 120, width=1600, font_size=13, color="#01579b")

    col_labels = [
        ("💾 Data\nAfspraken / Agreements", "#bbdefb", "#1565c0"),
        ("📐 Standaarden\nStandards", "#e3f2fd", "#1976d2"),
        ("🤝 Samenwerking\nCollaboration", "#e1f5fe", "#0288d1"),
    ]
    sub_qs = [
        "Welke data?\nWhich data?",
        "Wie heeft toegang?\nWho has access?",
        "Hoe wordt besloten?\nHow are decisions made?",
        "Welk protocol?\nWhich protocol?",
        "Wie handhaaft?\nWho enforces?",
    ]

    col_w = 520
    col_start = cx - col_w + 30
    table_top = y0 + 175

    for i, (label, fill, border) in enumerate(col_labels):
        cx_ = col_start + i * (col_w + 10)
        add_shape(board_id, "rectangle", cx_, table_top,
                  w=col_w, h=60, fill=border, border=border, content=label)
        for j, q in enumerate(sub_qs):
            ry = table_top + 60 + j * 110 + 55
            add_shape(board_id, "rectangle", cx_, ry,
                      w=col_w, h=25, fill=fill, border=border, content=q)
            add_sticky(board_id, "", cx_, ry + 50,
                       color=STICKY["blue"], width=400)

    add_shape(board_id, "rectangle",
              cx, y0 + FRAME_H - 60, w=1500, h=55,
              fill="#bbdefb", border="#1565c0",
              content="📄 Concrete afspraak die in het voorstel staat: "
                      "| Concrete agreement that goes in the proposal: ___________________")


def build_governance(board_id: str, col: int, row: int):
    """Frame 6 — Regie & Programmastructuur / Governance & Program Structure"""
    x0, y0, cx, cy = frame_origin(col, row)
    color = "#ffebee"
    add_frame(board_id, "6 · Regie & Programmastructuur | Governance & Program Structure",
              cx, cy, color=color)

    add_text(board_id,
             "Wie stuurt TOS13 aan en hoe is het programma gestructureerd?\n"
             "Who leads TOS13 and how is the program structured?",
             cx, y0 + 60, width=1600, font_size=20, bold=True,
             align="center", color=COLORS["governance"])

    add_text(board_id,
             "Instructie / Instruction: Teken de governance-structuur en vul de RACI-tabel in. "
             "| Draw the governance structure and fill in the RACI table.",
             cx, y0 + 120, width=1600, font_size=13, color="#b71c1c")

    # Governance hierarchy
    roles = [
        ("Stuurgroep\nSteering Committee", cx, y0 + 210, "#c62828", "#ffcdd2"),
        ("Programmamanager\nProgram Manager", cx - 350, y0 + 320, "#b71c1c", "#ffebee"),
        ("Wetenschappelijk coördinator\nScientific Coordinator", cx + 350, y0 + 320, "#b71c1c", "#ffebee"),
        ("WP1 Lead", cx - 550, y0 + 430, "#e53935", "#fff5f5"),
        ("WP2 Lead", cx - 180, y0 + 430, "#e53935", "#fff5f5"),
        ("WP3 Lead", cx + 180, y0 + 430, "#e53935", "#fff5f5"),
        ("WP4 Lead", cx + 550, y0 + 430, "#e53935", "#fff5f5"),
    ]
    for label, rx, ry, border, fill in roles:
        add_shape(board_id, "round_rectangle", rx, ry,
                  w=280, h=70, fill=fill, border=border, content=label)

    # RACI table
    raci_top = y0 + 540
    raci_headers = ["Activiteit / Activity", "Stuurgroep", "Prog.mgr", "WP Lead", "Partners"]
    raci_rows = [
        "Strategische beslissingen\nStrategic decisions",
        "Dagelijkse aansturing\nDay-to-day management",
        "Rapportage aan CLICKNL\nReporting to CLICKNL",
        "Data-afspraken\nData agreements",
        "MKB-betrokkenheid\nSME engagement",
    ]
    col_w_r = 300
    for i, h in enumerate(raci_headers):
        hx = x0 + 50 + col_w_r * i + col_w_r / 2
        add_shape(board_id, "rectangle", hx, raci_top,
                  w=col_w_r - 5, h=40,
                  fill="#b71c1c" if i == 0 else "#ffebee",
                  border="#b71c1c", content=h)
    for r, row_label in enumerate(raci_rows):
        ry = raci_top + 40 + r * 60 + 30
        for c in range(len(raci_headers)):
            rx_ = x0 + 50 + col_w_r * c + col_w_r / 2
            if c == 0:
                add_shape(board_id, "rectangle", rx_, ry,
                          w=col_w_r - 5, h=55,
                          fill="#fff5f5", border="#b71c1c", content=row_label)
            else:
                add_shape(board_id, "rectangle", rx_, ry,
                          w=col_w_r - 5, h=55,
                          fill="#ffffff", border="#e57373",
                          content="R / A / C / I")


def build_actions(board_id: str, col: int, row: int):
    """Frame 7 — Acties & Deadline / Actions & Deadline (full-width)"""
    x0, y0, cx, cy = frame_origin(col, row)
    fw = FRAME_W * 2 + GAP_X  # full width
    color = "#eceff1"
    add_frame(board_id, "7 · Acties & Deadline | Actions & Deadline",
              cx + (FRAME_W + GAP_X) / 2, cy, w=fw, h=FRAME_H, color=color)

    real_cx = cx + (FRAME_W + GAP_X) / 2

    add_text(board_id,
             "⏰  Deadline: 28 mei / May 28, 2026  |  Inleveren bij: Marijke (cc Marjolein, Bart)",
             real_cx, y0 + 55, width=3000, font_size=28, bold=True,
             align="center", color="#b71c1c")

    add_text(board_id,
             "Wie doet wat vóór 28 mei? | Who does what before May 28?",
             real_cx, y0 + 110, width=3000, font_size=18,
             align="center", color="#263238")

    # Action table
    table_top = y0 + 150
    cols = [
        ("#  Actie / Action", 900),
        ("Wie / Who", 280),
        ("Wanneer / When", 250),
        ("Status", 200),
    ]
    col_x = x0 + 30
    for label, w in cols:
        add_shape(board_id, "rectangle",
                  col_x + w / 2, table_top,
                  w=w - 10, h=45,
                  fill="#263238", border="#263238", content=label)
        col_x += w

    action_rows = [
        ("1  Focus: schrijf de centrale kennisvraag als één zin uit\n"
         "    Write the central research question as one sentence", "Troy/Jaap/Borre", "vóór 10 mei", "⬜"),
        ("2  Data & standaarden: beschrijf het governance-protocol\n"
         "    Describe the data-sharing governance protocol", "…", "vóór 12 mei", "⬜"),
        ("3  MKB-behoeften: verwerk input van vandaag in voorstel\n"
         "    Incorporate today's SME input into the proposal", "…", "vóór 15 mei", "⬜"),
        ("4  Use cases: voeg meetbare KPI per WP toe\n"
         "    Add measurable KPI per work package", "…", "vóór 17 mei", "⬜"),
        ("5  Schaalbare toepassingen: beschrijf top-3 deliverables\n"
         "    Describe top-3 deliverable applications", "…", "vóór 19 mei", "⬜"),
        ("6  Regie: werk governance-structuur en RACI uit\n"
         "    Elaborate governance structure and RACI", "…", "vóór 21 mei", "⬜"),
        ("7  Review & consolidatie addendum — finaliseren\n"
         "    Review & consolidate addendum — finalise", "Troy/Jaap/Borre", "vóór 26 mei", "⬜"),
        ("8  Indienen bij Marijke (cc Marjolein, Bart)\n"
         "    Submit to Marijke (cc Marjolein, Bart)", "Troy", "28 mei", "⬜"),
    ]

    row_fill = ["#f5f5f5", "#eeeeee"]
    for r, (action, who, when, status) in enumerate(action_rows):
        ry = table_top + 45 + r * 75 + 37
        col_x = x0 + 30
        for ci, (_, w) in enumerate(cols):
            content = [action, who, when, status][ci]
            add_shape(board_id, "rectangle",
                      col_x + w / 2, ry,
                      w=w - 10, h=70,
                      fill=row_fill[r % 2], border="#b0bec5",
                      content=content)
            col_x += w

    add_text(board_id,
             "💡 Tip: zet afgehandelde acties op ✅ en wijs een eigenaar aan vóór het einde van de workshop.\n"
             "Tip: mark completed actions ✅ and assign an owner before the end of the workshop.",
             real_cx, y0 + FRAME_H - 40, width=3000,
             font_size=13, color="#546e7a", align="center")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    if not API_KEY:
        print("❌  Set MIRO_API_KEY environment variable first.")
        print("    export MIRO_API_KEY='your_key_here'")
        sys.exit(1)

    print("🎨  Creating TOS13 Revision Workshop Miro board…")
    board_id = create_board()

    frames = [
        ("Welcome",       build_welcome,      0, 0),
        ("Focus",         build_focus,        1, 0),
        ("MKB Needs",     build_mkb,          0, 1),
        ("Use Cases",     build_usecases,     1, 1),
        ("Scalable Apps", build_scalable,     0, 2),
        ("Data/Standards",build_data_standards, 1, 2),
        ("Governance",    build_governance,   0, 3),
        ("Actions",       build_actions,      0, 4),  # full-width
    ]

    for name, builder, col, row in frames:
        print(f"  📋  Building frame: {name}…")
        try:
            builder(board_id, col, row)
        except Exception as e:
            print(f"     ⚠️  Frame {name} partially failed: {e}")

    print("\n✅  Board ready!")
    print(f"    Board ID: {board_id}")
    print(f"    Open: https://miro.com/app/board/{board_id}/")
    print("\n📌  Share with consortium before the workshop and remind everyone to:")
    print("    1. Read the CLICKNL letter (Frame 0)")
    print("    2. Prepare their MKB input (Frame 2)")
    print("    3. Think about their WP use case (Frame 3)")


if __name__ == "__main__":
    main()
