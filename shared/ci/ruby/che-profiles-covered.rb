#!/usr/bin/env ruby
##[>] 🤖🤖
$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__), __dir__)
require "che_matrix"

USAGE = "usage: che-profiles-covered.rb <ci-config> <spec-file>...".freeze

ci_path, *spec_paths = ARGV
abort USAGE if ci_path.nil? || spec_paths.empty?

published = CheMatrix.published(spec_paths.map { |p| File.read(p) })
covered = CheMatrix.covered(File.read(ci_path))
diff = CheMatrix.diff(published, covered)

if diff.clean?
  puts "che profile matrix covers all #{published.length} published profiles"
  exit 0
end

warn "profiles published but in no #{CheMatrix::TEMPLATE_MARK} include: #{diff.uncovered.join(", ")}" unless diff.uncovered.empty?
warn "profiles in a #{CheMatrix::TEMPLATE_MARK} include but published by no spec: #{diff.unpublished.join(", ")}" unless diff.unpublished.empty?
exit 1
##[<] 🤖🤖
