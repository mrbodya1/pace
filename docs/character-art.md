# Character cutouts

The seven individual game-style sport characters are stored as RGBA PNG files, 600×900, in assets/images/specializations/: runner.png, marathoner.png, multiathlete.png, trailrunner.png, skier.png, cyclist.png, swimmer.png. They replace the earlier opaque JPEG versions. The existing specialization IDs and saved profile values are unchanged.

Mode: built-in image_gen editing, transparent_background=true. Each source character was edited separately, with the source image provided as referenced_image_paths. No external image API or algorithmic background removal was used.

Prompt set: background-extraction. Remove the navy backdrop, purple glow, rocks/snow platform and ground shadow. Preserve the exact adult athlete identity, pose, black/lime clothing and equipment. Keep the complete body, hands, shoes, hair and clean edges. Retain bicycle and its transparent spoke gaps for cyclist; retain skis and poles for skier. Output an isolated character on genuinely transparent alpha, no background, halo, UI, text or logos. Trailrunner received an additional pass explicitly removing the outer aura.

Final PNG resizing retained the alpha channel. Transparent corners were checked at A=0; visible athlete pixels retain high alpha. Compositing was reviewed against the app's navy/violet background, rather than judging hidden RGB values of fully transparent pixels.
