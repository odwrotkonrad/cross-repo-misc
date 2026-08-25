##[>] 🤖🤖
#[why] CHE_BIN is read, never exported here: a repo may set it for another purpose entirely
#   (che-packages pins the linux binary its install matrix drives) and exporting it from an
#   included .mk overrides that repo's own unexport, handing the render a foreign binary
.PHONY: render-templates repo-ci-render-templates repo-render-env bootstrap-cross-repo-ci

#[what] render *.ontoRepo.tpl onto the repo, at the refs the group CI variables currently name
render-templates:
	@shared/ci/render-templates.zsh --env-type=dev

#[what] render *.ontoRepo.tpl onto the repo in CI, taking every upstream ref from the job environment
repo-ci-render-templates:
	@shared/ci/render-templates.zsh --env-type=ci

#[what] render .env.tpl to .env: upstream refs from the tracked .repo/upstream.env, CI variables via
#   glab, secrets via op
repo-render-env:
	@CHE_ENV_UNSET=empty $${CHE_BIN:-che} render-templates --profiles=envSeed

#[what] re-render the shared CI payload this repo consumes from cross-repo/misc
bootstrap-cross-repo-ci:
	@$${CHE_BIN:-che} render-templates --profiles=bootstrapCrossRepoCI
##[<] 🤖🤖
