# frozen_string_literal: true

require 'test_helper'

class TestSegments < Minitest::Test
  def setup
    @seg = new_client.segments
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/segments.json")
      .to_return(status: 200, body: { segments: [{ id: 1, name: 'Active' }] }.to_json)

    result = @seg.list
    assert_equal 'Active', result['segments'].first['name']
  end

  def test_get_with_subscribers
    stub_request(:get, "#{HOST}/api/v1/segments/1.json?page=2")
      .to_return(status: 200, body: { segment: { id: 1 }, subscribers: [] }.to_json)

    @seg.get_segment(1, page: 2)
  end

  def test_create
    stub_request(:post, "#{HOST}/api/v1/segments")
      .with(body: hash_including('segment' => hash_including('name' => 'Gmail Users')))
      .to_return(status: 201, body: { id: 5 }.to_json)

    @seg.create(
      name: 'Gmail Users',
      segment_groups_attributes: [
        {
          match_type: 'all',
          segment_rules_attributes: [
            { field: 'email', operator: 'contains', value: 'gmail.com', rule_type: 'text', value_type: 'string' }
          ]
        }
      ]
    )
  end

  def test_update
    stub_request(:patch, "#{HOST}/api/v1/segments/1")
      .with(body: hash_including('segment' => hash_including('name' => 'Updated')))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @seg.update(1, name: 'Updated')
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/segments/1")
      .to_return(status: 200, body: {}.to_json)

    @seg.delete(1)
    assert_requested(:delete, "#{HOST}/api/v1/segments/1")
  end
end
