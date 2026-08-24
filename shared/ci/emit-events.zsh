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
if [[ -z ${AUTOMATION_GITLAB_TOKEN:-} ]] {
  print -u2 -- 'AUTOMATION_GITLAB_TOKEN is empty: is GRP_KO_PROTECTED_VAR_BOT_AUTOMATION_GITLAB_TOKEN set, and is this a protected ref?'
  exit 1
}

#[why] the group access token authenticates as a user, so it drives POST /pipeline with a
#   PRIVATE-TOKEN header. The /trigger/pipeline form endpoint accepts only a per-project trigger
#   token, which would be a second identity per emitting repo with nothing to tell the callers apart
curl --fail-with-body --silent --show-error \
  --request POST \
  --header "PRIVATE-TOKEN: ${AUTOMATION_GITLAB_TOKEN}" \
  --form "ref=main" \
  --form "variables[][key]=AUTOMATION_EVENT" \
  --form "variables[][value]=${events}" \
  "${CI_API_V4_URL}/projects/${AUTOMATION_PROJECT//\//%2F}/pipeline"
##[<] 🤖🤖
