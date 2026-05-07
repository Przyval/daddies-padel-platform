# Design System — Daddies Padel Platform

## Creative North Star: The Curated Clubhouse
A high-end, boutique editorial aesthetic that blends the precision of modern athletics with the warmth of a heritage country club. We treat the screen like a premium printed journal — every element placed with the intent of a master typographer.

The fox mascot (hand-drawn, line art) is the brand seal — a symbol of wit, agility, and craft.

## Product Context
- **What this is:** Community platform for Daddies Padel Club — sessions, scoring, finance, member management
- **Who it's for:** Padel enthusiasts in Jakarta, Indonesia — a close-knit club community
- **Space/industry:** Sports community / social padel
- **Project type:** Mobile-first web app (Flutter)
- **Tone:** "Come Play with Daddies" — playful yet premium, like a private members' club

## Aesthetic Direction
- **Direction:** Heritage Athletic Editorial — "New Traditionalist"
- **Decoration level:** Intentional — tonal layering, glassmorphism on floating elements, no gratuitous decoration
- **Mood:** Walking into a boutique padel club with leather chairs, matcha on the counter, and a hand-drawn fox crest on the wall. Premium but not pretentious. Warm but precise.
- **Reference:** @padeldaddies Instagram — B&W editorial photography, hand-drawn fox mascot, forest greens

## The "No-Line" Rule
**Explicit rule:** No 1px solid borders for sectioning. Boundaries are defined solely through background color shifts or tonal transitions. To separate sections, shift from `surface` to `surfaceContainerLow`. The only permitted stroke is the "Ghost Border" — `outlineVariant` at 20% opacity — for accessibility-critical elements like input fields.

## Color System

### Surface Hierarchy (The Paper Stack)
Think of the UI as fine stationery stacked on a desk:

| Token | Hex | Role |
|-------|-----|------|
| `surface` | `#FAF9F5` | Global canvas — the cream paper |
| `surfaceBright` | `#FAF9F5` | Glass elements (with backdrop blur) |
| `surfaceContainerLow` | `#F4F4F0` | Content grouping, secondary sections |
| `surfaceContainer` | `#EFEEE A` | Mid-level containers |
| `surfaceContainerHigh` | `#E9E8E4` | Unselected chips, secondary buttons |
| `surfaceContainerHighest` | `#E3E2DF` | Highest nesting level |
| `surfaceContainerLowest` | `#FFFFFF` | Floating cards, modals — crisp lift |
| `surfaceDim` | `#DBDAD6` | Dimmed/disabled surfaces |
| `surfaceVariant` | `#E3E2DF` | Variant surface |

### Primary (Forest Green)
| Token | Hex | Role |
|-------|-----|------|
| `primary` | `#082217` | Deepest forest — primary buttons, selected states, app bar |
| `primaryContainer` | `#1E372B` | Slightly lighter — selected time slots, heritage badge |
| `onPrimary` | `#FFFFFF` | Text/icons on primary |
| `onPrimaryContainer` | `#85A091` | Subdued text on primary container |
| `primaryFixed` | `#CCE9D8` | Light green tint |
| `primaryFixedDim` | `#B1CDBC` | Dimmed fixed variant |

### Secondary (Neutral Gray)
| Token | Hex | Role |
|-------|-----|------|
| `secondary` | `#5E5E5E` | Secondary actions |
| `secondaryContainer` | `#E2E2E2` | Booked/disabled badges |
| `onSecondary` | `#FFFFFF` | Text on secondary |
| `onSecondaryContainer` | `#646464` | Text on secondary container |

### Tertiary (Moss Green)
| Token | Hex | Role |
|-------|-----|------|
| `tertiary` | `#032217` | Deep tertiary |
| `tertiaryContainer` | `#1A372C` | Tertiary container |
| `onTertiary` | `#FFFFFF` | Text on tertiary |
| `onTertiaryContainer` | `#81A192` | Subdued tertiary text |

### Semantic
| Token | Hex | Role |
|-------|-----|------|
| `error` | `#BA1A1A` | Errors, destructive actions |
| `errorContainer` | `#FFDAD6` | Error backgrounds |
| `onError` | `#FFFFFF` | Text on error |
| `onErrorContainer` | `#93000A` | Text on error container |
| `success` | `#4A7C59` | Success states |
| `warning` | `#D4A843` | Warnings, waitlist |
| `info` | `#3D6B8E` | Informational |

### Text & Content
| Token | Hex | Role |
|-------|-----|------|
| `onSurface` | `#1B1C1A` | Primary text — stark, sophisticated |
| `onSurfaceVariant` | `#424844` | Secondary text, metadata, labels |
| `onBackground` | `#1B1C1A` | Body text on background |
| `outline` | `#727974` | Visible outlines (rare) |
| `outlineVariant` | `#C2C8C2` | Ghost borders (at 20% opacity) |
| `inverseSurface` | `#2F312E` | Dark surfaces |
| `inverseOnSurface` | `#F2F1ED` | Text on dark surfaces |
| `inversePrimary` | `#B1CDBC` | Primary on dark surfaces |
| `surfaceTint` | `#4A6456` | Tint overlay |

