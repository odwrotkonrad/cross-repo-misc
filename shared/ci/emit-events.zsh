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
curl --fail-with-body --silent --show-error \
  --request POST \
  --form "token=${AUTOMATION_TRIGGER_TOKEN}" \
  --form "ref=main" \
  --form "variables[AUTOMATION_EVENT]=${events}" \
  "${CI_API_V4_URL}/projects/${AUTOMATION_PROJECT//\//%2F}/trigger/pipeline"
##[<] 🤖🤖
