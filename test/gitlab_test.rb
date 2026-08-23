##[>] 🤖🤖
require "minitest/autorun"
require_relative "../shared/ci/ruby/gitlab"

class GitlabProjectsTest < Minitest::Test
  GROUP = "konradodwrot".freeze

  def project(path, deletion: nil)
    { "path_with_namespace" => "#{GROUP}/#{path}" }.merge(deletion ? { "marked_for_deletion_on" => deletion } : {})
  end

  #[why] a deleted project lingers in the group listing under a renamed path for the whole retention
  #   window, and every read of its declarations 404s or times out
  def test_projects_pending_deletion_are_left_out
    listing = [project("notes"), project("workspace-deletion_scheduled-84208357", deletion: "2026-08-06"),
               project("cross-repo/misc")]

    assert_equal %w[notes cross-repo/misc], CrossRepo::Gitlab.live_paths(listing, GROUP)
  end

  def test_the_group_prefix_is_stripped_from_every_path
    assert_equal ["cross-repo/prose/assets"], CrossRepo::Gitlab.live_paths([project("cross-repo/prose/assets")], GROUP)
  end

  #[why] gitlab has named the field both ways across versions: neither spelling may leak through
  def test_either_spelling_of_the_deletion_field_excludes_a_project
    listing = [{ "path_with_namespace" => "#{GROUP}/gone", "marked_for_deletion_at" => "2026-08-06" }]

    assert_empty CrossRepo::Gitlab.live_paths(listing, GROUP)
  end
end
##[<] 🤖🤖
