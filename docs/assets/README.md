# Brand assets

> [!IMPORTANT]
> **[TBD: real ACT brand assets pending.]** Everything in this directory is a placeholder created
> to fill the README header. None of it has been reviewed or approved by anyone who owns ACT Data's
> visual identity. Replace it before this catalog is shown outside the team.

| File | What it is |
|---|---|
| [`act-wordmark.svg`](act-wordmark.svg) | Placeholder wordmark for light backgrounds |
| [`act-wordmark-white.svg`](act-wordmark-white.svg) | Placeholder wordmark for dark backgrounds |

## What is a placeholder and what is not

**Placeholder:** the mark itself. The letterform glyph, the lockup, the tagline
"AGENT PLUGIN CATALOG", and the proportions are invented. No ACT Data logo, wordmark, or brand
guide exists anywhere in this workspace to derive them from.

**Not invented — inherited:** the palette. ACT Data is a Patterson Companies business unit, so the
placeholder uses the Patterson 2025 Brand Guide colors rather than making up new ones:

| Token | Hex | Use here |
|---|---|---|
| Navy | `#003767` | Wordmark text, mark background |
| Cyan | `#00A8E1` | Accent stroke, primary badge color |
| Blue | `#147EC2` | Secondary badge color |
| Teal | `#00817D` | Tertiary badge color |
| Gray | `#58585B` | Tagline, muted badge color |

> [!NOTE]
> **[TBD: whether ACT Data has, or should have, a palette distinct from Patterson corporate.]**
> Inheriting the parent palette is the defensible default in the absence of a stated ACT palette,
> not a decision anyone has made.

## Constraints on replacements

Whatever replaces these must satisfy the repository gate (`sh scripts/verify-all.sh`):

- **SVG is preferred and exempt from the size limit.** Raster images are capped at 50 KiB by
  `scripts/check-no-binaries.ts`.
- **No font binaries.** Proxima Nova is licensed through Adobe Fonts and must never be committed
  here. The SVGs name it in `font-family` and fall back to Helvetica Neue and Arial, so they
  render correctly without it.
- **No PDFs, Office documents, or archives.** Brand guides live in their system of record, not in
  this repository.
