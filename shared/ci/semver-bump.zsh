#!/usr/bin/env zsh
##[>] 🤖🤖
set -euo pipefail

#[why] resolve the latest tag from the remote, never the local clone: a stale or mid-delete local tag would otherwise decide the release
last=$(git ls-remote --tags origin 'v[0-9]*' 2>/dev/null \
  | awk -F/ '{print $NF}' | grep -v '\^{}' | sort -V | tail -1 || true)
if [[ -z $last ]] {
  print v0.0.1
  exit 0
}

#[why] inference always yields patch: a repo grows by adding files, so adds must not mint a minor. major/minor come only from an explicit `semver:` commit token
bump=patch

#[why] the remote tag decides the version but may not exist locally (CI clones shallow, a host clone lags): scan from it only when it resolves, else from the newest local tag, else the whole history
range=HEAD
for ref in $last $(git tag --list 'v[0-9]*' --sort=-v:refname | head -1); do
  if { git rev-parse --verify --quiet $ref >/dev/null } { range=$ref..HEAD; break }
done

tokens=(${(f)"$(git log $range --format=%B | sed -nE 's/.*semver: (major|minor|patch).*/\1/p')"})
if (( ${#tokens} )) {
  if (( ${tokens[(I)minor]} )) bump=minor
  if (( ${tokens[(I)major]} )) bump=major
}

parts=(${(s:.:)${last#v}})
case $bump {
  (major) print v$((parts[1] + 1)).0.0 ;;
  (minor) print v${parts[1]}.$((parts[2] + 1)).0 ;;
  (patch) print v${parts[1]}.${parts[2]}.$((parts[3] + 1)) ;;
}
##[<] 🤖🤖
