##[>] 🤖🤖
require "yaml"

# Compares the che profiles a repo publishes against the profiles its CI
# includes feed to the shared matrix templates.
module CheMatrix
  RESERVED_KEYS = %w[options env include].freeze
  EXEMPT_MARK = "matrix-exempt"
  TEMPLATE_MARK = "CheProfile"

  Diff = Struct.new(:uncovered, :unpublished, keyword_init: true) do
    def clean?
      uncovered.empty? && unpublished.empty?
    end
  end

  # published returns every profile name the given che spec bodies declare,
  # minus reserved keys and keys marked "# matrix-exempt".
  def self.published(spec_bodies)
    spec_bodies.flat_map { |body| published_in(body) }.uniq
  end

  # covered returns the profile names a CI config's shared-template includes
  # pass through inputs.profiles.
  def self.covered(ci_yaml)
    template_includes(ci_yaml)
      .flat_map { |entry| Array(entry.dig("inputs", "profiles")) }
      .map(&:to_s)
      .uniq
  end

  def self.diff(published, covered)
    Diff.new(uncovered: published - covered, unpublished: covered - published)
  end

  def self.published_in(spec_yaml)
    exempt = exempt_keys(spec_yaml)
    top_level_keys(spec_yaml).reject do |key|
      exempt.include?(key) || RESERVED_KEYS.include?(key)
    end
  end

  def self.top_level_keys(spec_yaml)
    doc = YAML.safe_load(spec_yaml, aliases: true)
    doc.is_a?(Hash) ? doc.keys.map(&:to_s) : []
  end

  def self.exempt_keys(spec_yaml)
    spec_yaml.lines.filter_map do |line|
      key, comment = line.split("#", 2)
      next unless comment.to_s.include?(EXEMPT_MARK)

      key.to_s[/\A([A-Za-z][\w\/.-]*):/, 1]
    end
  end

  def self.template_includes(ci_yaml)
    doc = YAML.safe_load(ci_yaml, aliases: true)
    entries = doc.is_a?(Hash) ? Array(doc["include"]) : []
    entries.select do |entry|
      entry.is_a?(Hash) && %w[local file].any? { |k| entry[k].to_s.include?(TEMPLATE_MARK) }
    end
  end
end
##[<] 🤖🤖
