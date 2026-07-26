# frozen_string_literal: true

require 'test_helper'
require 'logger'

class TestResponse < Minitest::Test
  # --- Hash compatibility (v0.2 callers must keep working) ---

  def test_behaves_like_a_hash
    stub_ok({ id: 42, subject: 'Hello' })
    result = new_client.broadcasts.get_broadcast(1)

    assert_kind_of Hash, result
    assert_equal 42, result['id']
    assert_equal 'Hello', result['subject']
    assert_equal %w[id subject], result.keys
  end

  def test_equality_against_plain_hash_both_directions
    stub_ok({ 'id' => 42 })
    result = new_client.broadcasts.get_broadcast(1)

    assert_equal({ 'id' => 42 }, result)
    assert_equal result, { 'id' => 42 }
  end

  def test_empty_body_is_still_a_hash
    stub_request(:delete, "#{HOST}/api/v1/sequences/1").to_return(status: 200, body: '')
    assert_equal({}, new_client.request(:delete, '/api/v1/sequences/1'))
  end

  def test_array_body_passes_through_unwrapped
    stub_request(:get, "#{HOST}/api/v1/templates")
      .to_return(status: 200, body: [{ id: 1 }].to_json)

    result = new_client.templates.list
    assert_kind_of Array, result
    assert_equal 1, result.first['id']
  end

  def test_non_json_2xx_body_does_not_raise
    stub_request(:get, "#{HOST}/api/v1/broadcasts/1")
      .to_return(status: 200, body: '<html>proxy</html>')

    assert_equal({}, new_client.broadcasts.get_broadcast(1))
  end

  # --- Metadata ---

  def test_exposes_status
    stub_request(:post, "#{HOST}/api/v1/templates").to_return(status: 201, body: { id: 1 }.to_json)
    assert_equal 201, new_client.templates.create(label: 'x').status
  end

  def test_exposes_rate_limit
    stub_ok({ id: 1 }, headers: {
              'X-RateLimit-Limit' => '120',
              'X-RateLimit-Remaining' => '118',
              'X-RateLimit-Reset' => '2026-07-26T12:00:00Z'
            })

    rate_limit = new_client.broadcasts.get_broadcast(1).rate_limit
    assert_equal 120, rate_limit.limit
    assert_equal 118, rate_limit.remaining
    assert_equal Time.utc(2026, 7, 26, 12), rate_limit.reset
  end

  def test_rate_limit_nil_when_headers_absent
    stub_ok({ id: 1 })
    assert_nil new_client.broadcasts.get_broadcast(1).rate_limit
  end

  def test_unparseable_reset_header_does_not_raise
    stub_ok({ id: 1 }, headers: { 'X-RateLimit-Limit' => '120', 'X-RateLimit-Reset' => 'soon' })
    assert_nil new_client.broadcasts.get_broadcast(1).rate_limit.reset
  end

  def test_idempotent_replay_flag
    stub_ok({ id: 1 }, headers: { 'Idempotency-Replayed' => 'true' })
    assert_predicate new_client.broadcasts.get_broadcast(1), :idempotent_replay?
  end

  def test_idempotent_replay_false_by_default
    stub_ok({ id: 1 })
    refute_predicate new_client.broadcasts.get_broadcast(1), :idempotent_replay?
  end

  # --- Warnings ---

  def test_parses_warnings
    stub_ok({ id: 1, warnings: [
              { code: 'unrecognized_parameter', param: 'subscriber.foo',
                message: 'foo is not a recognized subscriber attribute and was ignored.' }
            ] })

    result = new_client.broadcasts.get_broadcast(1)
    assert_predicate result, :warnings?
    warning = result.warnings.first
    assert_equal 'unrecognized_parameter', warning.code
    assert_equal 'subscriber.foo', warning.param
    assert_match(/not a recognized/, warning.message)
  end

  def test_warning_without_param
    stub_ok({ id: 1, warnings: [{ code: 'double_opt_in_skipped', message: 'Already confirmed.' }] })

    warning = new_client.broadcasts.get_broadcast(1).warnings.first
    assert_nil warning.param
    assert_equal '[double_opt_in_skipped] Already confirmed.', warning.to_s
  end

  def test_warnings_empty_when_absent
    stub_ok({ id: 1 })
    result = new_client.broadcasts.get_broadcast(1)
    assert_empty result.warnings
    refute_predicate result, :warnings?
  end

  def test_warnings_stay_in_the_body
    stub_ok({ id: 1, warnings: [{ code: 'x', message: 'y' }] })
    assert_equal 1, new_client.broadcasts.get_broadcast(1)['warnings'].size
  end

  # --- warnings_mode ---

  def test_log_mode_writes_to_logger
    log = StringIO.new
    stub_ok({ id: 1, warnings: [{ code: 'parameter_ignored', param: 'created_after',
                                  message: 'could not be parsed' }] })

    new_client(logger: Logger.new(log)).broadcasts.get_broadcast(1)

    assert_includes log.string, 'parameter_ignored'
    assert_includes log.string, 'created_after'
  end

  def test_log_mode_without_logger_is_silent
    stub_ok({ id: 1, warnings: [{ code: 'x', message: 'y' }] })
    result = new_client.broadcasts.get_broadcast(1)
    assert_predicate result, :warnings?
  end

  def test_raise_mode_raises
    stub_ok({ id: 1, warnings: [{ code: 'unrecognized_parameter', param: 'foo', message: 'ignored' }] })

    error = assert_raises(Broadcast::WarningError) do
      new_client(warnings_mode: :raise).broadcasts.get_broadcast(1)
    end
    assert_match(/unrecognized_parameter/, error.message)
    assert_equal 1, error.warnings.size
    assert_equal 1, error.response['id'], 'the successful body is still reachable'
  end

  def test_raise_mode_ignores_clean_responses
    stub_ok({ id: 1 })
    new_client(warnings_mode: :raise).broadcasts.get_broadcast(1)
  end

  def test_ignore_mode_neither_logs_nor_raises
    log = StringIO.new
    stub_ok({ id: 1, warnings: [{ code: 'x', message: 'y' }] })

    result = new_client(warnings_mode: :ignore, logger: Logger.new(log)).broadcasts.get_broadcast(1)

    assert_predicate result, :warnings?
    refute_includes log.string, 'WARN'
  end

  private

  def stub_ok(body, headers: {})
    stub_request(:get, "#{HOST}/api/v1/broadcasts/1")
      .to_return(status: 200, body: body.to_json, headers: headers)
  end
end
