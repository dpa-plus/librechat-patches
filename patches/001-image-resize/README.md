# 001 — configurable image resize ceilings

**File:** `api/server/services/Files/images/resize.js`
**Applied:** yes
**Base:** v0.8.6-rc1
**Upstream status:** open — [discussion #6777](https://github.com/danny-avila/LibreChat/discussions/6777) (Apr 2025), [discussion #11065](https://github.com/danny-avila/LibreChat/discussions/11065) (Dec 2025), [issue #6776](https://github.com/danny-avila/LibreChat/issues/6776)

## What upstream does

`resizeImageBuffer` hardcodes three ceilings and applies them to **every** uploaded
image on **every** endpoint:

```js
const maxLowRes = 512;
const maxShortSideHighRes = 768;
const maxLongSideHighRes = endpoint === EModelEndpoint.anthropic ? 1568 : 2000;
```

There is no configuration path to any of them. The call site passes no
`resolution` at all, so uploads always take the `'high'` branch:

```js
handleImageUpload({ req, file, file_id, endpoint });   // -> resolution = 'high'
```

The maintainer has confirmed this is deliberate:

> "it is done across the board for image uploads, to retain dimensions accepted
> according to OpenAI spec, which would prevent certain images from creating an
> error when making vision requests. What you're proposing would be an
> improvement and will be considered."
> — danny-avila, [#6777](https://github.com/danny-avila/LibreChat/discussions/6777)

The numbers come from OpenAI's 2023 vision specification. They are applied to
custom endpoints too, including models that accept far more.

## Why it matters

Large-format technical drawings are the clearest case. A sheet in ISO A0 at
300 dpi is roughly 9900 × 4950 px. After upload it is **1538 × 768**. Labelling
that is 2.5 mm tall on the sheet — perfectly legible in the source — ends up
around 4.6 px high.

For comparison, Azure Document Intelligence documents 12 px as its minimum text
height and AWS Textract 15 px. So the image is unusable before any model is
involved, and the failure is silent: no error, no warning, just a worse answer.

Aspect ratio decides how badly it hurts, because the cap applies to the short
side:

| source (300 dpi) | after upload | scale |
|---|---|---|
| A0 landscape, ~2:1 | 1538 × 768 | 0.155 |
| A1 portrait, ~1.4:1 | 1086 × 768 | 0.22 |

The same applies to high-resolution scans, dense screenshots, and photographed
documents — anywhere the detail that matters is small relative to the sheet.

## What this patch changes

The same three values, read from the environment, with the upstream numbers as
defaults:

| Variable | Default | Replaces |
|---|---|---|
| `IMAGE_MAX_LOW_RES` | `512` | `maxLowRes` |
| `IMAGE_MAX_SHORT_SIDE` | `768` | `maxShortSideHighRes` |
| `IMAGE_MAX_LONG_SIDE` | `2000` | `maxLongSideHighRes` (non-Anthropic) |
| `IMAGE_MAX_LONG_SIDE_ANTHROPIC` | `1568` | `maxLongSideHighRes` (Anthropic) |

Non-numeric, zero, negative and empty values fall back to the default rather
than throwing.

**With no variables set, the behaviour is byte-for-byte identical to upstream.**
Nothing changes for anyone who does not opt in. That is deliberate: it keeps the
patch small, safe, and offerable upstream unchanged.

## What it does not fix

Raising these ceilings is necessary but not sufficient. Vision encoders have
their own pixel budgets — Kimi K2.6 downscales anything above ~3.2 MP at the
gateway, before tokenization. A full A0 sheet would need roughly 5700 px width
for legible labels, about 16 MP, which is five times what the model accepts.

Cropping to the drawing area stays mandatory. This patch only removes the
*second*, independent ceiling that sits in front of it.

## Upstream applicability

`resize.js` is byte-identical across `v0.8.6-rc1`, `v0.8.7` and `main`
(sha256 `091cc31a65084706…`, see `upstream.sha256`). The patch applies unchanged
to all three.
