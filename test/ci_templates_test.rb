##[>] 🤖🤖
require "minitest/autorun"
require "yaml"

TEMPLATE_DIR = File.expand_path("../ci/templates", __dir__)

def template(name)
  YAML.load_stream(File.read(File.join(TEMPLATE_DIR, name)))
end

def spec_and_body(name)
  docs = template(name)
  raise "#{name}: want a spec header then a body" unless docs.length == 2

  docs
end

class MatrixTemplateSpecTest < Minitest::Test
  MATRIX_TEMPLATES = %w[CheProfileDryRun.gitlab-ci.yml CheProfileApply.gitlab-ci.yml].freeze

  def test_declares_required_profiles_input
    MATRIX_TEMPLATES.each do |name|
      profiles = spec_and_body(name).first.dig("spec", "inputs", "profiles")

      assert_equal "array", profiles["type"], name
      refute profiles.key?("default"), "#{name}: profiles must stay required"
    end
  end

  def test_fans_out_over_profiles_and_arches
    MATRIX_TEMPLATES.each do |name|
      matrix = spec_and_body(name).last.values.first.dig("parallel", "matrix").first

      assert_equal "$[[ inputs.profiles ]]", matrix["CHE_PROFILE"], name
      assert_equal "$[[ inputs.arches ]]", matrix["ARCH"], name
    end
  end

  def test_extends_a_body_the_base_template_defines
    bases = template("CheProfileBase.gitlab-ci.yml").first.keys

    MATRIX_TEMPLATES.each do |name|
      extended = spec_and_body(name).last.values.first["extends"]
      as_user = spec_and_body(name).first.dig("spec", "inputs", "as_user", "options")

      as_user.each do |value|
        assert_includes bases, extended.sub("$[[ inputs.as_user ]]", value), name
      end
    end
  end

  def test_gates_every_job_on_the_enabled_input
    MATRIX_TEMPLATES.each do |name|
      first_rule = spec_and_body(name).last.values.first["rules"].first

      assert_equal "never", first_rule["when"], name
      assert_includes first_rule["if"], "inputs.enabled", name
    end
  end
end

class DryRunTemplateTest < Minitest::Test
  def job
    spec_and_body("CheProfileDryRun.gitlab-ci.yml").last.values.first
  end

  def test_runs_dry
    assert_equal "all", job.dig("variables", "MK_DRY_RUN")
  end

  def test_runs_on_merge_requests_and_the_default_branch
    conditions = job["rules"].drop(1).map { |rule| rule["if"] }

    assert_includes conditions, '$CI_PIPELINE_SOURCE == "merge_request_event"'
    assert_includes conditions, "$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH"
  end
end

class ApplyTemplateTest < Minitest::Test
  def job
    spec_and_body("CheProfileApply.gitlab-ci.yml").last.values.first
  end

  def test_never_applies_on_a_draft
    draft = job["rules"].find { |rule| rule["if"].to_s.include?("CI_MERGE_REQUEST_DRAFT") }

    assert_equal "never", draft["when"]
  end

  def test_waits_for_a_manual_click
    assert_equal "manual", job["rules"].last["when"]
  end

  def test_never_runs_outside_a_merge_request
    outside = job["rules"].find { |rule| rule["if"] == '$CI_PIPELINE_SOURCE != "merge_request_event"' }

    assert_equal "never", outside["when"]
  end
end

class BaseTemplateTest < Minitest::Test
  def bodies
    template("CheProfileBase.gitlab-ci.yml").first
  end

  def test_defines_only_hidden_jobs
    bodies.each_key { |name| assert name.start_with?("."), "#{name} must be a hidden job" }
  end

  def test_both_bodies_run_the_same_make_target
    bodies.each_value { |body| assert_includes body["script"].join(" "), "sync-full" }
  end

  def test_the_as_user_body_hands_every_upstream_pin_to_sudo
    script = bodies.fetch(".che-profile-matrix-true")["script"].join(" ")

    %w[CHE_PROFILE MK_DRY_RUN CHE_PACKAGES_REF PROSE_ASSETS_REF MISC_REF
       CONFIGS_TOOLS_REF CONFIGS_AI_TOOLS_REF].each do |name|
      assert_includes script, name
    end
  end
end
##[<] 🤖🤖
