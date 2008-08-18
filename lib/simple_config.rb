require 'yaml'

module SimpleConfig
  
  class << self
    def for(config_name, &block)
      default_manager.for(config_name, &block)
    end
    
    def default_manager
      @default_manager ||= Manager.new
    end
  end
  
  class Manager
    def initialize
      @configs = {}
    end
    
    def for(config_name, &block)
      returning @configs[config_name] ||= Config.new do |config|
        config.configure(&block) if block_given?
      end
    end
  end
  
  class Config
    def initialize
      @groups = {}
      @settings = {}
    end
    
    def configure(&block)
      instance_eval(&block)
    end
    
    def group(name, &block)
      returning @groups[name] ||= Config.new do |group|
        group.configure(&block) if block_given?
      end
    end
    
    def set(key, value)
      @settings[key] = value
    end
    
    def get(key)
      @settings[key]
    end
    
    def load(external_config_file, options={})
      options.reverse_merge!(:if_exists? => false)
      
      if options[:if_exists?]
        return unless File.exist?(external_config_file)
      end
      
      case File.extname(external_config_file)
      when /rb/
        instance_eval(File.read(external_config_file))
      when /yml|yaml/
        YAMLParser.parse_contents_of_file(external_config_file).parse_into(self)
      end
    end
    
    private
      def method_missing(method_name, *args)
        case true
        when @groups.key?(method_name)
          return @groups[method_name]
        when @settings.key?(method_name)
          return get(method_name)
        else
          super(method_name, *args)
        end
      end
  end
  
  class YAMLParser
    def initialize(raw_yaml_data)
      @data = YAML.load(raw_yaml_data)
    end
    
    def self.parse_contents_of_file(yaml_file)
      new(File.read(yaml_file))
    end
    
    def parse_into(config)
      @data.each do |key, value|
        parse(key, value, config)
      end
    end
    
    private
      def parse(key, value, config)
        if value.is_a?(Hash)
          group = config.group(key.to_sym)
          value.each { |key, value| parse(key, value, group) }
        else
          config.set(key.to_sym, value)
        end
      end
  end
  
end