### Dark Mode Strategy
Invert the paper stack. The "paper" becomes dark parchment:
- Background: `#1B1C1A`
- Surface: `#252624`
- Surface Container Low: `#2F312E`
- Primary stays `#082217`, but buttons use `inversePrimary` (`#B1CDBC`) on dark
- Reduce saturation 10-20% on accent colors
- All greens remain warm-toned, never cool/neon

## Typography
**Font:** Plus Jakarta Sans — sole typeface. Its modern geometry + heritage palette = "New Traditionalist."

| Level | Size | Weight | Letter Spacing | Usage |
|-------|------|--------|----------------|-------|
| Display LG | 3.5rem (56px) | 800 | -0.02em | Hero moments, splash |
| Display MD | 2.75rem (44px) | 800 | -0.02em | Large hero text |
| Headline LG | 2rem (32px) | 700 | -0.01em | Section titles |
| Headline MD | 1.75rem (28px) | 700 | -0.01em | Screen titles |
| Title LG | 1.375rem (22px) | 700 | -0.01em | Card headers, "Book a Court" |
| Title MD | 1rem (16px) | 700 | 0 | Subsection titles |
| Title SM | 0.875rem (14px) | 600 | 0 | Tertiary button text |
| Body LG | 1rem (16px) | 400 | 0 | Primary body text (line-height: 1.5) |
| Body MD | 0.875rem (14px) | 400 | 0 | Secondary body text |
| Body SM | 0.75rem (12px) | 400 | 0 | Captions |
| Label LG | 0.875rem (14px) | 700 | +0.02em | Button labels |
| Label MD | 0.75rem (12px) | 700 | +0.05em, UPPERCASE | Metadata, overlines, tags ("SELECTED VENUE") |
| Label SM | 0.65rem (10.4px) | 700 | +0.08em, UPPERCASE | Day abbreviations, nav labels, badge text |

**Loading:** Google Fonts CDN: `https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap`

**Flutter:** Add `google_fonts` package or bundle Plus Jakarta Sans in `assets/fonts/`.

## Spacing
- **Base unit:** 4px
- **Density:** Comfortable — generous whitespace is core to the editorial feel
- **Scale:**

| Token | Value | Usage |
|-------|-------|-------|
| `2xs` | 2px | Micro gaps |
| `xs` | 4px | Icon-to-text gaps |
| `sm` | 8px | Tight padding |
| `md` | 16px | Standard padding |
| `lg` | 24px | Section gaps |
| `xl` | 32px | Major section separation |
| `2xl` | 48px | Hero spacing |
| `3xl` | 64px | Page-level breathing room |

**The "Radius of Silence" Rule:** The fox mascot/heritage badge requires at least `xl` (32px) of whitespace around it. It's a premium brand mark — don't crowd it.

## Layout
- **Approach:** Organic Sophistication — editorial-influenced, not rigid boxy grids
- **Max content width:** 448px (mobile-first, `max-w-md`)
- **Padding:** 24px horizontal (`px-6`)
- **Section spacing:** 32px vertical (`space-y-8`)

### Border Radius (Hierarchical)
| Token | Value | Usage |
|-------|-------|-------|
| `sm` | 8px | Small chips, input fields inner |
| `md` | 16px (1rem) | Default — cards, input fields, time slots |
| `lg` | 32px (2rem) | Large cards, image containers |
| `xl` | 48px (3rem) | Bottom nav, feature sections |
| `full` | 9999px | Buttons (primary), badges, heritage badge, nav pills |

### Asymmetric Margins (Editorial Touch)
For editorial layouts, use intentional asymmetry: if left margin is `lg`, right margin can be `xl`. This mimics premium print layouts.

## Elevation & Depth

### Tonal Layering (Primary Method)
Depth through stacking, not shadows. A `surfaceContainerLowest` card on a `surfaceContainerHigh` background = visual separation without any shadow.

