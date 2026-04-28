# frozen_string_literal: true

require 'test_helper'

class TestOptInForms < Minitest::Test
  def setup
    @forms = new_client.opt_in_forms
  end

  def test_list
    stub_request(:get, "#{HOST}/api/v1/opt_in_forms")
      .to_return(status: 200, body: { opt_in_forms: [{ id: 1 }], pagination: { current: 1 } }.to_json)

    result = @forms.list
    assert_equal 1, result['opt_in_forms'].length
    assert_equal 1, result['pagination']['current']
  end

  def test_list_with_filters
    stub_request(:get, %r{#{HOST}/api/v1/opt_in_forms})
      .to_return(status: 200, body: { opt_in_forms: [] }.to_json)

    @forms.list(filter: 'newsletter', widget_type: 'inline', enabled: 'true')
    assert_requested(:get, /filter=newsletter/)
    assert_requested(:get, /widget_type=inline/)
    assert_requested(:get, /enabled=true/)
  end

  def test_get
    stub_request(:get, "#{HOST}/api/v1/opt_in_forms/5")
      .to_return(status: 200, body: { id: 5, label: 'Newsletter' }.to_json)

    result = @forms.get_opt_in_form(5)
    assert_equal 'Newsletter', result['label']
  end

  def test_create_wraps_under_opt_in_form
    stub_request(:post, "#{HOST}/api/v1/opt_in_forms")
      .with(body: hash_including('opt_in_form' => hash_including('label' => 'Newsletter')))
      .to_return(status: 201, body: { id: 1 }.to_json)

    @forms.create(label: 'Newsletter', form_type: 'inline')
  end

  def test_update_wraps_under_opt_in_form
    stub_request(:patch, "#{HOST}/api/v1/opt_in_forms/5")
      .with(body: hash_including('opt_in_form' => hash_including('enabled' => false)))
      .to_return(status: 200, body: { id: 5 }.to_json)

    @forms.update(5, enabled: false)
  end

  def test_delete
    stub_request(:delete, "#{HOST}/api/v1/opt_in_forms/5")
      .to_return(status: 200, body: { message: 'Opt-in form deleted successfully' }.to_json)

    result = @forms.delete(5)
    assert_includes result['message'], 'deleted'
  end

  def test_analytics_with_no_dates
    stub_request(:get, "#{HOST}/api/v1/opt_in_forms/5/analytics")
      .to_return(status: 200, body: { form_id: 5, totals: {} }.to_json)

    @forms.analytics(5)
    assert_requested(:get, "#{HOST}/api/v1/opt_in_forms/5/analytics")
  end

  def test_analytics_with_date_objects
    stub_request(:get, %r{#{HOST}/api/v1/opt_in_forms/5/analytics})
      .to_return(status: 200, body: { form_id: 5 }.to_json)

    @forms.analytics(5, start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 31))
    assert_requested(:get, /start_date=2026-01-01/)
    assert_requested(:get, /end_date=2026-01-31/)
  end

  def test_analytics_with_string_dates_passed_through
    stub_request(:get, %r{#{HOST}/api/v1/opt_in_forms/5/analytics})
      .to_return(status: 200, body: { form_id: 5 }.to_json)

    @forms.analytics(5, start_date: '2026-02-01', end_date: '2026-02-28')
    assert_requested(:get, /start_date=2026-02-01/)
    assert_requested(:get, /end_date=2026-02-28/)
  end

  def test_create_variant
    stub_request(:post, "#{HOST}/api/v1/opt_in_forms/5/variants")
      .with(body: hash_including('name' => 'B', 'weight' => 50))
      .to_return(status: 201, body: { id: 6, variant_name: 'B' }.to_json)

    @forms.create_variant(5, name: 'B', weight: 50)
  end

  def test_create_variant_omits_nil
    stub_request(:post, "#{HOST}/api/v1/opt_in_forms/5/variants")
      .to_return(status: 201, body: { id: 6 }.to_json)

    @forms.create_variant(5)
    assert_requested(:post, "#{HOST}/api/v1/opt_in_forms/5/variants") do |req|
      req.body.nil? || req.body.empty? || JSON.parse(req.body).empty?
    end
  end

  def test_duplicate
    stub_request(:post, "#{HOST}/api/v1/opt_in_forms/5/duplicate")
      .with(body: hash_including('label' => 'Copy 1'))
      .to_return(status: 201, body: { id: 7 }.to_json)

    @forms.duplicate(5, label: 'Copy 1')
  end
end
