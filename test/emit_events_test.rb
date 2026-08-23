##[>] 🤖🤖
$LOAD_PATH.unshift(File.expand_path('../shared/ci/ruby', __dir__))
require 'minitest/autorun'
require 'emit_events'
require 'tmpdir'
require 'yaml'

class EmitEventsTest < Minitest::Test
  ASSETS = 'gitlab.com/konradodwrot/cross-repo/prose/assets'.freeze
  NOTES = 'gitlab.com/konradodwrot/notes'.freeze

  def repo_root
    dir = Dir.mktmpdir
    Dir.mkdir(File.join(dir, '.repo'))
    write = ->(name, doc) { File.write(File.join(dir, '.repo', name), doc.to_yaml) }
    write['dependency-graph.yml', {
      'dependsOn' => { NOTES => [], 'ciEnv' => [{ 'uri' => ASSETS, 'type' => 'gitRepository' }] }
    }]
    write['artifacts-produced.yml', { 'produces' => [{ 'uri' => NOTES, 'type' => 'gitRepository',
                                                       'versionEnvVar' => 'NOTES_REF', 'version' => 'v0.0.15' }] }]
    write['artifacts-consumed.yml', { 'consumes' => [{ 'uri' => ASSETS, 'type' => 'gitRepository',
                                                       'version' => 'v0.0.60' }] }]
    dir
  end

  def types(changed, tag: nil)
    Dir.mktmpdir do |_|
      root = repo_root
      EmitEvents.call(changed, repo: 'notes', tag: tag, root: root).map { |e| e['type'] }
    end
  end

  def test_a_template_edit_redeclares_structure
    assert_equal ['artifacts.declared'], types(['.repo/artifacts-consumed.yml.tpl'])
    assert_equal ['artifacts.declared'], types(['.repo/dependency-graph.yml'])
  end

  def test_each_version_file_emits_its_own_event
    assert_equal ['artifacts.consumed'], types(['.repo/artifacts-consumed.yml'])
    assert_equal ['artifacts.produced'], types(['.repo/artifacts-produced.yml'])
  end

  def test_one_commit_touching_both_emits_both_in_one_send
    assert_equal %w[artifacts.declared artifacts.consumed],
                 types(['.repo/artifacts-consumed.yml.tpl', '.repo/artifacts-consumed.yml'])
  end

  def test_an_unrelated_commit_owes_nothing
    assert_empty types(['README.md', 'lib/thing.rb'])
  end

  def test_a_tag_releases_every_produced_artifact
    events = types([], tag: 'v0.0.16')
    assert_equal ['artifact.released'], events
  end

  def test_a_release_names_the_artifact_by_its_full_definition
    root = repo_root
    details = EmitEvents.call([], repo: 'notes', tag: 'v0.0.16', root: root).first['details']
    assert_equal NOTES, details['artifact']['uri']
    assert_equal 'NOTES_REF', details['artifact']['versionEnvVar']
    assert_equal 'v0.0.16', details['version']
  end

  def test_a_consumed_event_carries_the_versions_it_recorded
    root = repo_root
    details = EmitEvents.call(['.repo/artifacts-consumed.yml'], repo: 'notes', root: root).first['details']
    assert_equal [{ 'uri' => ASSETS, 'type' => 'gitRepository', 'version' => 'v0.0.60' }], details['consumes']
  end
end
##[<] 🤖🤖
