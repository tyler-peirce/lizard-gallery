# Breeding Groups on the For-Sale Page — Design

**Date:** 2026-05-30
**Status:** Approved design, ready for implementation plan

## Goal

Display breeding groups on the lizard for-sale gallery. A breeding group is a fixed
bundle of animals (typically 1 male + 3 females) sold together for a single group
price. Each group has a description explaining what is included. Group data is sourced
from the spreadsheet.

## Source data

The spreadsheet `Catalogue-of-Lizards_Tyler-Peirce.xlsx` (sheet `Sheet1`) has these
relevant columns:

- col 3 `Animal_code` — animal id
- col 4 `Breeding group price` — group price (same for every animal in the group)
- col 5 `Breeding group` — group id (e.g. `Q1`–`Q5`)
- col 17 `Breeding group description` — free text, filled on the first row of a group only

Current state: 5 groups (Q1–Q5), 4 animals each = 20 of the 41 listed animals. The
other 21 are individual animals. Group prices: Q1=2250, Q2=2150, Q3=2000, Q4=2000,
Q5=4000. Only Q1 currently has description text ("This breeding group...").

## Data model — `animals.json`

Add a `breeding_groups` object as a sibling to the existing `litters` object, and add a
`breeding_group` field to each grouped animal.

```json
{
  "config": { ... },
  "breeding_groups": {
    "Q1": { "price": 2250, "description": "This breeding group..." },
    "Q2": { "price": 2150, "description": "..." }
  },
  "animals": [
    { "id": "BZ06", "breeding_group": "Q1", "morphs": [...], "price": 700, ... }
  ]
}
```

- A grouped animal keeps its individual `price` field in the data (no data loss), but the
  UI shows the **group** price for grouped animals.
- Ungrouped animals have no `breeding_group` field — unchanged from today.

## Spreadsheet sync (manual, Claude-driven)

When the user says "sync from the spreadsheet", Claude:

1. Reads `Sheet1` of `Catalogue-of-Lizards_Tyler-Peirce.xlsx`.
2. For each animal row, if `Breeding group` (col 5) is set, stamp `breeding_group` onto
   the matching animal in `animals.json` (match by `Animal_code` → `id`).
3. Build the `breeding_groups` object from the distinct group ids: `price` from col 4,
   `description` from the first non-empty col 17 value within that group.
4. Leave individual (ungrouped) animals untouched.

This follows the existing workflow where price/DOB updates are applied from the
spreadsheet by hand rather than an automated script.

## Layout & rendering — `index.html`

### Order
Breeding groups render **first** (top of the grid), then individual animals.

### Group header banner
Each group is preceded by a full-width banner spanning all grid columns, styled with the
existing accent palette (reuse/extend the `litter-notice` styling):

```
┌──────────────────────────────────────────────────┐
│  BREEDING GROUP Q1               $2,250 AUD / group │
│  This breeding group... (description text)          │
└──────────────────────────────────────────────────┘
[BZ06 card] [CZ03 card] [DZ13 card] [EZ05 card]
```

- Banner shows: group id, group price (`$X,XXX AUD / group`), description text.
- Banner is a grid item with `grid-column: 1 / -1` so it spans the full row.

### Cards inside a group
- Each card shows `Group price: $2,250` instead of its own individual price.
- Otherwise identical to existing cards (photo, morphs, hets, dob, notes).
- Clicking a grouped animal opens the existing modal; the modal shows the group price
  labeled as the group price (and may note the group id).

### Ungrouped individual cards
Rendered exactly as today, below all the groups.

## Filter interaction

- **No filter:** all groups (intact) shown first, then all individuals.
- **Sex filter (Male/Female):** groups are bundles that cannot be split, so each group
  stays fully intact and visible regardless of the sex filter. Only ungrouped individual
  animals are filtered by sex.
- **Morph filter:** a group is shown (fully intact) if at least one of its members matches
  the morph filter; otherwise the group is hidden. Individuals filter as today.

## Out of scope (YAGNI)

- No automated spreadsheet→JSON script (kept manual, consistent with current workflow).
- No per-animal removal from a group in the UI (groups are fixed bundles).
- No editing of descriptions in the UI (descriptions come from the spreadsheet).
- No separate "buy this group" form wiring beyond the existing enquiry mechanism.

## Affected files

- `animals.json` — add `breeding_groups`, add `breeding_group` to 20 animals.
- `index.html` — group rendering, header banner, card price label, filter logic, modal
  price label, and boot code to read `data.breeding_groups`.
