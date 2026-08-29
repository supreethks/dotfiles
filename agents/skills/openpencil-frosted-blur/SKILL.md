---
name: openpencil-frosted-blur
description: Apply authentic frosted glass blur and redactions to regions of images or screenshots in OpenPencil. Use when blurring, redacting, frosting, or obscuring sensitive text, terminal outputs, or UI sections in OpenPencil designs.
---

# OpenPencil Frosted Blur & Redaction

This skill provides the workflow and automated tooling to apply clean, realistic frosted glass blur and text redactions to specific regions of images in OpenPencil documents.

## Why Custom Region Blur is Needed

In OpenPencil:
1. Native `BACKGROUND_BLUR` applied on transparent vector shapes over bitmap images does not composite against the underlying pixels in all render targets (often rendering opaque white or bleeding through unblurred pixels if layer opacity is reduced).
2. Applying blur directly to the whole image blurs the entire canvas rather than isolated sensitive regions.
3. The clean, reliable solution is to crop the target region from the source image, apply Gaussian blur (preserving native dark-mode or light-mode tone), and apply it to an overlay shape using `set_image_fill`.

---

## Quick Workflow

### 1. Identify Target Node & Region
1. Check the open document and page tree:
   ```bash
   # via OpenPencil MCP tools: list_documents, get_page_tree, get_node
   ```
2. Note the base image node ID and the rectangle overlay node ID on the canvas.
3. Calculate relative pixel crop coordinates:
   ```python
   x1 = max(0, overlay_x - image_x)
   y1 = max(0, overlay_y - image_y)
   x2 = x1 + overlay_width
   y2 = y1 + overlay_height
   ```

### 2. Run the Frosted Blur Script
Use the built-in utility script to compute the blur and update the node in OpenPencil:

```bash
python3 /Users/supreethks/.agents/skills/openpencil-frosted-blur/scripts/apply_frosted_blur.py \
  --src "/path/to/original_image.png" \
  --node-id "<OVERLAY_NODE_ID>" \
  --crop "<x1>,<y1>,<x2>,<y2>" \
  --radius <BLUR_RADIUS>
```

---

## Blur Strength Guidelines

| Task | Recommended Radius | Notes |
|---|---|---|
| **Subtle Soft Blur** | `6 - 8` | Text shape/lines remain visible, small font unreadable. Great for aesthetic privacy. |
| **Standard Redaction** | `12 - 14` | Clean dark-mode redaction. Line shapes visible, characters completely obscured. |
| **Heavy Frosted Glass** | `25 - 32` | Complete diffusion into smooth gradient blocks. |

---

## Visual Styles

### Dark Mode (Default)
Preserve the exact dark background and syntax highlight hues without washing out:
```bash
# Keep sheen=0 and brightness=1.0 (default)
--radius 7
```

### Light Frosted Sheen (macOS / Glassmorphism Style)
Add a subtle specular white highlight over the blur:
```bash
--radius 25 --sheen 35 --brightness 1.2
```

---

## Verification
Always export a low-scale preview to verify before finalizing:
```json
// Tool: open-pencil/export_image
{ "format": "PNG", "scale": 0.5 }
```
