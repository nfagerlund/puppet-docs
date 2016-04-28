require 'byebug'
# Jekyll::Hooks.register :pages, :pre_render do |page, payload|
#   if page.data['duplicate']
#     byebug
#     puts "hey"
#   end
#
# end

module Jekyll
  class DuplicatePage < Page
    def initialize(*args)
      super
    end

    def read_yaml(*args)
      self.data = {}
      self.content = ''
    end
  end

  class DuplicatePageGenerator < Generator
    def generate(site)
      site.pages.each do |page|
        if page.data['duplicate']
          source_page = site.pages.detect {|pg| pg.url == page.data['duplicate'] || pg.relative_path == page.data['duplicate']}
          page.data.merge!(source_page.data)
          page.content = source_page.content
        end
      end

      hardcoded_stubs_file = site.source + '/ja/pe/_stubs.yaml'
      require 'yaml'
      require 'pathname'
      stubs = YAML.load(File.read(hardcoded_stubs_file))
      starting_dir = Pathname.new('/') + Pathname.new(hardcoded_stubs_file).relative_path_from(Pathname.new(site.source)).dirname
      stubs.each do |dest_path, original_url|
        duplicate_pathname = starting_dir + dest_path
        duplicate_name = duplicate_pathname.basename.to_s
        duplicate_dir = duplicate_pathname.dirname.to_s
        source_page = site.pages.detect {|pg| pg.url == original_url || pg.relative_path == original_url}
        dupe_page = Jekyll::DuplicatePage.new(site, site.source, duplicate_dir, duplicate_name)
        dupe_page.data.merge!(source_page.data)
        dupe_page.content = source_page.content
        site.pages << dupe_page
      end

    end
  end
end
