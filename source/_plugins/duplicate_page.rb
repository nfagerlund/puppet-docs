# Class for duplicating existing pages. A Generator plugin can use this to
# create new pages based on the content of another page.
module Jekyll
  class DuplicatePage < Page
    def initialize(site, base, dir, name, new_url)
      super(site, base, dir, name)
      @url = new_url
    end

    def url
      @url
    end

  end
end