#!/usr/bin/env bash
# Run unmodified foreign binaries on one FHS mode's image (docker/<mode>.Dockerfile).
#
# The mode was activated when its image was built (activate.sh). This script
# never changes a system path: it writes only /work (scratch) and /cache (the
# machine-scoped download volume), so rerunning it in the same container
# measures the same system every time.
#
# Every check prints one "RESULT <mode> <check> PASS|FAIL <detail>" line.
set -u
MODE=${MODE:?set MODE}
C=/cache
mkdir -p $C/dl /work
export UV_CACHE_DIR=$C/uv UV_PYTHON_INSTALL_DIR=$C/uv-python
export RUSTUP_HOME=$C/rustup CARGO_HOME=$C/cargo
export PLAYWRIGHT_BROWSERS_PATH=$C/ms-playwright
export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt   # for the native curl/uv only
# No NIX_LD / NIX_LD_LIBRARY_PATH: like a systemd service, the corpus relies on
# nix-ld's compiled-in defaults.

result() { printf 'RESULT %-8s %-22s %s %s\n' "$MODE" "$1" "$2" "${3:-}"; }
check() { # name, command...
  local name=$1; shift
  local out
  if out=$(timeout 600 "$@" 2>&1); then
    result "$name" PASS "$(echo "$out" | tail -n1 | cut -c1-90)"
  else
    result "$name" FAIL "$(echo "$out" | grep -v '^\s*$' | tail -n1 | cut -c1-120)"
  fi
}
fetch() { [ -s "$C/dl/$2" ] || curl -fsSL "$1" -o "$C/dl/$2"; }

# Layer facts: are the module defaults merged into a custom list?
L=/run/current-system/sw/share/nix-ld/lib
if [ -d "$L" ]; then
  for so in libz.so.1 libsystemd.so.0 libstdc++.so.6 libcrypt.so.1 libxml2.so.2 libgtk-3.so.0; do
    [ -e "$L/$so" ] && result "has:$so" PASS || result "has:$so" FAIL "absent from layer"
  done
fi

# --- Node.js official tarball (dynamic: glibc, libstdc++, libgcc_s) ---
fetch https://nodejs.org/dist/v22.12.0/node-v22.12.0-linux-x64.tar.xz node.tar.xz
rm -rf /work/node && mkdir -p /work/node && tar -xJf $C/dl/node.tar.xz -C /work/node --strip-components=1
NODE=/work/node/bin/node
check node            $NODE -e 'console.log(process.version, require("zlib").gzipSync("x").length)'

# --- python-build-standalone via uv (what uv/pip users actually get) ---
uv python install 3.12 3.11 >/dev/null 2>&1
PY=$(uv python find 3.12 2>/dev/null); PY11=$(uv python find 3.11 2>/dev/null)
check python          "$PY" -c 'import sys; print(sys.version.split()[0])'
check py:ssl-https    "$PY" -c 'import urllib.request as u; print(u.urlopen("https://pypi.org/simple/").status)'
check py:zoneinfo     "$PY" -c 'import zoneinfo; print(zoneinfo.ZoneInfo("Europe/Moscow"))'
check py:find_library "$PY" -c 'import ctypes.util as c; r=c.find_library("z"); print(r); assert r'
check ldconfig-p      sh -c '/sbin/ldconfig -p | grep -m1 "libz.so.1"'
check py:dlopen-xml2  "$PY" -c 'import ctypes; ctypes.CDLL("libxml2.so.2"); print("ok")'
check py311:crypt     "$PY11" -W ignore -c 'import crypt; print("ok")'
rm -rf /work/venv
if "$PY" -m venv /work/venv >/dev/null 2>&1; then
  VPY=/work/venv/bin/python
  uv pip install --python $VPY -q numpy >/dev/null 2>&1
  check wheel:numpy   $VPY -c 'import numpy; print(numpy.__version__, numpy.ones(3).sum())'
else
  result wheel:numpy FAIL "venv could not be created"
fi

# --- shebangs and hard-coded tool paths (envfs resolves them on PATH) ---
printf '#!/usr/bin/python3\nprint("shebang ok")\n' > /work/s.py && chmod +x /work/s.py
check shebang:python3 env PATH="$(dirname "$PY"):$PATH" /work/s.py
check path:/bin/true  /bin/true

# --- rustup (prebuilt toolchain) + cargo build/run ---
fetch https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init rustup-init
chmod +x $C/dl/rustup-init
check rustup-init     $C/dl/rustup-init -y --profile minimal --default-toolchain stable --no-modify-path
if [ -x $CARGO_HOME/bin/cargo ]; then
  rm -rf /work/hello && $CARGO_HOME/bin/cargo new -q /work/hello >/dev/null 2>&1
  check cargo:run     $CARGO_HOME/bin/cargo run -q --manifest-path /work/hello/Cargo.toml
fi

# --- AppImage (no FUSE in a container: extract-and-run) ---
fetch https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage appimagetool
chmod +x $C/dl/appimagetool
check appimage        env APPIMAGE_EXTRACT_AND_RUN=1 $C/dl/appimagetool --version

# --- Playwright Chromium, headless (needs the desktop preset) ---
if [ -x /work/venv/bin/python ]; then
  uv pip install --python /work/venv/bin/python -q playwright >/dev/null 2>&1
  /work/venv/bin/python -m playwright install chromium >/dev/null 2>&1
  check playwright      /work/venv/bin/python -c '
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(); pg.set_content("<title>fyx</title>")
    print(pg.title()); b.close()'
fi

# --- known gap: a binary whose loader is the Nix store glibc ---
cp $NODE /work/node-storeld
patchelf --set-interpreter "$(patchelf --print-interpreter "$(readlink -f "$(command -v patchelf)")")" /work/node-storeld
check gap:store-loader /work/node-storeld -e 'console.log("ok")'
