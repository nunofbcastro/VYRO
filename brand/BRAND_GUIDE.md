# VYRO — brand guide (concept)

## Positioning
VYRO is the calm, confident home for better nutrition and stronger training. Smart without noisy AI hype; sporty without aggressive bodybuilding clichés.

## Voice
Short, clear, motivating. Portuguese (Portugal): "O teu dia", "Adicionar refeição", "Começar treino", "Registar série", "O teu progresso". No shaming, exaggerated health promises or false precision.

## Design direction
**Premium minimal + performance technology.** Near-black canvases, charcoal surfaces, one lime accent, off-white type. Spacious compositional grid, 16–24 px cards, thin strokes, understated charts. No neon gradients or excessive shadows. Accent is a signal, not a wallpaper.

## Palette
- Ink / primary background: `#0B0D10`
- Surface: `#171A20`
- Elevated surface: `#20242B`
- Primary accent: `#B8F36B`
- Main text: `#F5F7F8`
- Secondary text: `#9299A4`
- Border: `#2A2E35`
- Positive: `#71DB9B`; error: `#F08080`
- Light mode: background `#F8FAF7`, text `#171A20`, card `#FFFFFF`, accent `#4A741A` (darker for text contrast).

## Typography
Inter (or system sans fallback), tight bold headlines, clear tabular numbers, readable body. Do not package fonts in repo without checking licensing and distribution requirements.

## Layout system
8 px spacing grid, 16/20/24 px radii, 44–48 px minimum tap targets, 4–5 navigation tabs, strong numerical hierarchy, no more than one primary CTA per section.

## Logo
The logo is the V Y R O lettering with a separate accent cap on the V (SVG in `logos/`, geometry and files in `logos/README.md`). It is an initial vector concept, not a registered trademark. Keep clear space equivalent to the width of the V's inner notch.
- Dark backgrounds: white body, logo cap `#A3E635`. Light backgrounds: ink body `#18191C`, logo cap `#4D7C0F`.
- The logo cap is a logo colour, separate from the UI accent: UI lime `#B8F36B` is unchanged, and small lime text is not placed on white.
- The V monogram alone is the app icon: V at 60% of the canvas on `#0B0D10`.

## Accessibility
Use semantic labels, support font scaling, ensure appropriate contrast, supply non-colour feedback and dark/light variants.
