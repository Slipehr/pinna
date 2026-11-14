#!/bin/sh
# SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
# Required Notice: Copyright 2026 Slipehr
# Builds Pinna-x86_64.AppImage. Needs mksquashfs (squashfs-tools) and python3.
# The app itself runs on the system's python3 with GTK 4 and libadwaita.
set -eu
cd "$(dirname "$0")"
APPDIR=build/AppDir
HSC=vendor/headsetcontrol-appimage/squashfs-root/usr
RNNOISE=vendor/rnnoise/linux-rnnoise/ladspa/librnnoise_ladspa.so
RUNTIME_SRC=vendor/appimagetool/appimagetool-x86_64.AppImage

mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib/ladspa" "$APPDIR/usr/share/pinna/hrir"
cp pinna.py LICENSE "$APPDIR/usr/share/pinna/"
# License texts for the bundled third-party components.
mkdir -p "$APPDIR/usr/share/pinna/third-party-licenses"
cp third-party-licenses/GPL-3.0.txt third-party-licenses/NOTICE.txt "$APPDIR/usr/share/pinna/third-party-licenses/"
cp "$HSC/share/doc/libhidapi-hidraw0/copyright" "$APPDIR/usr/share/pinna/third-party-licenses/libhidapi-copyright.txt"
cp "$HSC/share/doc/libudev1/copyright" "$APPDIR/usr/share/pinna/third-party-licenses/libudev-copyright.txt"
cp "$HSC/bin/headsetcontrol" "$APPDIR/usr/bin/"
cp -a "$HSC"/lib/libhidapi-hidraw.so.0 "$HSC"/lib/libudev.so.1 "$APPDIR/usr/lib/"
cp "$RNNOISE" "$APPDIR/usr/lib/ladspa/"
for profile in dtshx atmos gsx sbx67 dht; do
    cp "vendor/hesuvi/extracted/HeSuVi/hrir/$profile.wav" "$APPDIR/usr/share/pinna/hrir/"
done
cp pinna.desktop pinna.svg "$APPDIR/"
VERSION=$(sed -n 's/^VERSION = "\(.*\)"$/\1/p' pinna.py)
echo "X-AppImage-Version=$VERSION" >> "$APPDIR/pinna.desktop"
cp pinna.svg "$APPDIR/.DirIcon"
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export APPDIR="$HERE"
exec /usr/bin/python3 "$HERE/usr/share/pinna/pinna.py" "$@"
APPRUN
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/headsetcontrol"

# An AppImage is a small ELF runtime followed by a squashfs image. Reuse the
# runtime from the front of the appimagetool download instead of executing it.
python3 - "$RUNTIME_SRC" build/runtime <<'PY'
import struct, sys
data = open(sys.argv[1], "rb").read()
shoff = struct.unpack_from("<Q", data, 0x28)[0]
shentsize, shnum = struct.unpack_from("<HH", data, 0x3A)
open(sys.argv[2], "wb").write(data[: shoff + shentsize * shnum])
PY
mksquashfs "$APPDIR" build/app.squashfs -root-owned -noappend -comp zstd -quiet
# Write to a temporary name and rename, so rebuilding works while the app is open.
cat build/runtime build/app.squashfs > build/Pinna-x86_64.AppImage
chmod +x build/Pinna-x86_64.AppImage
mv -f build/Pinna-x86_64.AppImage Pinna-x86_64.AppImage
ls -la Pinna-x86_64.AppImage
