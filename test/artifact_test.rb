##[>] 🤖🤖
$LOAD_PATH.unshift(File.expand_path('../shared/ci/ruby', __dir__))
require 'minitest/autorun'
require 'artifact'
require 'declaration'
require 'tmpdir'

class ArtifactTest < Minitest::Test
  IMAGE = {
    'type' => 'ociImage',
    'versionEnvVar' => 'OCI_IMAGES_CI_LINUX_REF'
  }.freeze
  IMAGE_URI = 'europe-docker.pkg.dev/konradodwrot/ci/ci-linux'.freeze
  REPO_URI = 'gitlab.com/konradodwrot/cross-repo/prose/assets'.freeze

  def repo_doc(_uri = REPO_URI)
    { 'type' => 'gitRepository', 'versionEnvVar' => 'PROSE_ASSETS_REF' }
  end

  def test_definition_round_trips
    artifact = CrossRepo::Artifact.parse(IMAGE_URI, IMAGE)
    assert_equal IMAGE, artifact.to_definition
    assert_equal IMAGE_URI, artifact.uri
  end

  def test_scope_prefixes_are_applied_at_use_not_stored
    artifact = CrossRepo::Artifact.parse(IMAGE_URI, IMAGE)
    assert_equal 'GRP_KO_VAR_OCI_IMAGES_CI_LINUX_REF', artifact.group_var
    assert_equal 'REPO_VAR_OCI_IMAGES_CI_LINUX_REF', artifact.project_var
    refute_includes artifact.to_definition.values.join, 'GRP_KO_VAR_'
  end

  def test_missing_field_and_unknown_type_are_named
    missing = assert_raises(ArgumentError) { CrossRepo::Artifact.parse(IMAGE_URI, IMAGE.reject { |k, _| k == 'versionEnvVar' }) }
    assert_match(/missing versionEnvVar/, missing.message)
    unknown = assert_raises(ArgumentError) { CrossRepo::Artifact.parse(IMAGE_URI, IMAGE.merge('type' => 'ciVariable')) }
    assert_match(/unknown type "ciVariable"/, unknown.message)
  end

  #[why] a published schema is one file fetched by url, never a clone: typing it gitRepository named
  #   the transport wrong, so file and archive describe what a consumer actually receives
  def test_a_fetched_file_or_archive_is_a_type_of_its_own
    %w[file archive].each do |type|
      artifact = CrossRepo::Artifact.parse(IMAGE_URI, IMAGE.merge('type' => type))
      assert_equal type, artifact.type
    end
  end

  def test_prefixed_version_env_var_is_rejected
    err = assert_raises(ArgumentError) { CrossRepo::Artifact.parse(IMAGE_URI, IMAGE.merge('versionEnvVar' => 'GRP_KO_VAR_X')) }
    refute_nil err
  end

  def test_versions_compare_per_artifact
    old = CrossRepo::Artifact.parse(IMAGE_URI, IMAGE, version: 'v0.0.9')
    new = old.with_version('v0.0.10')
    assert_equal(-1, old.compare_version(new))
    assert_equal 'v0.0.9', old.version
    assert_nil old.compare_version(CrossRepo::Artifact.parse(REPO_URI, repo_doc, version: 'v1.0.0'))
  end

  def test_declaration_resolves_versions_and_flags_gaps
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, '.repo'))
      write = ->(name, body) { File.write(File.join(dir, '.repo', name), body) }
      write['dependency-graph.yml',
            { 'dependsOn' => { IMAGE_URI => [{ 'uri' => REPO_URI, 'type' => 'gitRepository' }] } }.to_yaml]
      write['artifacts-produced.yml',
            { 'produces' => [IMAGE.merge('uri' => IMAGE_URI, 'version' => 'v0.0.121')] }.to_yaml]
      write['artifacts-consumed.yml',
            { 'consumes' => [{ 'uri' => REPO_URI, 'type' => 'gitRepository', 'version' => 'v0.9.4' }] }.to_yaml]

      declaration = CrossRepo::Declaration.load('cross-repo/infra/oci-images', dir)
      assert_equal 'v0.0.121', declaration.produces.fetch(IMAGE_URI).version
      assert_equal 'v0.9.4', declaration.consumes.fetch(REPO_URI).version
      assert_equal [], declaration.undeclared
      assert_equal [], declaration.dangling
    end
  end

  def test_declaration_names_an_undeclared_produced_artifact
    declaration = CrossRepo::Declaration.new(
      repo: 'x', graph: {}, produced: { 'produces' => [IMAGE.merge('uri' => IMAGE_URI, 'version' => 'v1')] }
    )
    assert_equal [IMAGE_URI], declaration.undeclared
  end

  def test_declaration_names_a_consumed_artifact_no_edge_covers
    declaration = CrossRepo::Declaration.new(
      repo: 'x', graph: {}, consumed: { 'consumes' => [{ 'uri' => REPO_URI, 'type' => 'gitRepository' }] }
    )
    assert_equal ["x consumes #{REPO_URI}, which no dependsOn edge names"], declaration.dangling
  end
end
##[<] 🤖🤖
