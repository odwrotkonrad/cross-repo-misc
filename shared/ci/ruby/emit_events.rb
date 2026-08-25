#!/usr/bin/env ruby
##[>] 🤖🤖
$LOAD_PATH.unshift(__dir__)
require 'json'
require 'yaml'
require 'artifact'
require 'declaration'

USAGE = 'usage: emit_events.rb <changed-file>...'.freeze

module EmitEvents
  DECLARATION_GLOBS = [/\.repo\/.*\.tpl\z/, %r{\.repo/deps-graph\.yml\z}, %r{\.repo/upstream\.yml\z}].freeze

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

  #[why] the upstream half versions in the tracked lockfile, not the yml, so a regen bumping
  #   .repo/upstream.env is what reports the versions this repo now holds
  VERSION_FILES = { CrossRepo::Declaration::UPSTREAM_ENV_FILE => %w[artifacts.consumed upstream],
                    CrossRepo::Declaration::DOWNSTREAM_FILE => %w[artifacts.produced downstream] }.freeze

  # One event per version file the commit moved, carrying that side's declared artifacts and versions.
  def self.version_events(changed, repo:, root:)
    VERSION_FILES.filter_map do |file, (type, key)|
      next unless changed.include?(file)

      declaration = CrossRepo::Declaration.load(repo, root)
      entries = declaration.public_send(key).map { |uri, artifact| artifact.to_definition.merge('uri' => uri, 'version' => artifact.version) }
      { 'type' => type, 'details' => { 'repo' => repo, key => entries } }
    end
  end

  # One artifact.released per artifact this repo publishes, only on a tag pipeline.
  def self.release_events(repo:, tag:, root:)
    return [] if tag.to_s.empty?

    declaration = CrossRepo::Declaration.load(repo, root)
    declaration.downstream.map do |uri, artifact|
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
