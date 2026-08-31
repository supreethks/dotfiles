---
name: visual-designer
description: High-craft visual design and mobile/desktop UI/UX systems powered by Impeccable engine and craft standards. Use when designing web and mobile interfaces, eliminating AI design tells, using Impeccable commands (/polish, /distill, /clarify, /typeset, /colorize, /harden), selecting icon systems (Phosphor, Lucide, Material Symbols, SF Symbols), defining tokenized design systems, or building designs in Pencil (pen.dev), Figma, and React/Compose.
---

# Visual Designer (Impeccable Edition)

This skill integrates the **Impeccable Design Engine (`v4.1.1`)** with cross-platform UI/UX architecture, tokenized design systems, **Pencil (`pen.dev`)** workflows, and mobile/desktop icon frameworks.

---

## 1. Impeccable Core Engine Integration

Whenever designing, reviewing, or modifying interfaces, activate and follow Impeccable's craft standards and command playbooks:

### Primary Commands
- **`/impeccable polish [target]`**: Refine spacing, typography, alignment, and tactile feedback without altering scope or functionality.
- **`/impeccable distill [target]`**: Eliminate unnecessary cards, status-chip clutter, and visual noise to establish clear visual hierarchy.
- **`/impeccable clarify [target]`**: Simplify forms, workflows, and onboarding paths so primary actions are obvious.
- **`/impeccable typeset [target]`**: Establish rhythmic type scales, proportional line heights, and deliberate tracking.
- **`/impeccable colorize [target]`**: Balance contrast ratios, semantic tokens, and theme variations (e.g. OLED pure black vs. tinted surfaces).
- **`/impeccable harden [target]`**: Prepare for production by hardening error states, empty states, truncation, and accessibility (WCAG AAA).

---

## 2. Pencil (`pen.dev`) Design Environment

- **Primary Tooling**: **Pencil / pen.dev** (`@pen.dev/cli`) using `.pen` schema.
- **CLI Execution**: `pen --out design.pen --prompt "..." --export design.png --export-scale 2`
- **MCP Server Tools**: `get_app_state`, `execute`, `get_style`, `browser`, `read_skill`.
- **Canvas Principles**: Design in nested frames, tokenized variables, reusable components (`type: "ref"`), and auto-layout containers.

---

## 3. Impeccable Craft Floor & Rules

### Must Verify:
1. **Contrast Ratio**: Body and placeholder text must satisfy ≥4.5:1, large text ≥3:1 against OLED surfaces. Tint secondary text with the foreground or background hue—never generic washed-out gray.
2. **Layered Depth**: Build true layered surfaces (`canvas` → `base` → `elevated` → `active/focus`) with subtle 1px border delineation (`#212836`). Avoid zero-blur colored halos.
3. **Typography**: Establish distinct hierarchy (Display → Title → Body → Caption → Data/Badge). No arbitrary gradient text; emphasis comes from scale, tracking, and weight.
4. **Touch & Click Ergonomics**: Desktop click targets ≥32px; mobile touch targets ≥44×44px with comfortable thumb-zone accessibility.

### Absolute Refusals (AI Tells):
- 🚫 **No emoji substitutes for icons**: Icons must be drawn from a cohesive vector library (such as Phosphor Icons) with uniform optical weight and stroke width.
- 🚫 **No nested cards or cookie-cutter templates**: Avoid repetitive icon-plus-heading-plus-text cards.
- 🚫 **No arbitrary glassmorphism/blurs**: Use frosted backdrops only for true modal scrims and sticky floating bars.
- 🚫 **No generic placeholder copy**: Use authentic product context, real metrics, and precise action labels.

---

## 4. Top Online Icon Sets for Mobile & Desktop Apps

* **Phosphor Icons (Recommended)**
  * *Style:* Highly flexible system with 6 distinct weights/styles (Thin, Light, Regular, Bold, Fill, Duotone).
  * *Formats:* SVG, React, Flutter, React Native, Figma library, Iconify (`ph:` prefix).
  * *Best For:* Cross-platform apps (Desktop + Mobile) requiring seamless active/inactive state toggles (e.g., outlined unselected tab vs. bold/fill selected tab).
  * *License:* MIT.

* **Lucide Icons**
  * *Style:* Clean, modern, lightweight outline icons (community-driven fork of Feather Icons).
  * *Formats:* SVG, React Native, Flutter, Compose-friendly vector data, Web Components.
  * *Best For:* Utilitarian utility navigation, minimal dashboards, settings screens.
  * *License:* ISC (Free for commercial use).

* **Google Material Symbols & Icons**
  * *Style:* Native Android standard, available in Outlined, Rounded, and Sharp variants with variable font weight axes.
  * *Formats:* Jetpack Compose Material Icons, Vector Drawables, Flutter (`Icons`), SVG.
  * *Best For:* Native Android look-and-feel, highly recognizable UI patterns.
  * *License:* Apache 2.0.

* **Apple SF Symbols**
  * *Style:* Native iOS standard with multi-weight, multicolor, and hierarchical rendering.
  * *Formats:* Native iOS/macOS integration (`systemImage:` in SwiftUI/UIKit).
  * *Best For:* Pure iOS/macOS native applications needing system alignment.
  * *License:* Proprietary (Free for Apple platform development only).

* **Tabler Icons**
  * *Style:* Over 5,000 consistent, pixel-aligned vector stroke icons.
  * *Formats:* SVG, Flutter, React Native, Figma.
  * *Best For:* Feature-dense applications needing comprehensive category coverage.
  * *License:* MIT.

* **Heroicons**
  * *Style:* Polished, modern UI icons designed by the Tailwind CSS team (Outline, Solid, Micro, Mini).
  * *Formats:* SVG, React Native wrappers, Figma.
  * *Best For:* High-polish onboarding flows, cards, and clean modern mobile layouts.
  * *License:* MIT.

---

## 5. Quick Icon Comparison Matrix

| Icon Set | Best Ecosystem | Key Styles | Total Icons |
| :--- | :--- | :--- | :--- |
| **Phosphor** | Android / iOS / Desktop / Web | 6 Weights (Thin, Light, Regular, Bold, Fill, Duotone) | ~1,200+ (×6 styles) |
| **Lucide** | Cross-Platform / Minimal | Stroke | ~1,500+ |
| **Material Symbols** | Android / Jetpack Compose | Outlined, Rounded, Sharp | ~3,000+ |
| **SF Symbols** | Native Apple (SwiftUI/UIKit) | Multiple weights / Multicolor | ~5,000+ |
| **Tabler** | Cross-Platform / Dense UIs | Outline & Filled | ~5,000+ |
| **Heroicons** | Modern Mobile & Web | Outline, Solid, Mini | ~300+ |


## Mandatory Rule: Immediate Auto-Save & Disk Persistence
- **Always Save on Disk**: Whenever creating, updating, or generating any design or code files (.pen, .tsx, .json, etc.), you MUST immediately write and flush the changes completely to disk.
- **Buffer & App Synchronization**: In desktop editors like Pen.app / Pencil, external file modifications are only loaded if the file on disk is flushed and reloaded. Never leave files in an unsaved or partial memory state.
- **Integrity Validation**: Always validate that the JSON structure of every .pen file is valid and complete with os.sync() / verified file read after every edit step.
