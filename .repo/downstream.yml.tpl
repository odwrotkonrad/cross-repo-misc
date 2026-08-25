##[>] 🤖
downstream:
  - uri: gitlab.com/konradodwrot/cross-repo/misc
    type: gitRepository
    versionEnvVar: MISC_REF
    version: {{ env.Getenv "MISC_REF" }}
##[<] 🤖
