# Design System Strategy: The Heritage Athletic Editorial

## 1. Overview & Creative North Star
This design system is built upon the "Creative North Star" of **The Curated Clubhouse**. We are moving away from the "generic tech app" look to embrace a high-end, boutique editorial aesthetic that blends the precision of modern athletics with the warmth of a heritage country club.

The core of this identity is driven by the provided hand-drawn fox sketch—a symbol of wit, agility, and craft. Our layout philosophy rejects rigid, boxy constraints in favor of **Organic Sophistication**. This means utilizing generous whitespace, intentional asymmetry in image placement, and a "paper-on-paper" layering effect. We treat the screen like a premium printed journal, where every element is placed with the intent of a master typographer.

## 2. Colors & Surface Philosophy
The palette is hyper-restrained to evoke a sense of "Quiet Luxury." 

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders for sectioning. Boundaries must be defined solely through background color shifts or tonal transitions. To separate a hero from a body section, move from `surface` (#faf9f5) to `surface-container-low` (#f4f4f0).

### Surface Hierarchy & Nesting
Treat the UI as a physical stack of fine stationery:
*   **Base Layer:** `surface` (#faf9f5) — The global canvas.
*   **Secondary Sections:** `surface-container-low` (#f4f4f0) — For content grouping.
*   **Floating Cards/Modals:** `surface-container-lowest` (#ffffff) — To create a crisp, "popping" lift against the cream background.
*   **Accents:** Use `primary_container` (#1e372b) sparingly for deep forest green moments that draw the eye to critical actions.

### Glass & Gradient Rule
While the brand is rooted in heritage, we use **Glassmorphism** to keep it modern. Floating navigation bars or action sheets should use a semi-transparent `surface_bright` with a 20px backdrop blur. 
*   **Signature Gradients:** For primary CTAs, use a subtle linear gradient from `primary` (#082217) to `primary_container` (#1e372b) at a 135-degree angle. This prevents buttons from looking "flat" and adds a tactile, premium depth.

## 3. Typography
We utilize **Plus Jakarta Sans** as our sole typeface. Its modern geometry paired with the heritage color palette creates a "New Traditionalist" vibe.

*   **Display (lg/md):** Use `3.5rem` and `2.75rem` for hero moments. These should have a slightly tighter letter-spacing (-0.02em) to feel like a high-end masthead.
*   **Headlines:** These are the "voice" of the brand. Use `headline-lg` (2rem) for section titles, always in `on_surface` (#1b1c1a) to maintain stark, sophisticated contrast.
*   **Body:** `body-lg` (1rem) is your workhorse. Ensure a line height of at least 1.5 to maintain the "editorial" breathability.
*   **Labels:** `label-md` (0.75rem) should be used for metadata and overlines, often in all-caps with increased letter-spacing (+0.05em) to mimic the look of a premium apparel tag.

## 4. Elevation & Depth
We eschew traditional drop shadows for **Tonal Layering**. 

*   **The Layering Principle:** Depth is achieved by "stacking." A `surface-container-lowest` card placed on a `surface-container-high` background provides all the visual separation needed.
*   **Ambient Shadows:** If a floating element (like a FAB) requires a shadow, it must be "Ambient."
    *   *Spec:* Blur: 40px, Spread: 0, Opacity: 6% of `primary` (#082217). This creates a soft, forest-floor glow rather than a harsh digital shadow.
*   **The Ghost Border:** If accessibility requires a stroke (e.g., input fields), use `outline_variant` (#c2c8c2) at **20% opacity**. It should be felt, not seen.

## 5. Components

### Buttons
*   **Primary:** High-roundness (`rounded-full`). Deep forest green (`primary`) background with `on_primary` (white) text.
*   **Secondary:** `surface_container_high` background. No border. Stark black text.
*   **Tertiary:** Text-only, using `title-sm` weight with a custom underlines that sit 4px below the baseline.

### Cards
*   **Style:** No borders. Use `rounded-lg` (2rem) for a friendly, organic feel. 
*   **Content:** Forbid divider lines. Use `spacing-6` (2rem) of vertical whitespace to separate header text from body text.

### Input Fields
*   **Style:** Use a `surface-container-low` background with a `rounded-md` (1.5rem) corner. 
*   **Focus State:** Shift background to `surface-container-lowest` and apply a 1pt "Ghost Border" of `primary` at 20% opacity.

### Selection Elements
*   **Chips:** High roundness (`rounded-full`). Unselected: `surface-container-high`. Selected: `primary` with `on_primary` text.
*   **Checkboxes/Radios:** Never use sharp corners. Even the "check" inside the box should have rounded terminals to match the "friendly community" vibe.

### Signature Component: The "Heritage Badge"
A floating circular element (using `rounded-full` and `spacing-12`) that houses the hand-drawn fox mascot or seasonal iconography, acting as a "seal of quality" over overlapping image/text sections.

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical margins. If the left margin is `spacing-8`, try a right margin of `spacing-12` for editorial layouts.
*   **Do** lean into the cream (`surface`) background. White (#ffffff) should be reserved only for the most elevated "top-tier" cards.
*   **Do** use the high-roundness scale (`xl`: 3rem) for image containers to mimic the soft edges of hand-drawn sketches.

### Don't
*   **Don't** use 1px black borders. It kills the boutique, premium feel immediately.
*   **Don't** use pure grey. Every "grey" in this system is slightly warmed or cooled by the forest green/cream base.
*   **Don't** crowd the fox. Any hand-drawn asset requires a "radius of silence" (at least `spacing-10` of whitespace) to maintain its status as a premium brand mark.