##[>] 🤖🤖
SHELL := zsh

WRAPPERS := repo-prepare-dev-env
COMMANDS := render-templates repo-render-env repo-ci-prepare-hooks repo-ci-precommit-all semver-next tag-mint test

.PHONY: $(WRAPPERS) $(COMMANDS)

##[>] Dev Environment [genai-include]
#[what] make a fresh clone a working checkout: generated docs, git hooks
repo-prepare-dev-env: repo-render-env render-templates repo-ci-prepare-hooks
##[<] Dev Environment

##[>] Docs [genai-include]
#[what] render *.ontoRepo.tpl onto the repo (makefile.agents.md, repo-structure.md, CLAUDE.md, AGENTS.md, README.md)
render-templates:
	@che render-templates --profiles=ontoRepo

#[what] render .env.tpl to .env: upstream refs and CI variables via glab, secrets via op
repo-render-env:
	@CHE_ENV_UNSET=empty che render-templates --profiles=envSeed
##[<] Docs

##[>] Release [genai-include]
#[what] print the next semver tag inferred from the last tag..HEAD diff (override: `semver: major|minor|patch` commit token)
semver-next: render-templates
	@ci/semver-bump.zsh

#[what] mint and push the next semver tag (CI: authed via TAG_TOKEN), running this repo's own ci/ scripts from source
tag-mint: render-templates
	@ci/tag-mint.zsh
##[<] Release

##[>] Test [genai-include]
#[what] run the minitest suite over lib/
test:
	@ruby test/che_matrix_test.rb
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
