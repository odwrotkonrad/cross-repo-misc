#!/usr/bin/env zsh
##[>] 🤖🤖
set -euo pipefail

head_tag=$(git tag --points-at HEAD | grep -E '^v[0-9]' || true)
if [[ -n $head_tag ]] {
  print "HEAD already tagged $head_tag, nothing to mint"
  exit 0
}

next=$(${0:a:h}/semver-bump.zsh)
git tag $next

#[why] one masked TAG_TOKEN per tagging project, terraform-managed: fail loudly when CI carries none rather than pushing unauthenticated
if [[ -n ${CI:-} ]] {
  git push https://tag-minter:${TAG_TOKEN:?}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git $next
} else {
  git push origin $next
}
print "minted $next"
##[<] 🤖🤖
