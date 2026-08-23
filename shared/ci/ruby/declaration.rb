##[>] 🤖🤖
require 'yaml'
require_relative 'artifact'

module CrossRepo
  # Declaration is one repo's .repo/ interface: its artifact definitions, what it produces, consumes and builds from.
  class Declaration
    GRAPH_FILE = '.repo/dependency-graph.yml'
    PRODUCED_FILE = '.repo/artifacts-produced.yml'
    CONSUMED_FILE = '.repo/artifacts-consumed.yml'

    attr_reader :repo, :artifacts, :depends_on, :produces, :consumes

    # Reads a repo's three rendered files from +root+, tolerating absent produced/consumed files.
    def self.load(repo, root)
      read = ->(rel) { YAML.safe_load(File.read(File.join(root, rel), encoding: 'UTF-8')) if File.file?(File.join(root, rel)) }
      new(repo: repo, graph: read[GRAPH_FILE] || {}, produced: read[PRODUCED_FILE] || {}, consumed: read[CONSUMED_FILE] || {})
    end

    def initialize(repo:, graph:, produced: {}, consumed: {})
      @repo = repo
      @depends_on = graph['dependsOn'] || {}
      @produces = versioned(produced, 'produces')
      @consumes = versioned(consumed, 'consumes')
      @artifacts = @produces
    end

    # Artifacts this repo produces that declare no depends_on key, the migration work queue.
    def undeclared
      produces.keys.reject { |uri| depends_on.key?(uri) }
    end

    # Consumed artifacts no dependsOn edge accounts for: an upstream nothing in this repo builds from.
    def dangling
      covered = depends_on.values.flatten.map { |u| u.is_a?(Hash) ? u.fetch('uri') : u }
      (consumes.keys - covered).map { |uri| "#{repo} consumes #{uri}, which no dependsOn edge names" }
    end

    private

    def versioned(doc, key)
      (doc[key] || []).to_h do |entry|
        uri = entry.fetch('uri')
        [uri, Artifact.new(type: entry['type'], uri: uri, version: entry['version'],
                           version_env_var: entry['versionEnvVar'])]
      end
    end
  end
end
##[<] 🤖🤖
