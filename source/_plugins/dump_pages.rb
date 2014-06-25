# require 'byebug'
require 'yaml'
require 'json'

module Jekyll

  # Sub-class Jekyll::StaticFile to allow recovery from unimportant exception
  # when writing the sitemap file.
  class StaticPageDataFile < StaticFile
    def write(dest)
      super(dest) rescue ArgumentError
      true
    end
  end

  class DumpPagesGenerator < Jekyll::Generator

    def generate(site)
#       byebug
      pagedata = site.pages.collect {|page|
        thispage = page.data.dup
        thispage["name"] = page.name
        thispage["dir"] = page.dir
        thispage["url"] = page.url
        thispage
      }
      site_folder = site.config['destination']
      unless File.directory?(site_folder)
        p = Pathname.new(site_folder)
        p.mkdir
      end
      # yaml
      File.open(File.join(site_folder, 'allpages.yaml'), 'w') do |f|
        f.write(YAML.dump(pagedata))
        f.close
      end
      # json
      File.open(File.join(site_folder, 'allpages.json'), 'w') do |f|
        f.write(JSON.dump(pagedata))
        f.close
      end
      site.static_files << Jekyll::StaticPageDataFile.new(site, site.dest, '/', 'allpages.yaml') << Jekyll::StaticPageDataFile.new(site, site.dest, '/', 'allpages.json')

    end

  end
end
