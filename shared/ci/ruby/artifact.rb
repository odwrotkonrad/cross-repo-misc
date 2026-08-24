##[>] 🤖🤖
module CrossRepo
  #[why] constants inside a Struct.new block bind to the block's scope, never to the struct, so
  #   every caller reading them off Artifact would raise; they live on the module instead
  #[why] file and archive describe what a consumer fetches, not where it is hosted: the schemas are
  #   single files published to a generic package registry and read by url, never cloned, so calling
  #   them gitRepository named the wrong thing
  #[why] ci-variable and lockfile break the camelCase of the rest: both were declared live before
  #   anything validated a type, and renaming one rewrites every repo's .repo/ files
  ARTIFACT_TYPES = %w[gitRepository ociImage goModule archive file genericPackage ci-variable lockfile].freeze
  ARTIFACT_FIELDS = { 'type' => :type, 'uri' => :uri, 'versionEnvVar' => :version_env_var }.freeze
  GROUP_PREFIX = 'GRP_KO_VAR_'
  PROJECT_PREFIX = 'REPO_VAR_'
  #[why] an identity variable states its protection in the prefix, so a stored bare name must be
  #   rejected for carrying any of them, not just the two unprotected spellings
  SCOPE_PREFIXES = [GROUP_PREFIX, PROJECT_PREFIX, 'GRP_KO_PROTECTED_VAR_', 'GRP_KO_UNPROTECTED_VAR_',
                    'REPO_PROTECTED_VAR_', 'REPO_UNPROTECTED_VAR_'].freeze
  SEMVER = /\A(?:[\w-]+\/)?v(\d+)\.(\d+)\.(\d+)\z/

  # Artifact is one versioned addressable thing: the graph vertex, identified by its uri.
  Artifact = Struct.new(:type, :uri, :version, :version_env_var, keyword_init: true) do
    #[why] versionEnvVar is producer-side: the producer names the variable carrying its version, a
    #   consumer only records the version it holds. Requiring it of both rejects every consumes entry
    def self.parse(uri, doc, version: nil, produced: true)
      raise ArgumentError, "artifact #{uri}: missing type" if doc['type'].to_s.empty?
      raise ArgumentError, "artifact #{uri}: unknown type #{doc['type'].inspect}" unless ARTIFACT_TYPES.include?(doc['type'])
      raise ArgumentError, "artifact #{uri}: missing versionEnvVar" if produced && doc['versionEnvVar'].to_s.empty?

      artifact = new(type: doc['type'], uri: uri, version: version, version_env_var: doc['versionEnvVar'])
      artifact.validate!
      artifact
    end

    # Raises when a present version variable is not a bare, unscoped name.
    def validate!
      return if version_env_var.to_s.empty?
      raise ArgumentError, "artifact #{uri}: versionEnvVar #{version_env_var.inspect} is not a bare variable name" unless version_env_var.match?(/\A[A-Z][A-Z0-9_]*\z/)
      return unless version_env_var.start_with?(*SCOPE_PREFIXES)

      raise ArgumentError, "artifact #{uri}: versionEnvVar #{version_env_var.inspect} carries a scope prefix, store the bare name"
    end

    # The uri-keyed mapping written back into a graph or declaration file.
    def to_definition
      ARTIFACT_FIELDS.reject { |k, _| k == 'uri' }.to_h { |key, field| [key, public_send(field)] }
    end

    def group_var
      GROUP_PREFIX + version_env_var
    end

    def project_var
      PROJECT_PREFIX + version_env_var
    end

    def with_version(other)
      self.class.new(to_h.merge(version: other))
    end

    def same_definition?(other)
      to_definition == other.to_definition
    end

    # Orders two versions of one artifact, nil when either is unparseable or they are not comparable.
    def compare_version(other)
      return nil unless uri == other.uri

      mine = self.class.parse_version(version)
      theirs = self.class.parse_version(other.version)
      return nil if mine.nil? || theirs.nil?

      mine <=> theirs
    end

    # Every type versions by a semver tag today, so one parse serves them all.
    def self.parse_version(value)
      match = CrossRepo::SEMVER.match(value.to_s)
      match && match.captures.map(&:to_i)
    end
  end
end
##[<] 🤖🤖
