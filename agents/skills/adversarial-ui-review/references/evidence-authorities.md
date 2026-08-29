# Evidence Authorities & Thresholds

Every finding MUST cite one of these. No citation → not a finding.

## Authorities

| Authority | Cite as | Governs |
|---|---|---|
| Nielsen Norman Group — 10 Usability Heuristics | `Nielsen H1` … `H10` | Status, match, control, consistency, error prevention, recognition, flexibility, minimalism, error recovery, help |
| WCAG 2.2 AA | `WCAG SC x.y.z` | Contrast, keyboard, focus, labels, targets, structure |
| Laws of UX (Yablonski et al.) | Law name | Cognition / motor / timing |
| Apple Human Interface Guidelines | `HIG: <topic>` | iOS / macOS layout, touch, Dynamic Type, focus |
| Material Design 3 | `Material: <topic>` | Android components, motion, touch, color roles |
| Deceptive patterns (Brignull) / DSA Art. 25 | Pattern name | Coercion, confirmshaming, forced continuity |

## Nielsen quick map

| # | Name | Typical UI failure |
|---|---|---|
| H1 | Visibility of system status | No loading / silent failure |
| H2 | Match system & real world | Jargon, non-native controls |
| H3 | User control & freedom | No Esc/back/undo; modal trap |
| H4 | Consistency & standards | Novel patterns vs OS/browser |
| H5 | Error prevention | Destructive with no confirm |
| H6 | Recognition rather than recall | Hidden gestures only |
| H7 | Flexibility & efficiency | Power users blocked (no shortcuts) |
| H8 | Aesthetic & minimalist design | Competing CTAs, chrome noise |
| H9 | Help users recover | Errors colour-only / no next step |
| H10 | Help & documentation | First-run dead ends |

## Hard thresholds

| Check | Threshold | Cite |
|---|---|---|
| Text contrast | ≥ 4.5:1 (large ≥ 3:1) | WCAG SC 1.4.3 |
| Non-text UI contrast | ≥ 3:1 | WCAG SC 1.4.11 |
| Touch target (a11y floor) | ≥ 24×24 CSS px | WCAG SC 2.5.8 |
| Touch target (comfort / HIG) | ≥ 44×44 pt (iOS) / 48×48 dp (Android) | HIG / Material |
| Visible keyboard focus | Always present | WCAG SC 2.4.7 |
| Keyboard operable | All actions | WCAG SC 2.1.1 |
| UI response feel | ≤ ~400 ms before feedback | Doherty Threshold |
| Working memory in menus | ~7±2 peer choices | Miller's Law |
| Primary CTA reach | Prefer ≤ 3 decisive steps | Krug / Hick |

## Adversarial probes (always try)

1. Empty / zero-data state
2. Error / timeout / permission denied
3. Extremely long strings / RTL / large Dynamic Type / font scale
4. Keyboard-only (and TalkBack / VoiceOver if mobile evidence available)
5. Rapid repeat activation (double-submit, double-shortcut)
6. Overflow: horizontal scroll, clipped CTAs, below-fold without affordance
7. Focus order vs visual order; focus restore on dismiss
