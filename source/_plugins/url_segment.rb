# Okay, so:
# "/references/3.0.latest/type.html".split('/') -> ["", "references", "3.0.latest", "type.html"]

# This tag takes an integer and uses it to index into the array created by
# calling `.split('/')` on the page.url Jekyll variable. Note that page.url is
# equivalent to `location.pathname` in javascript.

# This can replace the reference_version tag, as well as others. You can use -1
# to get the filename portion.

# NF 2015

module Jekyll
  class UrlSegmentTag < Liquid::Tag
		def initialize(tag_name, segment, tokens)
			super
			@segment = segment.to_i
		end

		def render(context)
      pageurl = context.environments.first['page']['url']
      # "/references/3.0.latest/type.html".split('/') -> ["", "references", "3.0.latest", "type.html"]
      pageurl.split('/')[@segment]
    end

  end
end

Liquid::Template.register_tag('url_segment', Jekyll::UrlSegmentTag)
