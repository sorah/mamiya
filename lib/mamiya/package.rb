require 'pathname'
require 'digest/sha2'
require 'json'

module Mamiya
  class Package
    class NotExists < Exception; end
    class InternalError < Exception; end
    PATH_SUFFIXES = /\.(?:tar\.gz|json)\z/

    def initialize(path)
      @path_without_ext = Pathname.new(path.sub(PATH_SUFFIXES, ''))
      @meta_loaded_from_file = false
      @loaded_meta = nil
      meta # load
    end

    attr_reader :path
    attr_writer :meta

    def name
      meta['name'] || @path_without_ext.basename.to_s
    end

    def path
      Pathname.new(@path_without_ext.to_s + '.tar.gz')
    end

    def meta_path
      Pathname.new(@path_without_ext.to_s + '.json')
    end

    def meta
      if !@meta_loaded_from_file && meta_path.exist?
        @meta_loaded_from_file = true
        loaded_meta = load_meta()
        if @loaded_meta == @meta
          @loaded_meta = loaded_meta
          @meta = load_meta()
        end
      end
      @meta ||= {}
    end

    def application
      meta['application'] || meta[:application]
    end

    def checksum
      return nil unless exist?
      Digest::SHA2.file(path).hexdigest
    end

    def valid?
      raise NotExists, 'package not exist' unless exist?
      raise NotExists, 'meta not exist' unless meta_path.exist?
      !meta['checksum'] || checksum == meta['checksum']
    end

    def exists?
      path.exist?
    end
    alias exist? exists?

    def build!(build_dir, exclude_from_package: [], dereference_symlinks: false, package_under: nil)
      exclude_from_package.push('.svn', '.git').uniq!

      build_dir = Pathname.new(build_dir)
      build_dir += package_under if package_under

      meta['name'] = self.name
      File.write build_dir.join('.mamiya.meta.json'), self.meta.to_json

      Dir.chdir(build_dir) do
        excludes = exclude_from_package.flat_map { |exclude| ['--exclude', exclude] }
        dereference = dereference_symlinks ? ['-h'] : []

        cmd = ["tar", "czf", self.path.to_s,
               *dereference,
               *excludes,
               "."]

        result = system(*cmd)
        raise InternalError, "failed to run: #{cmd.inspect}" unless result
      end

      checksum = self.checksum()
      raise InternalError, 'checksum should not be nil after package built' unless checksum
      meta['checksum'] = checksum

      File.write meta_path, self.meta.to_json
      nil
    end

    def extract_onto!(destination)
      raise NotExists unless exist?
      Dir.mkdir(destination) unless File.directory?(destination)

      cmd = ["tar", "xf", path.to_s, "-C", destination.to_s]
      result = system(*cmd)
      raise InternalError, "Failed to run: #{cmd.inspect}" unless result

      nil
    end

    private

    def load_meta
      meta_path.exist? && JSON.parse(meta_path.read)
    end
  end
end
