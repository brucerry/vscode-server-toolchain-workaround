#!/bin/bash

# Update the glibc and libstdc++ of VSCode server
# Read README.md for detail

set -exuo pipefail

script_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Disable VSCode glibc/libstdc++ version checking
if [[ ! -e "/tmp/vscode-skip-server-requirements-check" ]]; then
  touch "/tmp/vscode-skip-server-requirements-check"
fi

files="$@"

if [[ -z "${files:-}" ]]; then
  files=($HOME/.vscode-server/bin/*/node )
fi

echo "${files[@]}"
patchelf="$script_dir/patchelf-0.9/bin/patchelf"
interpreter="$script_dir/glibc-2.30/lib/ld-linux-x86-64.so.2"
lib_dir="$script_dir/glibc-2.30/lib:$script_dir/gcc-10.3.0/lib64"

for exe in "${files[@]}"; do
  ${patchelf} --set-interpreter ${interpreter} "$exe"
  ${patchelf} --set-rpath "${lib_dir}" "$exe" --force-rpath
done

# Patch native modules loaded after Node starts, including node-pty and Copilot.
mkdir -p /swwork/hbcc/commontools/glibc/2.30
ln -sfn "$script_dir/glibc-2.30/lib" /swwork/hbcc/commontools/glibc/2.30/lib
ln -sfn libutil-2.30.so "$script_dir/glibc-2.30/lib/libutil.so.1"
for module in compat db dns files hesiod; do
  ln -sfn "libnss_${module}-2.30.so" "$script_dir/glibc-2.30/lib/libnss_${module}.so.2"
done
ln -sfn libresolv-2.30.so "$script_dir/glibc-2.30/lib/libresolv.so.2"
find "$HOME/.vscode-server/bin" -type f -name "*.node" -exec "$patchelf" --set-rpath "$lib_dir" {} --force-rpath \; 2>/dev/null || true

echo "Succeeded to update glibc and libstdc++ of vscode server"
