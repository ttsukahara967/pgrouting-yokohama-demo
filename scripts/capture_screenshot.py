"""Capture docs/screenshot.png: a route from Yokohama Station to Minato Mirai.

Run with the stack up (see README "Updating the screenshot"):
  docker run --rm -v "$PWD:/work" -w /work -e APP_URL=http://host.docker.internal:8110 \
    mcr.microsoft.com/playwright/python:v1.49.1-noble \
    sh -c "pip install -q playwright==1.49.1 && python scripts/capture_screenshot.py"
"""

import os

from playwright.sync_api import sync_playwright

APP_URL = os.environ.get("APP_URL", "http://host.docker.internal:8080")
START = (35.4658, 139.6223)  # Yokohama Station
GOAL = (35.4440, 139.6380)   # Kannai


def click_latlng(page, lat, lon):
    pt = page.evaluate(f"(() => {{ const p = map.latLngToContainerPoint([{lat}, {lon}]); return [p.x, p.y]; }})()")
    page.mouse.click(pt[0], pt[1])


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1280, "height": 800}, locale="ja-JP")
    page.goto(APP_URL)
    page.wait_for_function("typeof bbox !== 'undefined' && bbox !== null")
    page.evaluate("map.setView([35.456, 139.630], 15)")
    page.wait_for_timeout(500)
    click_latlng(page, *START)
    click_latlng(page, *GOAL)
    page.wait_for_selector("#result b")
    page.wait_for_load_state("networkidle")
    page.wait_for_timeout(1500)  # let tiles finish fading in
    page.screenshot(path="docs/screenshot.png")
    print("result:", page.inner_text("#result"))
    browser.close()
