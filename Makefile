##[>] 🤖🤖
SHELL := zsh

WRAPPERS := repo-prepare-dev-env
COMMANDS := render-templates repo-ci-render-templates repo-render-env repo-ci-prepare-hooks repo-ci-precommit-all semver-next tag-mint test

.PHONY: $(WRAPPERS) $(COMMANDS)

##[>] Dev Environment [genai-include]
#[what] make a fresh clone a working checkout: generated docs, git hooks
repo-prepare-dev-env: repo-render-env render-templates repo-ci-prepare-hooks
##[<] Dev Environment

##[>] Docs [genai-include]
#[why] misc renders nothing from misc: it runs its own shared/ci/ payload from source, so no bootstrap rule and no gitignored tree
#[what] render *.ontoRepo.tpl onto the repo (makefile.agents.md, repo-structure.md, CLAUDE.md, AGENTS.md, README.md)
render-templates:
	@shared/ci/render-templates.zsh --env-type=dev

#[what] render *.ontoRepo.tpl onto the repo in CI, taking every upstream ref from the job environment
repo-ci-render-templates:
	@shared/ci/render-templates.zsh --env-type=ci

#[what] render .che/repo-git-untracked/templates/env.tpl to .env: upstream refs and CI variables via glab, secrets via op
repo-render-env:
	@CHE_ENV_UNSET=empty che render-templates --profiles=envSeed
##[<] Docs

##[>] Release [genai-include]
#[what] print the next semver tag inferred from the last tag..HEAD diff (override: `semver: major|minor|patch` commit token)
semver-next: render-templates
	@shared/ci/semver-bump.zsh

#[what] mint and push the next semver tag (CI: authed via TAG_TOKEN), running this repo's own shared/ci/ scripts from source
tag-mint: render-templates
	@shared/ci/tag-mint.zsh
##[<] Release

##[>] Test [genai-include]
#[what] run the minitest suites: lib/ profile-coverage rules, shared/ci/templates/ job shapes
test:
	@for suite in test/*_test.rb; do ruby "$$suite" || exit 1; done
##[<] Test

##[>] CI [genai-include]
#[what] install lefthook git hooks
repo-ci-prepare-hooks:
	@lefthook install --force

#[what] run pre-commit hooks over all files (not just staged)
repo-ci-precommit-all: repo-ci-prepare-hooks
	@lefthook run pre-commit --all-files --force
##[<] CI
##[<] 🤖🤖
