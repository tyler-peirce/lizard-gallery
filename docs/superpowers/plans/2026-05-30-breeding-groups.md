# Breeding Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display breeding groups (fixed bundles of animals sold for one group price) on the lizard for-sale gallery, with a per-group header banner showing description and group price.

**Architecture:** Extend `animals.json` with a `breeding_groups` object (sibling to `litters`) and a `breeding_group` field on grouped animals. In `index.html`, render groups first — each preceded by a full-width banner — then ungrouped individuals. Grouped cards show the group price.

**Tech Stack:** Vanilla HTML/CSS/JS single file (`index.html`), `animals.json` data, no build step, no test framework. Verification is browser-based via a local static server.

---

## Verification setup (used by every task)

This project has no automated tests. Verify each rendering change in a browser:

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
python3 -m http.server 8765
```

Then open `http://localhost:8765/` — the page has an entry gate (email form); submit it to reveal the gallery. Open the browser devtools Console and confirm **no errors**. Stop the server with Ctrl-C when done.

For JSON validity (Task 1), use the `jq` / `python3 -m json.tool` checks shown in the task.

---

## Task 1: Sync breeding group data into animals.json

**Files:**
- Modify: `/Users/tylerpeirce/agents/lizard-gallery/animals.json`

Source: `Catalogue-of-Lizards_Tyler-Peirce.xlsx`, sheet `Sheet1`. Columns (1-indexed in openpyxl tuple): col 3 `Animal_code`, col 4 `Breeding group price`, col 5 `Breeding group`, col 17 `Breeding group description`.

The 5 groups and their members (already confirmed present in `animals.json`):

| Group | Price | Members |
|-------|-------|---------|
| Q1 | 2250 | BZ06, CZ03, DZ13, EZ05 |
| Q2 | 2150 | BZ08, CZ06, DZ11, EZ09 |
| Q3 | 2000 | BZ09, CZ1124, DZ10, EZ12 |
| Q4 | 2000 | BZ07, CZ02, DZ07, EZ14 |
| Q5 | 4000 | BZ01, C, EZ10, Z |

- [ ] **Step 1: Run the sync script to regenerate animals.json**

This reads the spreadsheet, stamps `breeding_group` onto each member, and builds the `breeding_groups` object (price from col 4, description from the first non-empty col 17 per group). It preserves all existing animal fields and ordering, and inserts `breeding_groups` after `config`.

Run (uses the venv created during exploration, or recreate it):

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
[ -d /tmp/xlsx_venv ] || { python3 -m venv /tmp/xlsx_venv && /tmp/xlsx_venv/bin/pip install -q openpyxl; }
/tmp/xlsx_venv/bin/python3 - <<'PYEOF'
import json, openpyxl
from collections import OrderedDict

XLSX = 'Catalogue-of-Lizards_Tyler-Peirce.xlsx'
wb = openpyxl.load_workbook(XLSX, read_only=True, data_only=True)
ws = wb['Sheet1']

# Map animal_code -> (group, price); collect first description per group
rows = list(ws.iter_rows(min_row=2, values_only=True))
code_to_group = {}
group_price = {}
group_desc = {}
for r in rows:
    code  = r[3]
    price = r[4]
    group = r[5]
    desc  = r[17] if len(r) > 17 else None
    if not group:
        continue
    code_to_group[str(code)] = group
    if group not in group_price and isinstance(price, (int, float)):
        group_price[group] = int(price)
    if group not in group_desc and desc:
        group_desc[group] = str(desc).strip()

# Build breeding_groups in group-id order (Q1, Q2, ...)
breeding_groups = OrderedDict()
for g in sorted(group_price.keys()):
    breeding_groups[g] = {
        "price": group_price[g],
        "description": group_desc.get(g, "")
    }

# Load existing animals.json, preserving key order
with open('animals.json') as f:
    data = json.load(f, object_pairs_hook=OrderedDict)

# Stamp breeding_group onto matching animals (insert right after "id")
for a in data['animals']:
    g = code_to_group.get(a['id'])
    if g:
        new = OrderedDict()
        for k, v in a.items():
            new[k] = v
            if k == 'id':
                new['breeding_group'] = g
        a.clear()
        a.update(new)

# Insert breeding_groups after config, before animals
out = OrderedDict()
for k, v in data.items():
    out[k] = v
    if k == 'config':
        out['breeding_groups'] = breeding_groups
if 'breeding_groups' not in out:  # config absent edge case
    out['breeding_groups'] = breeding_groups

with open('animals.json', 'w') as f:
    json.dump(out, f, indent=2, ensure_ascii=False)
    f.write('\n')

