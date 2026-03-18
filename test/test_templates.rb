# frozen_string_literal: true

require 'test_helper'

class TestTemplates < Minitest::Test
  def setup
    @tpl = new_client.templates
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/templates")
      .to_return(status: 200, body: { data: [{ id: 1, label: 'Welcome' }] }.to_json)

    result = @tpl.list
    assert_equal 'Welcome', result['data'].first['label']
  end

  def test_get
    stub_request(:get, "#{HOST}/api/v1/templates/1")
      .to_return(status: 200, body: { id: 1, label: 'Welcome' }.to_json)

    result = @tpl.get_template(1)
    assert_equal 'Welcome', result['label']
  end

  def test_create_wraps_under_template_key
    stub_request(:post, "#{HOST}/api/v1/templates")
      .with(body: hash_including('template' => hash_including('label' => 'Newsletter', 'subject' => 'Monthly Update')))
      .to_return(status: 201, body: { id: 3 }.to_json)

    result = @tpl.create(label: 'Newsletter', subject: 'Monthly Update', body: '<p>Content</p>')
    assert_equal 3, result['id']
  end

  def test_update_wraps_under_template_key
    stub_request(:patch, "#{HOST}/api/v1/templates/1")
      .with(body: hash_including('template' => hash_including('subject' => 'Updated')))
      .to_return(status: 200, body: { id: 1 }.to_json)

    @tpl.update(1, subject: 'Updated')
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/templates/1")
      .to_return(status: 200, body: {}.to_json)

    @tpl.delete(1)
    assert_requested(:delete, "#{HOST}/api/v1/templates/1")
  end
end
