require_relative '../lib/arachnid'

require "minitest/autorun"

class ArachnidTest < Minitest::Test
  def test_ignores_specified_extensions
    arachnid = Arachnid.new 'example.com', exclude_urls_with_extensions: ['.jpg']

    assert arachnid.extension_not_ignored?('http://example.org/example')
    refute arachnid.extension_not_ignored?('http://example.org/example.jpg')
  end

  def test_does_not_sanitize_hrefs_with_javascript_code
    arachnid = Arachnid.new 'example.com', exclude_urls_with_extensions: ['.jpg']

    refute arachnid.sanitize_link('javascript:void(0)')
  end
end
