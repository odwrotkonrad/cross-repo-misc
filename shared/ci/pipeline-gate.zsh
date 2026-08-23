#!/usr/bin/env zsh
##[>] 🤖🤖
set -euo pipefail

#[why] rules:changes is an OR over its paths: it fires when any listed file changed, whatever else
#   the commit carries, so a real change riding beside a pin bump would skip validation and the tag.
#   The decision needs the whole changed set, which only a script can read.
#[why] artifacts-produced.yml alone records the version this repo just published: releasing on it
#   would loop. artifacts-consumed.yml is a dependency bump and must release like any other change.
typeset -r PRODUCED=.repo/artifacts-produced.yml
typeset -r ENV_FILE=${1:-pipeline-gate.env}

#[why] the safe default lands before anything that can fail: a crashing gate must leave the pipeline
#   running, never silence every job that reads this variable
print -- "DISABLE_PIPELINE=false" > $ENV_FILE

if [[ -n ${CI_COMMIT_TAG:-} ]]; then
  print -- "tag pipeline: always runs"
  exit 0
fi

git fetch --depth=2 origin $CI_COMMIT_SHA >/dev/null 2>&1 || true
typeset -a changed
changed=(${(f)"$(git diff-tree --no-commit-id --name-only -r $CI_COMMIT_SHA)"})

typeset disable=false
if (( ${#changed} > 0 )) && [[ ${changed[(r)^$PRODUCED]:-} == "" ]]; then
  disable=true
fi

print -- "DISABLE_PIPELINE=$disable" > $ENV_FILE
if [[ $disable == true ]]; then
  print -- "only $PRODUCED changed: downstream jobs skipped"
else
  print -- "changed: ${changed[*]:-none}"
fi
##[<] 🤖🤖