### Ambient Shadows (Floating Elements Only)
For FABs, floating bars, and modals:
- Blur: 40px
- Spread: 0
- Opacity: 6% of `primary` (#082217)
- Creates a soft "forest-floor glow" — never harsh digital shadows

### Glassmorphism (Modern Heritage)
Floating navigation bars and action sheets:
- Background: `surfaceBright` at 80% opacity
- Backdrop blur: 20px
- Ghost border: `outlineVariant` at 20% opacity
- Shadow: `0 -4px 40px rgba(8,34,23,0.06)` for bottom nav

### Signature Gradients
Primary CTAs: subtle linear gradient from `primary` (#082217) to `primaryContainer` (#1E372B) at 135 degrees. Prevents flat-button syndrome.

## Motion
- **Approach:** Intentional — motion aids comprehension and adds polish
- **Easing:** enter(ease-out) exit(ease-in) move(ease-in-out)
- **Duration:** micro(50-100ms) short(150-250ms) medium(250-400ms) long(400-700ms)
- **Active press:** `scale(0.95)` on tap for tactile feedback
- **Transitions:** `transition-all duration-300 ease-out` for hover/state changes

## Components

### Buttons
- **Primary:** `rounded-full`, `primary` background → `onPrimary` text. Padding: `px-8 py-4`. Shadow on hover. `active:scale-95` on press.
- **Secondary:** `surfaceContainerHigh` background, no border, stark black text. `rounded-full`.
- **Tertiary:** Text-only, `titleSm` weight, custom underline 4px below baseline.
- **Ghost:** Transparent background, `outlineVariant` border at 20% opacity.

### Cards
- **No borders.** Use `rounded-lg` (2rem).
- **Available state:** `surfaceContainerLowest` (#FFF) background, subtle `shadow-sm`.
- **Disabled/booked state:** `surfaceContainerLow` background, 80% opacity.
- **Content separation:** Use `lg` (24px) whitespace between sections — never divider lines.
- **Press feedback:** `active:scale-[0.98]` for tactile response.

### Input Fields
- **Default:** `surfaceContainerLow` background, `rounded-md` (1.5rem).
- **Focus:** Shift to `surfaceContainerLowest`, apply Ghost Border (`primary` at 20% opacity, 1pt).
- **No floating labels** — use overline labels (`labelMd`, uppercase, `onSurfaceVariant`).

### Selection Elements
- **Date chips:** `rounded-xl`, unselected: `surfaceContainerLow` + `onSurfaceVariant` text. Selected: `primary` bg + `onPrimary` text + `ring-4 ring-primaryContainer/10` glow.
- **Time slots:** `rounded-lg`, same pattern. Selected: `primaryContainer` bg + `onPrimary` text + 2px `primary` border.
- **Radio buttons:** `rounded-full`, 2px `primary` border, inner filled circle when selected.
- **Chips/tags:** `rounded-full`. Unselected: `surfaceContainerHigh`. Selected: `primary` + `onPrimary`.
- **Status badges:** `rounded-full`, `labelSm` uppercase, `primary/10` bg + `primary` text for "Available", `secondaryContainer` bg for "Booked".

### Bottom Navigation
- Glass effect: `surfaceBright/80` + `backdrop-blur-xl`
- `rounded-t-[3rem]` top corners
- Ghost border top: `outlineVariant/20`
- Ambient shadow: `0 -4px 40px rgba(8,34,23,0.06)`
- Active item: `primaryContainer` pill bg + `surface` text + filled icon
- Inactive: `primary/50` text + outlined icon
- Labels: `labelSm` uppercase, tracking widest

### Heritage Badge
A floating circular element (`rounded-full`, 56px) with `primaryContainer` background, housing the fox mascot or contextual icon. Acts as a "seal of quality." Requires `xl` whitespace radius.

### Floating Action Bar (Summary/CTA)
- Position: fixed bottom, above nav
- Glass: `surfaceBright/80` + `backdrop-blur-xl`
- `rounded-xl` container
- Ghost border: `outlineVariant/20`
- Contains metadata (labelMd overline) + price (headline) + primary CTA button

## Do's and Don'ts

### Do
- Use the cream (`surface` #FAF9F5) as the default background — white is only for the most elevated cards
- Use asymmetric margins for editorial flair
- Use `rounded-xl` (3rem) for image containers — mimics soft edges of hand-drawn sketches
- Use uppercase + wide letter-spacing for metadata labels — mimics premium apparel tags
- Warm every "gray" — no pure grays, everything is slightly forest-green or cream-tinted

### Don't
- Don't use 1px black borders — kills the boutique feel immediately
- Don't use pure gray — every neutral is warmed by the forest green/cream base
- Don't crowd the fox — `xl` whitespace minimum around the mascot
- Don't use harsh drop shadows — only ambient shadows with 6% opacity
- Don't use divider lines inside cards — use whitespace
- Don't use gradient backgrounds for entire sections — gradients are reserved for primary CTAs only

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-23 | Initial design system created | Based on "Heritage Athletic Editorial" stitch mockup + Padel Daddies Instagram brand identity |
| 2026-03-23 | Plus Jakarta Sans as sole typeface | Modern geometry + heritage palette = "New Traditionalist" — avoids overused Inter/Poppins |
| 2026-03-23 | No-line rule adopted | Premium boutique feel — tonal layering instead of borders |
| 2026-03-23 | Glassmorphism for floating elements | Bridges heritage aesthetic with modern UI expectations |
