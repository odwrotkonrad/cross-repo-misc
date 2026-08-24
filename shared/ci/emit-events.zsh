#!/usr/bin/env zsh
##[>] 🤖🤖
set -euo pipefail

#[why] the trigger API takes the event array directly, so one job builds it and posts it: a separate
#   trigger: job cannot read this job's artifact into a variable, and would double the repo's terminal jobs
root=${0:a:h:h:h}
cd $root

changed=()
if [[ -n ${CI_COMMIT_TAG:-} ]]; then
  changed=()
else
  git fetch --depth=2 origin $CI_COMMIT_SHA >/dev/null 2>&1 || true
  changed=(${(f)"$(git diff-tree --no-commit-id --name-only -r $CI_COMMIT_SHA)"})
fi

events=$(ruby shared/ci/ruby/emit_events.rb $changed)
if [[ $events == '[]' ]]; then
  print -- 'no events owed by this pipeline'
  exit 0
fi

print -- "posting $(print -- $events | ruby -rjson -e 'puts JSON.parse($stdin.read).map { |e| e["type"] }.join(" ")')"

#[why] an empty credential reaches the API as an anonymous call, which answers 404 rather than 401:
#   a release whose announcement never landed then reads as a missing project. Fail on the cause
if [[ -z ${EMIT_EVENTS_TOKEN:-} ]] {
  print -u2 -- 'EMIT_EVENTS_TOKEN is empty: is GRP_KO_PROTECTED_VAR_BOT_EMIT_EVENTS_TOKEN set, and is this a protected ref?'
  exit 1
}

#[why] a project access token on cross-repo/automation, so POST /pipeline with a PRIVATE-TOKEN
#   header. The /trigger/pipeline form endpoint takes only a pipeline trigger token, a second
#   identity per emitting repo with nothing to tell the callers apart
#[why] not the maintainer token automation clones and pushes with: emitting an event is a write to
#   one project's pipelines, and this credential reaches that project and nothing else
curl --fail-with-body --silent --show-error \
  --request POST \
  --header "PRIVATE-TOKEN: ${EMIT_EVENTS_TOKEN}" \
  --form "ref=main" \
  --form "variables[][key]=AUTOMATION_EVENT" \
  --form "variables[][value]=${events}" \
  "${CI_API_V4_URL}/projects/${AUTOMATION_PROJECT//\//%2F}/pipeline"
##[<] 🤖🤖