print("breeding_groups:", json.dumps(breeding_groups, ensure_ascii=False))
print("stamped animals:", sorted(code_to_group.keys()))
PYEOF
```

Expected output: a `breeding_groups` JSON with Q1–Q5 (Q1 price 2250 + the real description text, Q2 2150, Q3 2000, Q4 2000, Q5 4000 with empty descriptions), and a list of 20 stamped animal ids.

- [ ] **Step 2: Validate the JSON and spot-check the structure**

Run:

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
python3 -m json.tool animals.json > /dev/null && echo "VALID JSON"
/tmp/xlsx_venv/bin/python3 - <<'PYEOF'
import json
d = json.load(open('animals.json'))
assert 'breeding_groups' in d, "breeding_groups missing"
assert set(d['breeding_groups']) == {'Q1','Q2','Q3','Q4','Q5'}, d['breeding_groups'].keys()
assert d['breeding_groups']['Q1']['price'] == 2250
assert d['breeding_groups']['Q1']['description'], "Q1 description empty"
grouped = [a['id'] for a in d['animals'] if a.get('breeding_group')]
assert len(grouped) == 20, f"expected 20 grouped, got {len(grouped)}"
# spot check one
bz06 = next(a for a in d['animals'] if a['id']=='BZ06')
assert bz06['breeding_group'] == 'Q1'
assert 'price' in bz06, "individual price should be preserved"
print("OK:", len(grouped), "grouped animals;", len(d['animals']), "total")
PYEOF
```

Expected: `VALID JSON` then `OK: 20 grouped animals; 41 total`.

- [ ] **Step 3: Commit**

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
git add animals.json
git commit -m "feat: add breeding_groups data synced from spreadsheet"
```

---

## Task 2: Add breeding group banner CSS

**Files:**
- Modify: `/Users/tylerpeirce/agents/lizard-gallery/index.html` (insert after the `.litter-notice` block, around line 175)

- [ ] **Step 1: Add the banner styles**

Insert this CSS block immediately after the `.litter-notice a:hover { ... }` line (currently line 175) and before the `/* ── Empty state ── */` comment:

```css
        /* ── Breeding group banner ── */
        .group-banner {
            grid-column: 1 / -1;
            background: linear-gradient(180deg, var(--surface2), var(--surface));
            border: 1px solid var(--accent-dim);
            border-radius: var(--radius);
            padding: 1rem 1.25rem;
            display: flex;
            flex-direction: column;
            gap: 0.4rem;
        }
        .group-banner-top {
            display: flex;
            justify-content: space-between;
            align-items: baseline;
            gap: 1rem;
            flex-wrap: wrap;
        }
        .group-banner-title {
            font-size: 1rem;
            font-weight: 700;
            color: var(--accent);
            letter-spacing: 0.02em;
        }
        .group-banner-price {
            font-size: 1rem;
            font-weight: 700;
            color: var(--accent);
            white-space: nowrap;
        }
        .group-banner-desc {
            font-size: 0.85rem;
            color: var(--text-dim);
            line-height: 1.45;
        }
        .card-group-price { font-size: 0.85rem; font-weight: 600; color: var(--accent); }
```

- [ ] **Step 2: Verify the page still loads with no console errors**

Start the server (see Verification setup), open the page, pass the gate, confirm the gallery renders as before and the Console shows no errors. CSS-only change, so layout is unchanged at this point.

- [ ] **Step 3: Commit**

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
git add index.html
git commit -m "feat: add breeding group banner styles"
```

---

## Task 3: Read breeding_groups on boot and store in state

**Files:**
- Modify: `/Users/tylerpeirce/agents/lizard-gallery/index.html` — state object (around line 602-608) and boot block (around line 1044-1053)

- [ ] **Step 1: Add `breedingGroups` to state**

In the `const state = { ... }` object (currently starts line 602), add a `breedingGroups: {},` line right after `litters: {},`:

```javascript
    const state = {
        animals:     [],
        litters:     {},
        breedingGroups: {},
        filterMorph: null,
        filterSex:   null,
        modal: { animal: null, photos: [], index: 0, animalIdx: -1, discovering: false },
    };
```

- [ ] **Step 2: Populate it on boot**

In the boot `fetch('animals.json')` `.then` block (currently around line 1047-1052), add the breeding groups assignment after the `state.litters` line:

```javascript
            CONFIG        = Object.assign({ watermark: '', formspreeId: '' }, data.config || {});
            state.animals = data.animals || [];
            state.litters = data.litters || {};
            state.breedingGroups = data.breeding_groups || {};
            initGate();
            render();
```

- [ ] **Step 3: Verify**

Reload the page (server still running), pass the gate. In the Console run `state.breedingGroups` — wait, `state` is module-scoped and not global. Instead confirm no console errors on load; the data wiring is exercised in Task 4. Visual output unchanged here.

