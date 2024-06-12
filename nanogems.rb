
unless $LOADED_FEATURES.find { |file| file.match(/rubygems/) }
  require 'rbconfig'
  module Gem
    VERSION = "3.1.4" # arbitrary, but we need something.
    WIN_PATTERNS = [/bccwin/i, /cygwin/i, /djgpp/i, /mingw/i, /mswin/i, /wince/i]
    @@win_platform = nil
    def self.win_platform?
      if @@win_platform.nil? then
        @@win_platform = !!WIN_PATTERNS.find { |r| RUBY_PLATFORM =~ r }
      end
      @@win_platform
    end

    # Gem::LoadError: Could not find RubyGem sdfsdf (>= 0)
    class LoadError < ::LoadError
    end

    # require 'rubygems/version' references this.
    module Deprecate
      def self.skip
        false
      end
    end
  end

  # load for rubygems version comparators
  require 'rubygems/version'

  class Nanogems
    VERSION = "1.0.0"
    class << self
      
      # TODO: configuration
      # TODO: modularize, ~/.gems

      # Nanogems.gempaths("foo")
      # => ["/usr/lib/ruby/gems/1.8/gems/foo-1.0.0/lib"]
      def gempaths(name, dirlist)
        dirlist = self.path.flat_map { |gpath| self.dircache(File.join(gpath, 'gems', '*')) }
        dirlist.select { |dir| File.basename(dir).match?(/^#{name}-([\d\.]+)$/)}.map { |d| File.join(d, 'lib')}
        #self.path.flat_map do |gpath|
        #  Dir["#{gpath}/gems/#{name}-*/lib"]
        #end
      end

      def get_named_gem_path(name, version)
        self.path.each do |gpath|
          dirpath = "#{gpath}/gems/#{name}-#{version}/lib"
          return dirpath if Dir.exist? dirpath
        end
        nil
      end

      def dircache(directory)
        @dircache ||= {}
        @dircache[directory] ||= Dir[directory]
      end

      def highest_gem(name)
        lookup = {}
        gem_paths = self.gempaths(name, nil)
        raise LoadError.new("Cannot find gem #{name}") if gem_paths.empty? 
        #p gem_paths_possible: gem_paths
        gem_paths.each do |gem_path|
          #p gempath: gem_path
          if matches = File.basename(File.dirname(gem_path)).match(/^(.*?)-([\d\.]+)$/)
            #p matches: matches
            name, version_no = matches.captures[0,2]
            version = Gem::Version.new(version_no)
            if !lookup[name] || (lookup[name] && lookup[name][1] < version)
              lookup[name] = [gem_path, version]
            end
          end
        end
        #p name: name, lookup: lookup
        return lookup[name][0]
      end

      # Nanogems.gem("foo", "0.9.8")
      # => "/usr/lib/ruby/gems/1.8/gems/foo-0.9.8/lib"
      def gem(name, version)
        if version.nil?
          self.highest_gem(name)
        else
          get_named_gem_path(name, version) || self.gem(name, nil)
        end
      end

      def loaded_gems
        @loaded_gems ||= Array.new
      end

      # Array of paths to search for Gems.
      def path
        @path ||= begin
          paths = [self.default_path]
          paths += ENV.fetch("GEM_PATH","").split(File::PATH_SEPARATOR)
          paths
        end
      end

      def default_path
        @default_path ||= if defined? RUBY_FRAMEWORK_VERSION then
          File.join File.dirname(RbConfig::CONFIG["sitedir"]), 'Gems', 
            RbConfig::CONFIG["ruby_version"]
        elsif defined?(RUBY_ENGINE) && File.directory?(
          File.join(RbConfig::CONFIG["libdir"], RUBY_ENGINE, 'gems', 
            RbConfig::CONFIG["ruby_version"])
          )
            File.join RbConfig::CONFIG["libdir"], RUBY_ENGINE, 'gems', 
              RbConfig::CONFIG["ruby_version"]
        else
          File.join RbConfig::CONFIG["libdir"], 'ruby', 'gems', 
            RbConfig::CONFIG["ruby_version"]
        end
      end

      def preprocess_version(original_version)
        return original_version unless original_version.is_a?(String)
        version = original_version.clone
        deleted_chars = version.delete!("<>=~ ") 
        warn "Not handling version '#{original_version}' with these characters '<>=~ '" if deleted_chars
        return version
      end

      def activate(name, version = nil)
        gem = if version.nil?
          self.highest_gem(name)
        else
          # TODO: > = ~ version
          # >= 0
          version = self.preprocess_version(version)
          #version.delete!("<>=~ ") if version.is_a?(String)
          self.gem(name, version)
        end
        self.loaded_gems.push(File.basename(File.dirname(gem)))
        $:.push(gem)
      end

      # We may not actually need this...
      def deactivate(name, version = nil)
        if version.nil?
          $:.each do |path|
            if File.dirname(path).match(/^#{Regexp::quote(name)}-/)
              $:.delete!(path)
            end
          end
        else
          # TODO: > = ~ version
          # >= 0
          version = self.preprocess_version(version)
          libdir = self.gem(name, version)
          $:.delete(libdir) if $:.include?(libdir)
        end
      end

      def path_info
        if $DEBUG or $VERBOSE
          STDERR.puts "Load paths: #{$:.inspect}"
          STDERR.puts "Loaded gems: #{::Nanogems.loaded_gems.inspect}"
        end
      end
    end
  end

  module Kernel
    alias_method :__require__, :require

    def gem(name, version = nil)
      Nanogems.activate(name, version)
    end
    
    # Attempt sequence for a require:
    # 1. kernel.require
    # 2. activate gemname-replace-slash-with-dash, then require
    #   - rack/protection -> rack-protection
    # 3. activate gemname-strip-after-slash, then require
    #   - rexml/document -> rexml
    def require(file)
      __require__(file)
    rescue LoadError
      begin
        hackfile = file.gsub(%r|/|,'-')
        Nanogems.activate(hackfile) # rescue nil
        __require__(file)
      rescue LoadError
        begin
          hackfile = file.sub(%r|/.*|,'')
          Nanogems.activate(hackfile) # rescue nil
          __require__(file)
        rescue LoadError
          Nanogems.path_info
          raise $!
        end
      end
    end
  end
end