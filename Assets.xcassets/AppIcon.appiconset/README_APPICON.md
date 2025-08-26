How to generate iOS AppIcon PNGs from AppIcon.svg

Files here:
- AppIcon.svg: downloaded from https://aroundsketch.github.io/Apple-App-Icons/App-Icon/Apple/TestFlight/@SVG.svg
- Contents.json: iPhone + iPad + iOS Marketing mappings for Xcode.
- generate-icons.sh: renders all required PNGs from the SVG.

Steps (macOS):
1) Install a renderer (either works):
   - Homebrew + ImageMagick: `brew install imagemagick`
   - or librsvg: `brew install librsvg`
2) Run the generator from this folder:
   - `./generate-icons.sh`
3) Drag the whole `AppIcon.appiconset` into your Xcode `Assets.xcassets`.

Notes:
- App Store icons must not contain transparency. If your source SVG has transparency, flatten to a solid background.
- Xcode 15+ can use a single 1024px icon, but this set is compatible with older templates too.

