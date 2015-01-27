require_relative '../lib/arachnid'

require "minitest/autorun"

class ArachnidTest < Minitest::Test
  def test_makes_a_url_absolute
    arachnid = Arachnid.new 'example.com'

    assert_equal "http://example.com/é#anchor", arachnid.make_absolute("/é#anchor", "http://example.com")
    assert_equal "http://example.com/é#anchor", arachnid.make_absolute("é#anchor", "http://example.com/a")
    assert_equal "http://example.com/a/é#anchor", arachnid.make_absolute("é#anchor", "http://example.com/a/b")
    assert_equal "http://other.org/a", arachnid.make_absolute("http://other.org/a", "http://example.com")
  end

  def test_ignores_specified_extensions
    arachnid = Arachnid.new 'example.com', exclude_urls_with_extensions: ['.jpg']

    assert arachnid.extension_not_ignored?('http://example.org/example')
    refute arachnid.extension_not_ignored?('http://example.org/example.jpg')
  end

  def test_parses_domain
    arachnid = Arachnid.new 'example.com'

    assert_equal arachnid.parse_domain('www.example.com/link'), 'www.example.com'
  end

  def test_hash_detection
    arachnid = Arachnid.new 'example.com', exclude_urls_with_hash: true
    refute arachnid.no_hash_in_url? 'http://www.example.com/link#1'
    
    arachnid = Arachnid.new 'example.com', exclude_urls_with_hash: false
    assert arachnid.no_hash_in_url? 'http://www.example.com/link#1'
  end

end
