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

che=${CHE_BIN:-che}

if [[ $env_type == ci ]] {
  $che render-templates --profiles=ontoRepo
  exit 0
}

CHE_ENV_UNSET=empty $che render-templates --profiles=envSeed

#[why] naming an undefined profile is a hard che error, and a repo rendering nothing from misc publishes no bootstrapCrossRepoCI: ask the spec before asking che
if { grep -qE '^bootstrapCrossRepoCI:' che.yml } {
  $che render-templates --profiles=bootstrapCrossRepoCI
}

$che render-templates --profiles=ontoRepo
##[<] 🤖🤖
