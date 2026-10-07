# frozen_string_literal: true

require 'test_helper'

# Subscriber topics: kinds of email subscribers opt in to or out of. A topic
# reads a top-level custom_data key or a tag.
class TestTopics < Minitest::Test
  def setup
    @topics = new_client.topics
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/topics.json")
      .to_return(status: 200, body: { data: [{ id: 1, name: 'Webinars' }], total: 1 }.to_json)

    assert_equal 'Webinars', @topics.list['data'].first['name']
  end

  def test_get_topic
    stub_request(:get, "#{HOST}/api/v1/topics/1.json")
      .to_return(status: 200, body: { id: 1, custom_data_key: 'sub_webinars' }.to_json)

    assert_equal 'sub_webinars', @topics.get_topic(1)['custom_data_key']
  end

  def test_create
    stub_request(:post, "#{HOST}/api/v1/topics")
      .with(body: hash_including('topic' => hash_including('name' => 'Webinars', 'custom_data_key' => 'sub_webinars')))
      .to_return(status: 201, body: { id: 3 }.to_json)

    @topics.create(name: 'Webinars', custom_data_key: 'sub_webinars')
  end

  def test_update
    stub_request(:patch, "#{HOST}/api/v1/topics/3")
      .with(body: hash_including('topic' => hash_including('unset_receives' => true)))
      .to_return(status: 200, body: { id: 3 }.to_json)

    @topics.update(3, unset_receives: true)
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/topics/3")
      .to_return(status: 200, body: { message: 'Topic deleted successfully' }.to_json)

    @topics.delete(3)
  end
end
