# Character cutouts

Fourteen game-style sport characters are stored as RGBA PNG files, 600×900, in assets/images/specializations/male/ and assets/images/specializations/female/. Each directory contains runner.png, marathoner.png, multiathlete.png, trailrunner.png, skier.png, cyclist.png and swimmer.png. These replace the older mixed-sex root-level images; specialization IDs stay unchanged.

Mode: built-in image_gen editing, transparent_background=true. Each source character was edited separately, with the source image provided as referenced_image_paths. No external image API or algorithmic background removal was used.

Prompt set: background-extraction. Remove the navy backdrop, purple glow, rocks/snow platform and ground shadow. Preserve the exact adult athlete identity, pose, black/lime clothing and equipment. Keep the complete body, hands, shoes, hair and clean edges. Retain bicycle and its transparent spoke gaps for cyclist; retain skis and poles for skier. Output an isolated character on genuinely transparent alpha, no background, halo, UI, text or logos. Trailrunner received an additional pass explicitly removing the outer aura.

Final PNG resizing retained the alpha channel. Transparent corners were checked at A=0; visible athlete pixels retain high alpha. Compositing was reviewed against the app's navy/violet background, rather than judging hidden RGB values of fully transparent pixels.

Counterpart prompt set: edit the referenced isolated full-body athlete into an adult athletic woman/man, preserving pose, discipline-specific black/lime equipment, lighting and realistic game-character style. Keep all hands, head, feet and gear in frame; retain bike, skis and poles where applicable. Transparent alpha only, no environment, glow, halo, platform, shadow, UI or text. Each counterpart is a separate built-in image_gen edit.

Height normalization: male head-to-sole height 780 px, female 733.2 px (94%); common sole baseline y=790 in each 600×900 canvas. Head position is y=10 for men and y=56.8 for women. Aspect ratios and alpha are preserved. Skier body anchors use boot soles, not ski tips; equipment can extend below the common foot baseline. These heights are an art convention and do not alter the profile's real height parameter.

Selection uses the existing profile sex field (male/female), keeping participant selection and personal parameters consistent. Only confirmation writes the choice. Changing sex alone does not reset specializationChangedAt, affect class bonuses or recalculate old XP. Missing/unknown sex previews the male set without writing until confirmation.
