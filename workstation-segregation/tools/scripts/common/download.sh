#!/bin/bash
# Download integrity. DL_STATUS is one of: verified, unverified, fetch-failed,
# malformed, mismatch. Only verified and unverified succeed; on any failure the
# artifact is deleted so nothing unverified can run.
DL_STATUS=""

dl_fetch() { _curl -o "$2" "$1"; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# checksum_lookup <sums file> <asset name>: "hash  name", "hash *name",
# "SHA256 (name) = hash" and single-hash files.
checksum_lookup() {
  awk -v n="$2" '
    NF==1 && length($1)==64 && $1 ~ /^[0-9a-fA-F]+$/ { print $1; exit }
    $2==n || $2=="*" n { print $1; exit }
    index($0, "(" n ") = ") > 0 && $1 ~ /^SHA-?256$/ { print $NF; exit }
  ' "$1"
}

# dl_verify <file> <asset name> <declared yes|no> <checksum url>...
# declared "no" means upstream publishes no checksum: unverified, reported.
# declared "yes" means a checksum is published: any failure to use it fails.
dl_verify() {
  local file="$1" name="$2" declared="$3" u expected="" actual i=0 fetched=0 tmp
  shift 3
  if [ "$declared" != yes ]; then DL_STATUS=unverified; return 0; fi
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/wst-sums.XXXXXX")"
  for u in "$@"; do
    i=$((i + 1))
    if dl_fetch "$u" "$tmp/sums.$i" 2>/dev/null; then
      fetched=1
      expected="$(checksum_lookup "$tmp/sums.$i" "$name")"
      [ -n "$expected" ] && break
    fi
    expected=""
  done
  if [ "$fetched" = 0 ]; then
    rm -rf "$tmp" "$file"; DL_STATUS=fetch-failed; return 1
  fi
  if [ -z "$expected" ]; then
    rm -rf "$tmp" "$file"; DL_STATUS=malformed; return 1
  fi
  rm -rf "$tmp"
  case "$expected" in
    *[!0-9A-Fa-f]*) rm -f "$file"; DL_STATUS=malformed; return 1 ;;
  esac
  [ "${#expected}" = 64 ] || { rm -f "$file"; DL_STATUS=malformed; return 1; }
  expected="$(printf '%s' "$expected" | tr 'A-F' 'a-f')"
  actual="$(sha256_of "$file")"
  if [ "$actual" != "$expected" ]; then
    rm -f "$file"; DL_STATUS=mismatch; return 1
  fi
  DL_STATUS=verified
}

# dl_verify_sha512 <file> <expected hex>: for manifests that publish SHA-512.
dl_verify_sha512() {
  local actual
  case "$2" in ''|*[!0-9A-Fa-f]*) rm -f "$1"; DL_STATUS=malformed; return 1 ;; esac
  if command -v sha512sum >/dev/null 2>&1; then actual="$(sha512sum "$1" | cut -d' ' -f1)"
  else actual="$(shasum -a 512 "$1" | cut -d' ' -f1)"; fi
  if [ "$actual" != "$(printf '%s' "$2" | tr 'A-F' 'a-f')" ]; then rm -f "$1"; DL_STATUS=mismatch; return 1; fi
  DL_STATUS=verified
}

# dl_verify_pkg_signature <pkg>: macOS package signature check.
dl_verify_pkg_signature() {
  if pkgutil --check-signature "$1" >/dev/null 2>&1; then
    DL_STATUS=verified
  else
    rm -f "$1"; DL_STATUS=mismatch; return 1
  fi
}

# dl_fail_message <status> <name>
dl_fail_message() {
  case "$1" in
    fetch-failed) echo "could not fetch the published checksum for $2" ;;
    malformed)    echo "published checksum for $2 is missing or malformed" ;;
    mismatch)     echo "checksum/signature mismatch for $2" ;;
    *)            echo "integrity check failed for $2 ($1)" ;;
  esac
}
