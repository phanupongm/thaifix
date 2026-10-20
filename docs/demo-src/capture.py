import asyncio, sys
from playwright.async_api import async_playwright
FPS = 12
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(viewport={"width":800,"height":420}, device_scale_factor=1)
        await pg.goto("file:///tmp/claude-0/demo/demo.html")
        await pg.evaluate("document.fonts.ready")
        total = await pg.evaluate("window.TOTAL")
        n = int(total*FPS)
        for i in range(n):
            await pg.evaluate(f"render({i/FPS})")
            await pg.screenshot(path=f"/tmp/claude-0/demo/f/{i:04d}.png")
        await b.close()
        print(n, "frames")
asyncio.run(main())
