require 'grape/router'
require 'grape/api/instance'

module Grape
  # The API class is the primary entry point for creating Grape APIs. Users
  # should subclass this class in order to build an API.
  class API
    # Class methods that we want to call on the API rather than on the API object
    NON_OVERRIDABLE = %I[define_singleton_method instance_variable_set inspect class is_a? ! kind_of? respond_to?].freeze

    class << self
      attr_accessor :base_instance
      # When inherited, will create a list of all instances (times the API was mounted)
      # It will listen to the setup required to mount that endpoint, and replicate it on any new instance
      def inherited(remountable_class, base_instance_parent = Grape::API::Instance)
        remountable_class.initial_setup(base_instance_parent)
        remountable_class.override_all_methods
        remountable_class.make_inheritable
      end

      # Initialize the instance variables on the remountable class, and the base_instance
      # an instance that will be used to create the set up but will not be mounted
      def initial_setup(base_instance_parent)
        @instances = []
        @setup = []
        @base_parent = base_instance_parent
        @base_instance = mount_instance
      end

      # Redefines all methods so that are forwarded to add_setup and recorded
      def override_all_methods
        (base_instance.methods - NON_OVERRIDABLE).each do |method_override|
          define_singleton_method(method_override) do |*args, &block|
            add_setup(method_override, *args, &block)
          end
        end
      end

      # When classes inheriting from this API child, we also want the instances to inherit from our instance
      def make_inheritable
        define_singleton_method(:inherited) do |sub_remountable|
          Grape::API.inherited(sub_remountable, base_instance)
        end
      end

      # The remountable class can have a configuration hash to provide some dynamic class-level variables.
      # For instance, a descripcion could be done using: `desc configuration[:description]` if it may vary
      # depending on where the endpoint is mounted. Use with care, if you find yourself using configuration
      # too much, you may actually want to provide a new API rather than remount it.
      def mount_instance(configuration: {})
        instance = Class.new(@base_parent)
        instance.instance_variable_set(:@configuration, configuration)
        instance.define_singleton_method(:configuration) { @configuration }
        replay_setup_on(instance)
        @instances << instance
        instance
      end

      # Replays the set up to produce an API as defined in this class, can be called
      # on classes that inherit from Grape::API
      def replay_setup_on(instance)
        @setup.each do |setup_stage|
          instance.send(setup_stage[:method], *setup_stage[:args], &setup_stage[:block])
        end
      end

      def respond_to?(method, include_private = false)
        super(method, include_private) || base_instance.respond_to?(method, include_private)
      end

      private

      # Adds a new stage to the set up require to get a Grape::API up and running
      def add_setup(method, *args, &block)
        setup_stage = { method: method, args: args, block: block }
        @setup << setup_stage
        last_response = nil
        @instances.each do |instance|
          last_response = instance.send(setup_stage[:method], *setup_stage[:args], &setup_stage[:block])
        end
        last_response
      end
    end
  end
end
