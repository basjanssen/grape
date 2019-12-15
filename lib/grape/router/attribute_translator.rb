# frozen_string_literal: true

module Grape
  class Router
    # this could be an OpenStruct, but doesn't work in Ruby 2.3.0, see https://bugs.ruby-lang.org/issues/12251
    class AttributeTranslator
      attr_reader :attributes, :request_method, :requirements

      def initialize(attributes = {})
        @attributes = attributes
        @request_method = attributes[:request_method]
        @requirements = attributes[:requirements]
      end

      def to_h
        attributes
      end

      def method_missing(method_name, *args) # rubocop:disable Style/MethodMissing
        if setter?(method_name[-1])
          attributes[method_name[0..-1]] = *args
        else
          attributes[method_name]
        end
      end

      def respond_to_missing?(method_name, _include_private = false)
        if setter?(method_name[-1])
          true
        else
          @attributes.key?(method_name)
        end
      end

      private

      def setter?(method_name)
        method_name[-1] == '='
      end
    end
  end
end
