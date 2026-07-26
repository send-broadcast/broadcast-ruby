# frozen_string_literal: true

require 'test_helper'

# The gemspec builds its file list from `git ls-files` minus an exclusion list.
# Anything not excluded ships to every user who installs the gem, so internal
# planning documents and tooling metadata have to be filtered out deliberately.
class TestGemspec < Minitest::Test
  def setup
    @spec = Gem::Specification.load(File.expand_path('../broadcast-ruby.gemspec', __dir__))
  end

  def test_ships_the_library
    assert_includes @spec.files, 'lib/broadcast.rb'
    assert_includes @spec.files, 'lib/broadcast/resources/autopilots.rb'
  end

  def test_ships_user_facing_docs
    assert_includes @spec.files, 'README.md'
    assert_includes @spec.files, 'CHANGELOG.md'
    assert_includes @spec.files, 'LICENSE.txt'
  end

  # Roadmaps and work logs are for this repo, not for someone's vendor/bundle.
  def test_excludes_internal_planning_docs
    %w[TODO.md SDK-TODO.md].each do |file|
      refute_includes @spec.files, file, "#{file} is internal and must not ship"
    end
  end

  # Consumed by the coverage tooling in the broadcast repo; meaningless to a user.
  def test_excludes_tooling_metadata
    refute_includes @spec.files, '.api-coverage.yml'
    refute_includes @spec.files, '.rubocop.yml'
  end

  def test_excludes_tests_and_binaries
    refute(@spec.files.any? { |f| f.start_with?('test/') })
    refute(@spec.files.any? { |f| f.start_with?('bin/') })
  end

  # Built .gem artifacts have been committed to this repo before; shipping one
  # inside another would roughly double the download for no reason.
  def test_excludes_built_gem_artifacts
    refute(@spec.files.any? { |f| f.end_with?('.gem') }, 'a built .gem is packaged inside the gem')
  end

  def test_version_matches_the_library
    assert_equal Broadcast::VERSION, @spec.version.to_s
  end
end