- [ ] **Step 4: Commit**

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
git add index.html
git commit -m "feat: load breeding_groups into app state"
```

---

## Task 4: Render groups first with banners, grouped cards show group price

**Files:**
- Modify: `/Users/tylerpeirce/agents/lizard-gallery/index.html` — `getFiltered()` (lines 667-700), `render()` (lines 703-732), `makeCard()` price line (line 792), and add a `makeGroupBanner()` helper.

This task changes how the gallery is assembled. Read the existing `getFiltered` and `render` before editing.

**Important:** `openModal()` calls `getFiltered().visible` in four places (lines 830, 841, 874, 878) to drive prev/next navigation. The new `getFiltered` MUST still return a flat `visible` array in on-screen order, or modal navigation breaks. The code below does this. `openModal` itself needs no change for navigation.

- [ ] **Step 1: Replace `getFiltered()` to separate grouped vs ungrouped, apply the new filter rules, and return a flat `visible` array**

Replace the entire `getFiltered` function (currently lines 667-700) with:

```javascript
    function getFiltered() {
        const { animals, litters, breedingGroups, filterMorph, filterSex } = state;

        // Split into grouped (breeding bundles) and individuals
        const grouped     = animals.filter(a => a.breeding_group);
        const individuals = animals.filter(a => !a.breeding_group);

        // ── Individuals: morph + sex filters, then litter capping ──
        let matched = individuals.filter(a =>
            animalMatchesMorph(a, filterMorph) &&
            (!filterSex || a.sex === filterSex)
        );
        if (filterMorph) {
            const visuals = matched.filter(a =>  animalExpressesMorph(a, filterMorph));
            const hets    = matched.filter(a => !animalExpressesMorph(a, filterMorph));
            matched = [...visuals, ...hets];
        }

        const seen = {}, hidden = {}, capped = [];
        for (const animal of matched) {
            const lid = animal.litter;
            const max = lid && litters[lid]?.showCount;
            if (max) {
                seen[lid]   = seen[lid]   || 0;
                hidden[lid] = hidden[lid] || 0;
                if (seen[lid] < max) { seen[lid]++; capped.push(animal); }
                else { hidden[lid]++; }
            } else {
                capped.push(animal);
            }
        }

        // Order individuals for display: non-litter first, then litter buckets
        const litterBuckets = {};
        const noLitter = [];
        for (const a of capped) {
            if (a.litter) (litterBuckets[a.litter] = litterBuckets[a.litter] || []).push(a);
            else noLitter.push(a);
        }

        // ── Breeding groups: bundles stay intact. Sex filter never splits them.
        //    Morph filter shows a group only if at least one member matches. ──
        const groupOrder = Object.keys(breedingGroups);
        const groupBuckets = {};
        for (const a of grouped) {
            (groupBuckets[a.breeding_group] = groupBuckets[a.breeding_group] || []).push(a);
        }
        const visibleGroups = [];
        for (const gid of groupOrder) {
            const members = groupBuckets[gid] || [];
            if (members.length === 0) continue;
            if (filterMorph && !members.some(a => animalMatchesMorph(a, filterMorph))) continue;
            visibleGroups.push({ id: gid, members });
        }

        // Flat visible list in on-screen order (group members first, then individuals)
        const visible = [];
        for (const g of visibleGroups) visible.push(...g.members);
        visible.push(...noLitter);
        for (const bucket of Object.values(litterBuckets)) visible.push(...bucket);

        return { visibleGroups, noLitter, litterBuckets, hidden, visible, visibleCount: visible.length };
    }
```

- [ ] **Step 2: Replace `render()` to draw groups first, then individuals (reusing getFiltered's ordering)**

Replace the entire `render` function (currently lines 703-732) with:

```javascript
    function render() {
        renderFilters();

        const { visibleGroups, noLitter, litterBuckets, hidden, visibleCount } = getFiltered();
        const gallery = document.getElementById('gallery');
        gallery.innerHTML = '';

        document.getElementById('count').textContent =
            `${visibleCount} animal${visibleCount !== 1 ? 's' : ''} shown`;

        if (visibleCount === 0) {
            gallery.innerHTML = '<div class="empty">No animals match this filter.</div>';
            return;
        }

        // Breeding groups first: banner + member cards
        for (const group of visibleGroups) {
            gallery.appendChild(makeGroupBanner(group.id));
            for (const a of group.members) gallery.appendChild(makeCard(a));
        }

        // Then individuals: non-litter first, then litter buckets with notices
        for (const a of noLitter) gallery.appendChild(makeCard(a));
        for (const [lid, group] of Object.entries(litterBuckets)) {
            for (const a of group) gallery.appendChild(makeCard(a));
            if (hidden[lid] > 0) gallery.appendChild(makeLitterNotice(lid, hidden[lid]));
        }
    }
