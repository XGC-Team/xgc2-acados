#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: publish_apt_repo.sh <repo-dir> <deb-dir> [suite] [component]

Creates a flat Debian apt repository layout with per-architecture Packages
indices under dists/<suite>/<component>/binary-<arch>/.

Environment:
  APT_REPO_SIGNING_KEY  Optional GPG key id used to create InRelease/Release.gpg.
USAGE
}

if [[ $# -lt 2 || $# -gt 4 ]]; then
  usage
  exit 2
fi

repo_dir="$(realpath "$1")"
deb_dir="$(realpath "$2")"
suite="${3:-focal}"
component="${4:-main}"

if ! compgen -G "${deb_dir}/*.deb" >/dev/null; then
  echo "No .deb files found in ${deb_dir}" >&2
  exit 1
fi

mkdir -p "${repo_dir}/pool/${component}/x/xgc2-acados"
cp -v "${deb_dir}"/*.deb "${repo_dir}/pool/${component}/x/xgc2-acados/"

mapfile -t archs < <(
  for deb in "${repo_dir}/pool/${component}/x/xgc2-acados/"*.deb; do
    dpkg-deb -f "${deb}" Architecture
  done | sort -u
)

for arch in "${archs[@]}"; do
  binary_dir="${repo_dir}/dists/${suite}/${component}/binary-${arch}"
  mkdir -p "${binary_dir}"
  (
    cd "${repo_dir}"
    dpkg-scanpackages --arch "${arch}" --multiversion "pool/${component}" /dev/null
  ) > "${binary_dir}/Packages"
  gzip -9fk "${binary_dir}/Packages"
done

release_dir="${repo_dir}/dists/${suite}"
if command -v apt-ftparchive >/dev/null 2>&1; then
  apt-ftparchive release "${release_dir}" > "${release_dir}/Release"
else
  {
    echo "Suite: ${suite}"
    echo "Codename: ${suite}"
    echo "Components: ${component}"
    echo "Architectures: ${archs[*]}"
    echo "Date: $(date -Ru)"
  } > "${release_dir}/Release"
fi

if [[ -n "${APT_REPO_SIGNING_KEY:-}" ]]; then
  gpg --batch --yes --default-key "${APT_REPO_SIGNING_KEY}" \
    --clearsign -o "${release_dir}/InRelease" "${release_dir}/Release"
  gpg --batch --yes --default-key "${APT_REPO_SIGNING_KEY}" \
    -abs -o "${release_dir}/Release.gpg" "${release_dir}/Release"
fi

echo "APT repository published at ${repo_dir}"
echo "Add with: deb [trusted=yes] file:${repo_dir} ${suite} ${component}"
