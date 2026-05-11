# UX research

This folder holds the design research that fed the app's visual, animation, and motion decisions. Each markdown file is a self-contained reference written *before* the corresponding code shipped — the goal was to commit to a vocabulary (timings, easings, depth techniques, image treatments) before any of it became a moving target in the implementation.

The work happens at two layers:

- **Top-level files** are the engineering-facing briefs. Each one synthesizes a specific design surface — motion, hospitality patterns, image treatment, editorial typography — into concrete SwiftUI iOS 17+ recipes with rationale. They're the documents I'd hand a teammate joining the project who'd ask "why does the morph feel like *that*?"
- **`team/`** holds the deeper-dive research that informed those briefs — extracted patterns from specific apps, integration plans for multi-track work, and audit logs from continuous design review. More raw, more granular; the top-level files distill it.

## What's in each file

### Top-level briefs

| File | What it covers |
|---|---|
| `01-swiftui-animation-primitives.md` | API-level guidance for `withAnimation`, `PhaseAnimator`, `KeyframeAnimator`, `matchedGeometryEffect`, etc. — with production-grade defaults and the API decisions behind ADR-007 (value-bound animation over `PhaseAnimator`). |
| `02-apple-hig-motion.md` | Apple HIG motion vocabulary translated into opinionated rules for hotel-card and search-row UX. The "feels native, not novel" reference. |
| `03-airbnb-hilton-patterns.md` | Field guide to specific transitions, timings, and component behaviors from premium hospitality apps on iOS — with SwiftUI implementation notes. Feeds the morph + drag-throw work. |
| `04-microinteractions.md` | The vocabulary of perceived-quality micro-interactions: tap acknowledgements, gesture rewards, state-transition motion + haptics. Drives Theme.Animation tokens + the chip pulse + the haptic schedule. |
| `05-image-gallery-gradients.md` | Hero gallery, gradient overlays, text legibility on photo substrates — the substrate work for the hotel card's image surface. Feeds the EditorialGradeProcessor + the parallax hero recipes. |
| `06-editorial-luxury-design.md` | Visual vocabulary from Mr & Mrs Smith, Aman, One Hotels, Soho House, Edition — typography, air, flatness limits. The reference for "expensive without a custom font." |

### `team/` subfolder

The deeper-dive research that fed the briefs above. Highlights:

- `00-build-brief.md` / `01-integration-plan.md` — the multi-worker build plan that scoped the transition-shell work.
- `01-60fps-card-patterns.md` / `02-mobbin-hospitality-patterns.md` / `03-awwwards-dribbble-concepts.md` — pattern surveys from 60fps.design, Mobbin, Awwwards, Dribbble.
- `04-premium-hospitality-deep-dive.md` — field study of ten shipping apps with concrete extraction targets.
- `05-depth-techniques.md` — the layered-effect approach behind the card depth ("depth is never one effect").
- `07-pull-to-refresh-hero-patterns.md` — the parallax-hero + pull-down behavior survey behind the detail-screen sticky header.
- `09-auxiliary.md` — secondary patterns referenced inline by the top-level briefs.
- `audit-log.md` / `12-continuous-audit.json` — the running design-review log against the implementation.

## What this folder is *not*

It isn't engineering documentation — that lives in [`ARCHITECTURE.md`](../ARCHITECTURE.md) and the [ADRs](../docs/ADRs.md). It isn't user research either — there were no user interviews on a take-home. It's **design research**: synthesized observations of how premium apps in this category solve the problems we're solving, translated into recipes the engineering work could pick from.

The briefs aren't meant to be exhaustively read end-to-end. They're meant to be searchable — when an animation question came up during the build (*"how long should this morph take?"*, *"should the spring be critically damped?"*, *"what gradient stops keep this legible?"*), the answer was already written down here with citations to the apps that established the convention.

## Goal

Decouple two things that often get conflated on a small project: **deciding** what a surface should feel like, and **building** it. By the time the code started, the decisions were already made and recorded. The implementation phase was about hitting the documented targets — not about discovering what the targets should be.
