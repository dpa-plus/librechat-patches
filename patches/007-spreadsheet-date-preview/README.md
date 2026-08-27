# 007 — formatted dates in spreadsheet previews

**Applied:** yes — built into the image, see `Dockerfile`  
**Type:** B (opt-in preview formatting; unset keeps upstream behavior)  
**Base:** v0.8.7  
**Upstream status:** not offered yet

LibreChat renders spreadsheet previews through SheetJS. By default, date cells
can reach `sheet_to_html` as numeric Excel serials even when the workbook
contains a valid date number format. A user then sees a value such as
`46241.51806` instead of the intended date and time.

This patch adds an opt-in preview mode:

```env
SPREADSHEET_PREVIEW_FORMAT_DATES=true
```

When enabled, XLSX workbooks are read with date cells and number formats
preserved. Date display values are produced from the workbook's own format
before the sanitized HTML preview is generated. Literal dots in otherwise
valid Excel date formats are escaped for SheetJS' SSF formatter.

The workbook itself is never modified. Unsupported or unusual formats keep
SheetJS' readable fallback, and all existing ZIP-bomb and HTML sanitization
checks remain in place.

## Compatibility contract

With the variable unset, LibreChat follows the upstream rendering path without
behavioral changes. Truthy values are `true`, `1`, and `yes`, case-insensitive.

## Verification

The regression test creates a workbook containing the Excel serial
`46241.51805555556` with the number format `DD.MM.YYYY HH:MM`. With the option
enabled, the generated HTML contains `07.08.2026 12:26` and not the serial.
