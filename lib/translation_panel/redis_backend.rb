module TranslationPanel
  class RedisBackend < I18n::Backend::KeyValue
    include I18n::Backend::Pluralization

    attr_reader :store

    def initialize(store)
      @subtrees = false
      @store = store
    end

  protected
    def lookup(locale, key, scope = [], options = {})
      key = normalize_flat_keys(locale, key, scope, options[:separator])
      count = options[:count]
      value = @store["#{locale}.#{key}"]
      if !count && value && (decoded = decode(value))
        TranslationPanel.push key if TranslationPanel.show?
        decoded
      else  # look in namespace
        pluralization_result = count ? get_count_keys(locale, key) : {}
        full_keys = @store.keys "#{locale}.#{key}.*"
        if full_keys.empty?
          TranslationPanel.push key if TranslationPanel.show?
          I18n.backend.store_translations(locale, {key => nil}, :escape => false) unless value
          nil
        else
          keys = full_keys.map{ |full_key| full_key.partition("#{locale}.")[2] }
          TranslationPanel.push keys if TranslationPanel.show?
          flatten_result = full_keys.inject({}) do |result, full_key|
            value = @store[full_key]
            result.merge full_key.partition("#{locale}.#{key}.")[2] => decode(value)
          end
          expand_keys(pluralization_result.merge(flatten_result)).deep_symbolize_keys
        end
      end
    end

    def decode(value)
      ActiveSupport::JSON.decode(value)
    end

    # Transforms flatten hash into nested hash
    #   expand_keys "some.one" => "a", "some.another" => "b"
    #   # => "some" => {"one" => "a", "another" => "b"}
    def expand_keys(flatten_hash)
      expanded_hash = {}
      flatten_hash.each do |key, value|
        key_parts = key.partition "."
        if key_parts[2].empty?
          expanded_hash.deep_merge! key => value
        else
          expanded_hash.deep_merge! key_parts[0] => expand_keys(key_parts[2] => value)
        end
      end
      expanded_hash
    end

    # Creates empty translations for absented pluralization keys.
    # Returns hash with plural keys and their values (even from another backend)
    def get_count_keys(locale, key)
      empty_translations = {}
      store_empty_translations = false
      count_keys = I18n.t!('i18n.plural.keys', :locale => locale).inject({}) do |result, plural_key|
        full_key = "#{key}.#{plural_key}"
        value = get_translate(locale, full_key)
        if value
          store_empty_translations = true
          result.merge plural_key.to_s => value
        else
          empty_translations.merge! full_key => ""
          result
        end
      end
      if store_empty_translations && empty_translations.present?
        I18n.backend.store_translations locale, empty_translations, :escape => false
      end
      count_keys
    rescue
      {}
    end

    # returns translation key if any, otherwise nil
    def get_translate(locale, key)
      I18n.t!(key, :locale => locale)
    rescue
      nil
    end
  end
end
