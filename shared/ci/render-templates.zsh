#!/usr/bin/env zsh
##[>] 🤖🤖
set -euo pipefail

env_type=""
for arg in "$@"; do
  case $arg {
    (--env-type=*) env_type=${arg#--env-type=} ;;
    (*) print -u2 -- "unknown argument: $arg"; exit 2 ;;
  }
done

if [[ $env_type != dev && $env_type != ci ]] {
  print -u2 -- "--env-type is required, one of: dev|ci"
  exit 2
}

#[why] a pipeline exports every upstream ref as a job variable and holds no token for `glab variable get`:
#   seeding .env there is both unnecessary and a 401. the dev path asked for by a hook still runs as ci.
if [[ -n ${CI:-} ]] {
  env_type=ci
}

che=${CHE_BIN:-che}

if [[ $env_type == ci ]] {
  $che render-templates --profiles=ontoRepo
  exit 0
}

#[why] on a host the tracked lockfile is the single record of what this repo holds, so the dev render
#   takes its refs from there: a shell exporting a stale pin would otherwise render the docs at a
#   version this repo does not hold and the pre-commit hook would commit the downgrade. CI is the
#   other way round: the job variables are the current values, and the lockfile is what they update
typeset -r upstream_env=.repo/upstream.env
if [[ -f $upstream_env ]] {
  for line in ${(f)"$(<$upstream_env)"}; do
    if [[ $line == [A-Z]*=* ]] export $line
  done
}

CHE_ENV_UNSET=empty $che render-templates --profiles=envSeed

#[why] naming an undefined profile is a hard che error, and a repo rendering nothing from misc publishes no bootstrapCrossRepoCI: ask the spec before asking che
if { grep -qE '^bootstrapCrossRepoCI:' che.yml } {
  $che render-templates --profiles=bootstrapCrossRepoCI
}

$che render-templates --profiles=ontoRepo
##[<] 🤖🤖
