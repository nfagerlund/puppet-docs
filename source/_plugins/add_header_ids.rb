# This monkey-patch:
#
# * Intercepts the fully-rendered content fragment of each page
# * Inserts an id attribute if there isn't one already
# * Builds a list of all headers within the content fragment
# * Inserts that list into the page.all_headers variable.
#
# We previously relied on Kramdown's automatic header IDs, but that left us with
# an undesirable dependence on one library. If we want reliable in-page anchors
# (and we do), we need to control the implementation, which is what we're doing
# here. I've borrowed Kramdown's implementation here, so our existing anchors
# will stay the same.
#
# Currently, we only behave oddly when a header contains something that
# Kramdown's smartypants implementation would transform.
#
# -NF August 8, 2013 / June 17, 2014

# PS: This was very helpful: http://www.runtime-era.com/2012/12/reopen-and-modify-ruby-classes-monkey.html

require 'nokogiri'

module Jekyll
  module Convertible

# Show page titles as we generate them (useful for checking relative speed of certain pages)
#     alias original_do_layout do_layout
#     def do_layout(payload, layouts)
#       $stdout.puts(payload['page']['title'])
#       original_do_layout(payload, layouts)
#     end

    alias original_render_all_layouts render_all_layouts
    def render_all_layouts(layouts, payload, info)
      # render_all_layouts is called as the last step of the do_layout method.

      # At the moment this is called, self.output and self.content are
      # identical. Or, actually I think they're references to the same object in
      # memory, because of the way assignment in Ruby works.

      # At any rate, the value of both of them now is the final HTML content
      # fragment before rendering the layout, despite the name of these methods.
      # (It's confusing to me too.) This means any Liquid tags have been
      # replaced with their values, and any Markdown or Textile (or any other
      # thing that can be handled by a converter plugin) has been compiled down
      # to HTML.

      # We should be able to modify both self.content and self.output by
      # modifying either of them, but the next method to use this material uses
      # self.output, so that's what we'll stick to. We can also shim new page
      # data in by modifying the payload['page'] hash; any variables added like
      # this will be available within layout templates by accessing
      # page.name_of_variable.

      # I want to:
      # - Rewrite all <h\d> elements in the content to have an ID attribute,
      #   calculated the same way Kramdown does it.
      # - Keep an array of all headers (including 'level' [integer],
      #   'text' [string], and 'id' [string without leading #]), in the order
      #   in which they were encountered in the document.

      process_headers_with_nokogiri # populates the @all_headers instance variable
      payload['page']['all_headers'] = @all_headers
      # payload['page']['all_headers_dump'] = @all_headers.inspect
      original_render_all_layouts(layouts, payload, info)
    end


    # Munge all header elements in self.output, and build up an @all_headers data structure.
    #
    # We used to do this with gsub, but this method is safer, more correct, and
    # easier to debug. Nokogiri is OK to install under Bundler these days, and the
    # speed is actually fine if we use an xpath expression instead of a CSS selector.
    def process_headers_with_nokogiri
      output_fragment = Nokogiri::HTML::DocumentFragment.parse(self.output)
      # If you're putting html inside a div or something, you're expected to
      # fend for yourself. But we handle blockquotes because Markdown makes it
      # easy to nest headers in them.
      output_fragment.xpath('h1|blockquote/h1|h2|blockquote/h2|h3|blockquote/h3|h4|blockquote/h4|h5|blockquote/h5|h6|blockquote/h6').each do |header|
        unless header[:id]
          header[:id] = generate_id(header.text)
        end
        @all_headers ||= []
        @all_headers << {
          'text'  => header.text,
          'level' => header.name.split('')[-1].to_i,
          'id'    => header[:id]
        }
      end
      self.output = output_fragment.to_html
    end


    # Transform a string of header text into a unique ID.
    # Stolen & modified from Kramdown code, which has MIT license. -NF
    # Generate an unique alpha-numeric ID from the the string +str+ for use as a header ID.
    def generate_id(str)
      gen_id = str.sub(/^[^a-zA-Z]+/, '')
      gen_id.tr!('^a-zA-Z0-9 -', '')
      gen_id.tr!(' ', '-')
      gen_id.downcase!
      gen_id = 'section' if gen_id.length == 0
      @used_ids ||= {}
      if @used_ids.has_key?(gen_id)
        gen_id += '-' << (@used_ids[gen_id] += 1).to_s
      else
        @used_ids[gen_id] = 0
      end
      gen_id
    end


  end
end