module RoutingFilter
  class Base
    class_inheritable_accessor :active
    self.active = true

    attr_accessor :successor, :options

    def initialize(options = {})
      @options = options
      options.each { |name, value| instance_variable_set :"@#{name}", value }
    end

    def run(method, *args, &block)
      if RUBY_VERSION >= '1.9.0'
        # Unlike Ruby v1.8, Ruby 1.9 actually enforces the arity of procs created with lambda.
        # http://github.com/svenfuchs/adva_cms/issues#issue/8
        successor = @successor ? proc {|path, env| @successor.run(method, *args, &block) } : block
      else
        successor = @successor ? lambda { @successor.run(method, *args, &block) } : block
      end
      active ? send(method, *args, &successor) : successor.call(*args)
    end
  end
end
