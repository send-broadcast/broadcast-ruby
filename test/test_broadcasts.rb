# frozen_string_literal: true

require 'test_helper'

class TestBroadcasts < Minitest::Test
  def setup
    @bcast = new_client.broadcasts
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/broadcasts?limit=10")
      .to_return(status: 200, body: { data: [] }.to_json)

    @bcast.list(limit: 10)
  end

  def test_get
    stub_request(:get, "#{HOST}/api/v1/broadcasts/1")
      .to_return(status: 200, body: { id: 1, subject: 'Newsletter' }.to_json)

    result = @bcast.get_broadcast(1)
    assert_equal 'Newsletter', result['subject']
  end

  def test_create
    stub_request(:post, "#{HOST}/api/v1/broadcasts")
      .with(body: hash_including('subject' => 'March Update'))
      .to_return(status: 201, body: { id: 5 }.to_json)

    result = @bcast.create(subject: 'March Update', body: '<p>News</p>')
    assert_equal 5, result['id']
  end

  def test_update
    stub_request(:patch, "#{HOST}/api/v1/broadcasts/1")
      .to_return(status: 200, body: { id: 1 }.to_json)

    @bcast.update(1, subject: 'Updated')
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/broadcasts/1")
      .to_return(status: 200, body: {}.to_json)

    @bcast.delete(1)
    assert_requested(:delete, "#{HOST}/api/v1/broadcasts/1")
  end

  def test_send_broadcast
    stub_request(:post, "#{HOST}/api/v1/broadcasts/1/send_broadcast")
      .to_return(status: 200, body: { id: 1, status: 'queueing' }.to_json)

    result = @bcast.send_broadcast(1)
    assert_equal 'queueing', result['status']
  end

  def test_schedule
    stub_request(:post, "#{HOST}/api/v1/broadcasts/1/schedule_broadcast")
      .with(body: hash_including('scheduled_send_at' => '2026-03-20T09:00:00Z'))
      .to_return(status: 200, body: { status: 'future_scheduled' }.to_json)

    result = @bcast.schedule(1, scheduled_send_at: '2026-03-20T09:00:00Z', scheduled_timezone: 'America/Toronto')
    assert_equal 'future_scheduled', result['status']
  end

  def test_cancel_schedule
    stub_request(:post, "#{HOST}/api/v1/broadcasts/1/cancel_schedule")
      .to_return(status: 200, body: { status: 'draft' }.to_json)

    result = @bcast.cancel_schedule(1)
    assert_equal 'draft', result['status']
  end

  def test_statistics
    stub_request(:get, "#{HOST}/api/v1/broadcasts/1/statistics")
      .to_return(status: 200, body: { delivery: { sent: 1500 } }.to_json)

    result = @bcast.statistics(1)
    assert_equal 1500, result['delivery']['sent']
  end

  def test_statistics_timeline
    stub_request(:get, "#{HOST}/api/v1/broadcasts/1/statistics/timeline?timeframe=24h&metrics=opens,clicks")
      .to_return(status: 200, body: { series: [] }.to_json)

    @bcast.statistics_timeline(1, timeframe: '24h', metrics: 'opens,clicks')
  end

  def test_statistics_links
    stub_request(:get, "#{HOST}/api/v1/broadcasts/1/statistics/links?sort=clicks&order=desc")
      .to_return(status: 200, body: { links: [] }.to_json)

    @bcast.statistics_links(1, sort: 'clicks', order: 'desc')
  end
end
