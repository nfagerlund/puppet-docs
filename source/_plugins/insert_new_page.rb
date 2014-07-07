# require 'byebug'
require 'yaml'
require 'json'

module Jekyll

  class PageDuplicatorGenerator < Jekyll::Generator

    def generate(site)
#       byebug
      page_to_dupe = site.pages.detect {|page|
        page.url == '/puppet/3.6/reference/config_about_settings.html'
      }
      duped_page = Jekyll::DuplicatePage.new(site, site.source, page_to_dupe.dir, page_to_dupe.name, '/pe/3.2/new_config_page.html')
      duped_page_two = Jekyll::DuplicatePage.new(site, site.source, page_to_dupe.dir, page_to_dupe.name, '/pe/3.3/new_config_page.html')
      duped_page.data = duped_page.data.merge({'title' => "This is a duplicated version of the config page from puppet 3.6."})
      duped_page_two.data = duped_page.data.merge({'title' => "This is a duplicated version of the config page from puppet 3.6. AGAIN."})
      site.pages << duped_page << duped_page_two

    end

  end
end
