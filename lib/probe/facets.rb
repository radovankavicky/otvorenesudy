module Probe
  class Facets
    include Enumerable

    attr_reader :params

    def initialize(facets)
      @facets = Hash.new.with_indifferent_access

      facets.each do |facet|
        @facets[facet.name] = facet
      end
    end

    def extract_facets_params(params)
      refresh!

      @params = {}.with_indifferent_access

      params.each do |param, value|
        facet = @facets[param]

        if facet
          terms = facet.parse_terms(value)

          facet.terms         = terms
          @params[facet.name] = terms
        end
      end

      each { |facet| facet.params = @params }
    end

    def add_search_params(options)
      @params.merge! options
    end

    def build_query
      map { |facet| facet.build_query if facet.respond_to?(:build_query) && facet.active? }
    end

    def build_filter(type)
      { type => map { |facet| { or: facet.build_filter } if facet.active?  }}
    end

    def build_selective_filter(type, options)
      # TODO what's going on in here?
      included = options[:include] || @facets.values
      excluded = options[:exclude] || []

      filter = map do |facet|
        if included.include?(facet) && !excluded.include?(facet)
          { or: facet.build_filter } if facet.active?
        end
      end

      { type => filter }
    end

    def highlights
      map { |facet| facet.highlights if facet.respond_to? :highlights }.flatten
    end

    def populate(results)
      results.each do |name, values|
        facet = @facets[name]

        next unless facet

        facet.populate(values, results[facet.selected_name])
      end

      map { |facet| facet.results }
    end

    def each(&block)
      @facets.each_value { |facet| yield(facet) }
    end

    def map(&block)
      @facets.values.map { |facet| yield(facet) }.compact
    end

    def [](name)
      @facets[name]
    end

    private

    def refresh!
      each { |facet| facet.refresh! }
    end
  end
end
