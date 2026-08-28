# Skill: Cypher UI Design

Design-system discipline for Agent Cypher's Flutter UI. Apply whenever creating or modifying widgets, screens, or themes.

## Core rules

1. **Consistent design tokens.** All colors, spacing, radii, durations, and type styles come from `lib/core/theme/` tokens. Never invent local values.
2. **No arbitrary colors.** A `Color(0x...)` literal in a screen or widget is a defect. Add a token instead.
3. **No arbitrary padding scattered across screens.** Use `CypherSpacing` semantic names (`componentGap`, `groupGap`, `pagePadding`…), not raw doubles.
4. **Reusable components.** Shared visuals live in `lib/core/ui/` (CypherButton, CypherCard, CypherGlass, CypherSheet…). Two screens needing the same look must share one component.
5. **Responsive layouts.** Use `MediaQuery`/`LayoutBuilder` and `CypherSpacing.bp*` breakpoints. Never fix a widget to one emulator's dimensions; support large font scales.
6. **Correct touch target sizes.** Minimum 44×44 logical px for every interactive element; bottom-anchored primary actions within thumb reach.
7. **Clear visual hierarchy.** One primary action per view; size/weight/color communicate importance before position does.
8. **Progressive disclosure.** Secondary/rare actions collapse into menus, sheets, or expandable sections. Never surface a wall of buttons.
9. **Accessible contrast.** Body text ≥ 4.5:1, large text ≥ 3:1 against its actual surface. Verify in both dark and light presets.
10. **Reduced-motion support.** Respect `MediaQuery.disableAnimations`/`accessibleNavigation`; make decorative motion skippable.
11. **Efficient Flutter rendering.** `const` constructors, `ListView.builder` for long lists, rebuild only what changed, keep expensive work out of `build`.
12. **Minimal unnecessary blur.** `BackdropFilter` is allowed on small surfaces (composer, sheets, floating controls) — never full-screen behind scrolling text. The UI must look correct with blur disabled.
13. **Minimal unnecessary animation.** Motion communicates state (composer expansion, message arrival, sheet transitions); nothing bounces for decoration.
14. **No giant collections of buttons.** Group by task frequency; demote the rare, promote the frequent.
15. **No vibe-coded inconsistency.** Same role ⇒ same token ⇒ same visual everywhere. Grep for old hardcoded colors before finishing a screen.
16. **Preserve existing functionality.** Trace every callback/service/flag a screen touches before restyling it. Reorganizing access is allowed; silent removal is not.
17. **Test UI changes on appropriate screen sizes.** Small phone, large phone, tablet width, landscape, keyboard open, largest accessibility font scale.
18. **Prefer theme-level changes over widget hacks.** If several widgets need the same fix, fix `CypherThemeData.toMaterialTheme()` or the component — not each call site.

## Visual philosophy

Dark charcoal foundation + faded ambient accent + subtle glass + warm off-white typography + restrained accent color + generous spacing + progressive disclosure. Content first, function second, material third, decoration last. Quiet, premium, intentional — never neon, never gamer, never template.

## Token access

```dart
final c = context.cypher;          // CypherThemeData
c.colors.background;               // semantic colors
c.spacing.componentGap;            // semantic spacing
c.typography.bodyMedium;           // semantic type
c.defaultGlassSpec;                // glass material spec
```

`CypherTheme.of(context)` falls back to the Crimson Night preset when no inherited theme exists (e.g. overlay isolate), so tokens are always safe to read.