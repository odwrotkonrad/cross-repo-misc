##[>] 🤖🤖
require 'yaml'
require_relative 'artifact'

module CrossRepo
  # Declaration is one repo's .repo/ interface: its artifact definitions, what it publishes, consumes and builds from.
  class Declaration
    GRAPH_FILE = '.repo/deps-graph.yml'
    DOWNSTREAM_FILE = '.repo/downstream.yml'
    UPSTREAM_FILE = '.repo/upstream.yml'
    UPSTREAM_ENV_FILE = '.repo/upstream.env'

    attr_reader :repo, :artifacts, :depends_on, :downstream, :upstream

    # Reads a repo's declaration files from +root+, tolerating absent downstream/upstream files.
    def self.load(repo, root)
      path = ->(rel) { File.join(root, rel) }
      read = ->(rel) { YAML.safe_load(File.read(path[rel], encoding: 'UTF-8')) if File.file?(path[rel]) }
      new(repo: repo, graph: read[GRAPH_FILE] || {}, downstream: read[DOWNSTREAM_FILE] || {},
          upstream: read[UPSTREAM_FILE] || {}, upstream_env: read_env(path[UPSTREAM_ENV_FILE]))
    end

    # Parses a tracked KEY=VALUE lockfile, the sole source of the versions this repo holds.
    def self.read_env(path)
      return {} unless File.file?(path)

      File.read(path, encoding: 'UTF-8').each_line.with_object({}) do |line, env|
        line = line.strip
        next if line.empty? || line.start_with?('#')

        key, value = line.split('=', 2)
        env[key] = value.to_s
      end
    end

    def initialize(repo:, graph:, downstream: {}, upstream: {}, upstream_env: {})
      @repo = repo
      @depends_on = graph['dependsOn'] || {}
      @downstream = versioned(downstream, 'downstream')
      @upstream = versioned(upstream, 'upstream', env: upstream_env)
      @artifacts = @downstream
    end

    # Artifacts this repo publishes that declare no depends_on key, the migration work queue.
    def undeclared
      downstream.keys.reject { |uri| depends_on.key?(uri) }
    end

    # Upstream artifacts no dependsOn edge accounts for: an upstream nothing in this repo builds from.
    def dangling
      covered = depends_on.values.flatten.map { |u| u.is_a?(Hash) ? u.fetch('uri') : u }
      (upstream.keys - covered).map { |uri| "#{repo} consumes #{uri}, which no dependsOn edge names" }
    end

    private

    def versioned(doc, key, env: nil)
      (doc[key] || []).to_h do |entry|
        uri = entry.fetch('uri')
        [uri, Artifact.parse(uri, entry, version: version_of(entry, env), downstream: key == 'downstream')]
      end
    end

    def version_of(entry, env)
      return entry['version'] if env.nil?

      env[entry['versionEnvVar']]
    end
  end
end
##[<] 🤖🤖
