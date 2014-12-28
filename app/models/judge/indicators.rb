class Judge
  module Indicators
    extend ActiveSupport::Concern

    def indicators
      Judge::Indicators.for(self)
    end

    def self.for(judge)
      load! unless @data

      @data[judge.id]
    end

    def self.load!
      @data = Hash.new
      @numerical_average = nil

      CSV.read(Rails.root.join('data', 'judges_statistical_indicators.csv'), col_sep: "\t", headers: true).each do |line|
        judge = Judge.find_by_name(line[0])

        next unless judge

        @data[judge.id] ||= OpenStruct.new
        @data[judge.id].statistical = normalize_statistical_values(line)
      end

      CSV.read(Rails.root.join('data', 'judges_numerical_indicators.csv'), col_sep: "\t", headers: true).each do |line|
        judge = Judge.find_by_name(line[0])

        next unless judge

        @data[judge.id] ||= OpenStruct.new
        @data[judge.id].numerical = normalize_numerical_values(line)
      end
    end

    def self.numerical_average
      load! unless @data

      @numerical_average ||= calculate_numerical_average
    end

    def self.calculate_numerical_average
      average = Hash.new(0)

      @data.each do |id, values|
        next unless values.numerical

        values.numerical.each do |key, value|
          average[key] += value if value
        end
      end

      average.each do |key, value|
        average[key] = value / @data.size.to_f
      end

      average
    end

    def self.normalize_statistical_values(values)
      values.each_with_index do |(key, value), index|
        value.gsub!(/-/, '–')

        value = case value
                when 'N/A' then nil
                else value
                end

        if value
          value = case index
                  when 4, 5, 6 then value.split(',').map { |name| Court.find_by_name(name.strip) }
                  else value
                  end
        end

        values[key] = value
      end
    end

    def self.normalize_numerical_values(values)
      values.each_with_index do |(key, value), index|
        value = case index
                when 2..9 then value.to_i
                end

        values[key] = value
      end
    end
  end
end