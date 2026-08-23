#!/usr/bin/env ruby
##[>] 🤖🤖
$LOAD_PATH.unshift(__dir__)
require 'json'
require 'yaml'
require 'artifact'
require 'declaration'

USAGE = 'usage: emit_events.rb <changed-file>...'.freeze

module EmitEvents
  DECLARATION_GLOBS = [/\.repo\/.*\.tpl\z/, %r{\.repo/dependency-graph\.yml\z}].freeze

  #[why] a repo whose pipeline computes an event no declaration file can express (iac reads its
  #   terraform plan for ci-var.changed) writes it here, so one terminal job still sends every event
  EXTRA_EVENTS_FILE = 'extra-events.json'.freeze

  # Decides which events a pipeline owes from its changed paths and the tag it was built on.
  def self.call(changed, repo:, tag: nil, root: '.')
    events = []
    events << { 'type' => 'artifacts.declared', 'details' => { 'repo' => repo } } if changed.any? { |f| DECLARATION_GLOBS.any? { |g| f.match?(g) } }
    events.concat(version_events(changed, repo: repo, root: root))
    events.concat(release_events(repo: repo, tag: tag, root: root))
    events.concat(extra_events(root: root))
    events
  end

  # Events this pipeline computed for itself, read from the file its earlier jobs wrote.
  def self.extra_events(root:)
    path = File.join(root, EXTRA_EVENTS_FILE)
    return [] unless File.file?(path)

    doc = JSON.parse(File.read(path, encoding: 'UTF-8'))
    doc.is_a?(Array) ? doc : [doc]
  end

  # One event per rendered version file the commit moved, carrying that file's declared versions.
  def self.version_events(changed, repo:, root:)
    { CrossRepo::Declaration::CONSUMED_FILE => %w[artifacts.consumed consumes],
      CrossRepo::Declaration::PRODUCED_FILE => %w[artifacts.produced produces] }.filter_map do |file, (type, key)|
      next unless changed.include?(file)

      doc = YAML.safe_load(File.read(File.join(root, file), encoding: 'UTF-8')) || {}
      { 'type' => type, 'details' => { 'repo' => repo, key => doc[key] || [] } }
    end
  end

  # One artifact.released per artifact this repo publishes, only on a tag pipeline.
  def self.release_events(repo:, tag:, root:)
    return [] if tag.to_s.empty?

    declaration = CrossRepo::Declaration.load(repo, root)
    declaration.produces.map do |uri, artifact|
      { 'type' => 'artifact.released',
        'details' => { 'artifact' => artifact.to_definition.merge('uri' => uri), 'version' => tag, 'prev' => ENV['PREVIOUS_TAG'] } }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  repo = ENV.fetch('CI_PROJECT_PATH') { abort 'CI_PROJECT_PATH is unset' }.delete_prefix('konradodwrot/')
  source = { 'project' => ENV['CI_PROJECT_PATH'], 'pipeline' => ENV['CI_PIPELINE_ID'],
             'ref' => ENV['CI_COMMIT_REF_NAME'], 'sha' => ENV['CI_COMMIT_SHA'] }
  events = EmitEvents.call(ARGV, repo: repo, tag: ENV['CI_COMMIT_TAG']).map { |e| e.merge('source' => source) }
  warn(events.empty? ? 'no events owed by this pipeline' : "emitting: #{events.map { |e| e['type'] }.join(' ')}")
  puts JSON.generate(events)
end
##[<] 🤖🤖
