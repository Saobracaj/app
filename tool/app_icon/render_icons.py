"""Renders every app icon (Android, iOS, web, in-app logo) from Saobracaj-icon.svg.

Usage: python3 tool/app_icon/render_icons.py
Needs Google Chrome (headless) — no ImageMagick/rsvg on the dev machine.
"""
import os, subprocess, tempfile
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SRC = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "Saobracaj-icon.svg")).read()
PATH_D = SRC.split('<path d="')[1].split('"')[0]
BLUE = "#1060A9"
TMP = tempfile.mkdtemp(prefix="app_icon_")
APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def svg_full(radius_pct=0):
    r = 800 * radius_pct
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800">'
            f'<rect width="800" height="800" rx="{r}" ry="{r}" fill="{BLUE}"/>'
            f'<path d="{PATH_D}" fill="white"/></svg>')

def svg_adaptive_fg(color="white"):
    # Adaptive icon: canvas 108dp, visible 72dp -> the 800px square maps to the
    # central 2/3, i.e. viewBox 1200 with the artwork shifted by 200.
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 1200">'
            f'<g transform="translate(200 200)"><path d="{PATH_D}" fill="{color}"/></g></svg>')

def svg_bg():
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 1200">'
            f'<rect width="1200" height="1200" fill="{BLUE}"/></svg>')

def render(svg, size, out, transparent=False):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp_svg = os.path.join(TMP, "_cur.svg"); tmp_html = os.path.join(TMP, "_cur.html")
    open(tmp_svg, "w").write(svg)
    open(tmp_html, "w").write(
        f'<!doctype html><html><body style="margin:0;background:{"transparent" if transparent else BLUE}">'
        f'<img src="file://{tmp_svg}" style="display:block;width:{size}px;height:{size}px"></body></html>')
    args = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
            f"--window-size={size},{size}", f"--screenshot={out}"]
    if transparent:
        args.append("--default-background-color=00000000")
    args.append(f"file://{tmp_html}")
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print("ok", size, os.path.relpath(out, APP))

full = svg_full()
# --- web ---
render(full, 64, f"{APP}/web/favicon.png")
for s in (192, 512):
    render(full, s, f"{APP}/web/icons/Icon-{s}.png")
    render(full, s, f"{APP}/web/icons/Icon-maskable-{s}.png")
# --- in-app logo ---
render(full, 256, f"{APP}/assets/img/app_icon.png")
# --- iOS ---
ios = {
 "AppIcon@2x.png":120, "AppIcon@3x.png":180, "AppIcon~ipad.png":76, "AppIcon@2x~ipad.png":152,
 "AppIcon-83.5@2x~ipad.png":167, "AppIcon-40@2x.png":80, "AppIcon-40@3x.png":120, "AppIcon-40~ipad.png":40,
 "AppIcon-40@2x~ipad.png":80, "AppIcon-20@2x.png":40, "AppIcon-20@3x.png":60, "AppIcon-20~ipad.png":20,
 "AppIcon-20@2x~ipad.png":40, "AppIcon-29.png":29, "AppIcon-29@2x.png":58, "AppIcon-29@3x.png":87,
 "AppIcon-29~ipad.png":29, "AppIcon-29@2x~ipad.png":58, "AppIcon-60@2x~car.png":120, "AppIcon-60@3x~car.png":180,
 "AppIcon~ios-marketing.png":1024,
}
for name, s in ios.items():
    render(full, s, f"{APP}/ios/Runner/Assets.xcassets/AppIcon.appiconset/{name}")
# --- Android ---
dens = {"mdpi":1, "hdpi":1.5, "xhdpi":2, "xxhdpi":3, "xxxhdpi":4}
legacy = svg_full(radius_pct=0.2)  # rounded square for pre-Oreo launchers
for d, k in dens.items():
    base = f"{APP}/android/app/src/main/res/mipmap-{d}"
    render(legacy, int(48*k), f"{base}/ic_launcher.png", transparent=True)
    render(svg_bg(), int(108*k), f"{base}/ic_launcher_background.png")
    render(svg_adaptive_fg("white"), int(108*k), f"{base}/ic_launcher_foreground.png", transparent=True)
    render(svg_adaptive_fg("black"), int(108*k), f"{base}/ic_launcher_monochrome.png", transparent=True)
