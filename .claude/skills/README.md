# Agent skills

Open-source skills that the AI workers building Esplitealo use for SwiftUI and Apple design practice. Claude Code discovers each folder here automatically.

| Skill | Source | License | Use it for |
|---|---|---|---|
| `swiftui-expert-skill` | https://github.com/AvdLee/SwiftUI-Agent-Skill @ `204dba7c67256a8b707ee3fbc5759a824191974f` | MIT (`swiftui-expert-skill/LICENSE`) | Writing, reviewing and refactoring SwiftUI: state, view structure, layout, lists, navigation, performance, accessibility, localization |
| `apple-design-liquid-glass` | https://github.com/rshankras/claude-code-apple-skills @ `9ffb83138209057875698dd11c1720c657c47a92` | MIT (`LICENSE` in the folder) | Liquid Glass (iOS 26+) reference |
| `apple-design-typography` | same | MIT | Dynamic Type and type hierarchy |
| `apple-design-sf-symbols` | same | MIT | Choosing and configuring SF Symbols |
| `apple-design-ux-writing` | same | MIT | General UX writing principles |
| `apple-design-animation-patterns` | same | MIT | Transitions, symbol effects, keyframes, visual effects |
| `apple-design-ui-prototyping` | same | MIT | Quickly prototyping UI |

The SwiftUI skill's Instruments trace recording/analysis workflow (scripts and two references) was intentionally left out. The files are otherwise unmodified, apart from a note in `swiftui-expert-skill/SKILL.md` where those workflows were removed.

## Project rules that take precedence over any skill

1. The project docs decide visual design, wording and Spanish (Puerto Rico) copy: `docs/DESIGN_GUIDE.md`, `design/brand`, `docs/REQUIREMENTS.md`.
2. The UX-writing skill never overrides the wording rules: use the "tu" register, say "marcar", never "monto".
3. Liquid Glass: use standard system chrome (navigation bars, toolbars, sheets, tab bars). Do not hand-roll custom glass.
4. The app's minimum is iOS 18, so gate iOS 26+ APIs with `#available`.
5. Money is never set in the Unkempt font.
