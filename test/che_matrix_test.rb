##[>] 🤖🤖
require "minitest/autorun"
require_relative "../lib/che_matrix"

FIXTURES = File.expand_path("fixture", __dir__)

def fixture(name)
  File.read(File.join(FIXTURES, name))
end

class PublishedTest < Minitest::Test
  def test_lists_profile_keys
    assert_equal %w[base/packages base virt/linux], CheMatrix.published([fixture("che.yml")])
  end

  def test_drops_reserved_keys
    refute_includes CheMatrix.published([fixture("che.yml")]), "env"
    refute_includes CheMatrix.published([fixture("che.yml")]), "options"
  end

  def test_drops_exempt_keys
    refute_includes CheMatrix.published([fixture("che.yml")]), "ontoRepo"
  end

  def test_merges_every_spec_file
    published = CheMatrix.published([fixture("che.yml"), fixture("area.che.yml")])

    assert_includes published, "shell/virt/linux"
    assert_includes published, "base"
  end

  def test_ignores_a_non_mapping_spec
    assert_empty CheMatrix.published(["[]\n"])
  end
end

class CoveredTest < Minitest::Test
  def test_collects_profiles_from_template_includes
    assert_equal %w[base virt/linux cli/macos], CheMatrix.covered(fixture("gitlab-ci.yml"))
  end

  def test_ignores_unrelated_includes
    refute_includes CheMatrix.covered(fixture("gitlab-ci.yml")), "not/a/profile"
  end

  def test_returns_empty_without_includes
    assert_empty CheMatrix.covered("stages: [validate]\n")
  end
end

class DiffTest < Minitest::Test
  def test_clean_when_both_sides_match
    assert CheMatrix.diff(%w[a b], %w[b a]).clean?
  end

  def test_names_a_published_profile_no_include_covers
    assert_equal %w[b], CheMatrix.diff(%w[a b], %w[a]).uncovered
  end

  def test_names_a_covered_profile_no_spec_publishes
    assert_equal %w[c], CheMatrix.diff(%w[a], %w[a c]).unpublished
  end
end
##[<] 🤖🤖
