#!/usr/bin/env python3
"""
apply_frosted_blur.py

Utility script to generate frosted blur / redaction fills for OpenPencil image overlays.
Crops the target region from the source image, applies Gaussian blur, optionally adds
sheen, encodes to base64, and updates the OpenPencil node via MCP stdio.
"""

import argparse
import base64
import io
import json
import os
import subprocess
import sys
from PIL import Image, ImageFilter, ImageEnhance


def send_mcp_command(name, arguments):
    p = subprocess.Popen(
        ["openpencil-mcp"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    def send(msg):
        p.stdin.write(json.dumps(msg) + "\n")
        p.stdin.flush()

    def read():
        line = p.stdout.readline()
        return json.loads(line) if line else None

    # MCP handshake
    send({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "frosted-blur-cli", "version": "1.0"},
        },
    })
    read()
    send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    # Tool call
    send({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/call",
        "params": {
            "name": name,
            "arguments": arguments,
        },
    })
    resp = read()
    p.kill()
    return resp


def apply_blur(src_path, node_id, crop_box, radius=7, sheen=0, brightness=1.0):
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size

    x1, y1, x2, y2 = crop_box
    x1 = max(0, min(w, x1))
    y1 = max(0, min(h, y1))
    x2 = max(x1, min(w, x2))
    y2 = max(y1, min(h, y2))

    cropped = img.crop((x1, y1, x2, y2))

    # Apply Gaussian blur
    blurred = cropped.filter(ImageFilter.GaussianBlur(radius=radius))

    if brightness != 1.0:
        blurred = ImageEnhance.Brightness(blurred).enhance(brightness)

    if sheen > 0:
        sheen_layer = Image.new("RGBA", blurred.size, (255, 255, 255, int(sheen)))
        blurred = Image.alpha_composite(blurred, sheen_layer)

    buf = io.BytesIO()
    blurred.convert("RGB").save(buf, format="JPEG", quality=95)
    b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

    result = send_mcp_command("set_image_fill", {
        "id": node_id,
        "image_data": b64,
        "scale_mode": "FILL"
    })
    return result


def main():
    parser = argparse.ArgumentParser(description="Apply frosted blur to OpenPencil overlay node")
    parser.add_argument("--src", required=True, help="Source full image path")
    parser.add_argument("--node-id", required=True, help="OpenPencil target node ID (e.g. 0:48)")
    parser.add_argument("--crop", required=True, help="Crop box x1,y1,x2,y2 in source image pixels")
    parser.add_argument("--radius", type=int, default=7, help="Gaussian blur radius (default: 7)")
    parser.add_argument("--sheen", type=int, default=0, help="White sheen alpha 0-255 (default: 0)")
    parser.add_argument("--brightness", type=float, default=1.0, help="Brightness multiplier (default: 1.0)")

    args = parser.parse_args()
    crop_parts = [float(x.strip()) for x in args.crop.split(",")]
    if len(crop_parts) != 4:
        print("Error: --crop must be 4 comma-separated numbers: x1,y1,x2,y2", file=sys.stderr)
        sys.exit(1)

    res = apply_blur(
        src_path=args.src,
        node_id=args.node_id,
        crop_box=crop_parts,
        radius=args.radius,
        sheen=args.sheen,
        brightness=args.brightness
    )
    print("Result:", json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
