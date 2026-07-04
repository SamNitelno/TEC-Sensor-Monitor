# TEK Machine Downtime — Design System

## Pattern
**Instrument Console** — enterprise SCADA-inspired monitoring for large factories.

## Style
- Precision industrial UI, restrained motion, high information density
- Subtle instrument grid on chart backgrounds
- Live pulse indicator on real-time panels

## Colors (Dark — default)
| Token | Hex |
|-------|-----|
| background | `#0A0E14` |
| surface | `#121820` |
| surfaceElevated | `#1A2230` |
| border | `#2A3544` |
| primary | `#00C9A7` |
| secondary | `#E8A838` |
| error | `#F85149` |
| success | `#3FB950` |
| textPrimary | `#E8EDF4` |
| textMuted | `#7D8B9E` |

## Colors (Light)
| Token | Hex |
|-------|-----|
| background | `#F0F3F7` |
| surface | `#FFFFFF` |
| surfaceElevated | `#E8ECF2` |
| border | `#D0D7E2` |
| primary | `#008F7A` |
| textPrimary | `#1A2332` |
| textMuted | `#5C6B7E` |

## Typography
- **Display / headings:** Manrope (600–700)
- **Body / UI:** Source Sans 3 (400–600)
- **Data / axes:** Source Sans 3 tabular nums

## Shape
- Cards: 12px · Inputs: 10px · Chips: 8px · Buttons: 10px

## Motion
- Micro-interactions: 150–200ms ease-out
- Chart series: 600–800ms
- Respect `prefers-reduced-motion` + user setting

## Anti-patterns
- No emoji icons · No layout-shifting hover scale · No invisible borders in light mode