```

- [ ] **Step 3: Add the `makeGroupBanner()` helper**

Insert this function immediately before `makeLitterNotice` (currently line 813):

```javascript
    function makeGroupBanner(groupId) {
        const g = state.breedingGroups[groupId] || {};
        const price = g.price ? `$${g.price.toLocaleString()} AUD / group` : 'Price on application';
        const div = document.createElement('div');
        div.className = 'group-banner';
        div.innerHTML = `
            <div class="group-banner-top">
                <span class="group-banner-title">Breeding Group ${groupId}</span>
                <span class="group-banner-price">${price}</span>
            </div>
            ${g.description ? `<div class="group-banner-desc">${g.description}</div>` : ''}
        `;
        return div;
    }
```

- [ ] **Step 4: Make grouped cards show the group price**

In `makeCard` (currently line 792), replace the single price line:

```javascript
        const price    = animal.price ? `$${animal.price.toLocaleString()} AUD` : 'POA';
```

with logic that prefers the group price for grouped animals:

```javascript
        const groupPrice = animal.breeding_group
            ? state.breedingGroups[animal.breeding_group]?.price
            : null;
        const priceHtml = groupPrice
            ? `<div class="card-group-price">Group price: $${groupPrice.toLocaleString()} AUD</div>`
            : `<div class="price">${animal.price ? `$${animal.price.toLocaleString()} AUD` : 'POA'}</div>`;
```

Then in the `body.innerHTML` template (currently line 802), replace the line `<div class="price">${price}</div>` with `${priceHtml}`.

- [ ] **Step 5: Verify in the browser**

Start the server, open the page, pass the gate. Confirm:
- 5 banners labeled **Breeding Group Q1 … Q5** appear at the top, each spanning the full width.
- Q1 banner shows the description text and `$2,250 AUD / group`; Q5 shows `$4,000 AUD / group`.
- Cards directly under each banner show **Group price: $X,XXX AUD** (not an individual price).
- Individual animals appear below all groups, unchanged.
- The count reads `41 animals shown`.
- Console shows no errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
git add index.html
git commit -m "feat: render breeding groups first with banners and group pricing"
```

---

## Task 5: Verify filter interaction

**Files:** none (verification of Task 4 logic). If a check fails, fix `getFiltered` in `index.html` per the spec rules.

- [ ] **Step 1: Sex filter keeps groups intact**

With the page open, click the **Male** sex filter. Confirm:
- All 5 breeding group banners are still shown, each with all 4 member cards intact (groups are not split by sex).
- Among the **individual** (non-group) animals below, only males are shown.
- Click **Female**: same — groups stay fully intact, individuals show only females.
- Console shows no errors.

- [ ] **Step 2: Morph filter shows only groups with a matching member**

Click a morph filter (e.g. **Anery**). Confirm:
- A breeding group banner appears only if at least one of its 4 members matches that morph; non-matching groups (and their banners) disappear.
- Clear the filter (click the active morph again / the "All" control): all 5 groups return.
- Console shows no errors.

- [ ] **Step 3: Commit (only if a fix was needed)**

If Steps 1-2 passed with no change, skip. If you edited `index.html`:

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
git add index.html
git commit -m "fix: breeding group filter interaction"
```

---

## Task 6: Show group price in the modal for grouped animals

**Files:**
- Modify: `/Users/tylerpeirce/agents/lizard-gallery/index.html` — `openModal()` price computation (line 840) and the two places it is rendered (`compact-price` line 852, `modal-price` line 868).

- [ ] **Step 1: Compute the group-aware price label in `openModal`**

In `openModal` (currently line 840), replace:

```javascript
        const price    = animal.price ? `$${animal.price.toLocaleString()} AUD` : 'Price on application';
```

with:

```javascript
        const groupPrice = animal.breeding_group
            ? state.breedingGroups[animal.breeding_group]?.price
            : null;
        const price = groupPrice
            ? `$${groupPrice.toLocaleString()} AUD (Group ${animal.breeding_group})`
            : (animal.price ? `$${animal.price.toLocaleString()} AUD` : 'Price on application');
```

The existing `compact-price` (line 852) and `modal-price` (line 868) already interpolate `${price}`, so no further template change is needed.

- [ ] **Step 2: Verify**

Open the page, click a card inside a breeding group (e.g. BZ06). Confirm the modal price reads `$2,250 AUD (Group Q1)`. Click an individual animal: modal shows its normal individual price. Console shows no errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/tylerpeirce/agents/lizard-gallery
git add index.html
git commit -m "feat: show breeding group price in modal"
```

---

## Done

After Task 6, the feature is complete: groups render first with descriptive banners and group pricing, grouped cards and the modal show the group price, sex filters keep bundles intact, and morph filters hide irrelevant groups. To add descriptions for Q2–Q5 later, fill the `Breeding group description` column in the spreadsheet and re-run Task 1's sync script.
