##[>] 🤖🤖
require 'json'

module CrossRepo
  # Event is one parsed AUTOMATION_EVENT entry: a type, where it came from, the sender's details.
  Event = Struct.new(:type, :source, :details, keyword_init: true) do
    SOURCE_FIELDS = %w[project pipeline ref sha].freeze

    # Parses the JSON array every emit-events job sends, validating each entry against +catalogue+.
    def self.parse_all(json, catalogue:)
      doc = JSON.parse(json)
      entries = doc.is_a?(Array) ? doc : [doc]
      raise ArgumentError, 'event array is empty' if entries.empty?

      entries.map { |entry| parse_entry(entry, catalogue: catalogue) }
    end

    # Parses one event object, raising on an unknown type or a missing field.
    def self.parse_entry(doc, catalogue:)
      type = doc.fetch('type') { raise ArgumentError, 'event has no type' }
      type = catalogue.resolve(type)
      source = doc.fetch('source') { raise ArgumentError, 'event has no source' }
      details = doc.fetch('details') { raise ArgumentError, 'event has no details' }
      missing = (SOURCE_FIELDS - source.keys).map { |k| "source.#{k}" } +
                (catalogue.required_details(type) - details.keys).map { |k| "details.#{k}" }
      raise ArgumentError, "#{type} event missing #{missing.join(', ')}" unless missing.empty?

      new(type: type, source: source, details: details)
    end

    def tag
      source['ref']
    end

    def repo
      details['repo'] || source['project']
    end
  end
end
##[<] 🤖🤖
