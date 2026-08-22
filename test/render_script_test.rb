##[>] 🤖🤖
require "minitest/autorun"
require "open3"

SCRIPT = File.expand_path("../shared/ci/render-templates.zsh", __dir__)

def run_script(*args, env: {})
  base = { "CI" => nil, "CHE_BIN" => "true" }
  Open3.capture3(base.merge(env), SCRIPT, *args, chdir: File.expand_path("..", __dir__))
end

class EnvTypeArgumentTest < Minitest::Test
  def test_a_missing_env_type_is_refused
    _, err, status = run_script

    assert_equal 2, status.exitstatus
    assert_includes err, "dev|ci"
  end

  def test_an_unknown_env_type_is_refused
    _, err, status = run_script("--env-type=nonsense")

    assert_equal 2, status.exitstatus
    assert_includes err, "dev|ci"
  end

  def test_an_unknown_argument_is_refused
    _, err, status = run_script("--nope")

    assert_equal 2, status.exitstatus
    assert_includes err, "unknown argument"
  end
end

class CiDetectionTest < Minitest::Test
  # [why] CHE_BIN=true makes every che call a no-op, so the run reports which
  #   phases the script chose without rendering anything.
  def test_a_pipeline_never_seeds_dot_env_even_when_asked_for_the_dev_path
    _, _, status = run_script("--env-type=dev", env: { "CI" => "true" })

    assert_predicate status, :success?
  end

  def test_the_ci_path_stays_the_ci_path
    _, _, status = run_script("--env-type=ci", env: { "CI" => "true" })

    assert_predicate status, :success?
  end

  def test_the_dev_path_runs_off_a_pipeline
    _, _, status = run_script("--env-type=dev")

    assert_predicate status, :success?
  end
end
##[<] 🤖🤖
