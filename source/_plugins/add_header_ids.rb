# This monkey-patch intercepts the fully-rendered content fragment of each page,
# inserts id attributes into each header element tag, builds a list of all
# headers within the content fragment, and inserts that list into the
# page.all_headers variable.

# Previously, docs.puppetlabs.com relied on header ID generation built into the
# Kramdown markdown library. Unfortunately, this isn't a universal feature of
# the Markdown spec, and every library seems to do things differently; many
# don't even support header IDs, some use a different formula for transforming
# the header text into a unique ID, and the current best-of-class Ruby Markdown
# library, Redcarpet, uses an idiotic and 100% useless numbers-only scheme.
#
# I investigated what Github.com does, because we know they're using Redcarpet
# but they have actual good header IDs. The experiments are here:
# https://github.com/nfagerlund/evil-made-manifest/blob/master/headerproblems.
# markdown -- long story short, they appear to be turning off any auto-IDs in
# their lightweight markup renderers, and are running a post-processor on
# the generated HTML. That's obviously the way to go, so that's what we'll do.
# This should free us from dependency on any specific Markdown implementation,
# at least for this crucial thing-a-majob. We're still on the hook for things
# like footnotes, fenced code blocks, tables, etc., but there's no helping that
# for now, pending a better Markdown spec.
#
# If it were possible, it'd be a good idea for everyone doing this to just
# standardize on Github's scheme, but it's not public, and I'm not sure I've
# caught all the edges in my reverse-engineering. (I didn't test HTML entities,
# f'rex.) In the meantime, the best thing for OUR site is to hew as close as
# possible to Kramdown's behavior.
#
# Currently, we behave oddly when a header contains something that Kramdown's
# smartypants implementation would transform, but other than that I think I've
# nailed it.

# -NF August 8, 2013

# PS: This was very helpful: http://www.runtime-era.com/2012/12/reopen-and-modify-ruby-classes-monkey.html

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
      # At the moment this is called, self.output and self.content are identical. Or, actually I think they're references to the same object in memory, because of the way assignment in Ruby works.
      # At any rate, the value of both of them now is the final HTML content fragment before rendering the layout, despite the name of these methods. (It's confusing to me too.) This means any Liquid tags have been replaced with their values, and any Markdown or Textile (or any other thing that can be handled by a converter plugin) has been compiled down to HTML.

      # We should be able to modify both self.content and self.output by modifying either of them (although the next method, which consumes the content, will be accessing output). We can also shim new page data in by modifying the payload['page'] hash; any variables added like this will be available within layout templates by accessing page.new_variable.

      # I want to:
      # - Rewrite all <h\d> elements in the content to have an ID attribute, calculated the same way Kramdown does it.
      # - Keep an array of all headers (including 'level' [integer], 'text' [string], and 'id' [string without leading #]), in the order in which they were encountered in the document.

      process_headers_with_gsub # populates the @all_headers instance variable
      payload['page']['all_headers'] = @all_headers
      # payload['page']['all_headers_dump'] = @all_headers.inspect
      original_render_all_layouts(layouts, payload, info)
    end

    # Both this method and process_headers_with_nokogiri should have nearly the
    # same effect.
    def process_headers_with_gsub
      require 'htmlentities'
      entitier = HTMLEntities.new
      self.output.gsub!(
        %r{
          <(h # 1: The whole element name -- h2, h3, etc.
            (\d) # 2: Header level
          )
          (?:
            >|\s+([^>]+)> # 3: Empty or a set of attributes, which would include id="blah" if we turned on auto_ids. The group makes a capture, possibly empty, even if the alternator keeps matching from reaching it.
          )
          (.*?) # 4: Header text, potentially including <em> or <code> or some other span-level element
          </\1\s*> # Closing tag, backreferencing the element name
        }imx
      ) {|header|
        header_name = $1
        header_level = $2.to_i
        header_inner_html = $4
        header_text = entitier.decode( header_inner_html.gsub(/<[^>]+>/m, '').strip ) # Get rid of any span-level tags inside the header text, strip trailing whitespace, and decode any html entities.
        header_id = generate_id(header_text)
        @all_headers ||= []
        @all_headers << {
          'text'  => header_text,
          'level' => header_level,
          'id'    => header_id
        }
        # And now we have to replace the element with an ID added:
        ('<' + header_name + %q{ id="} + header_id + %q{">} + header_inner_html + '</' + header_name + '>')
      }
    end

    # This method is safer, more correct, and easier to debug. It also adds a
    # minimum of 1:40 to generating the docs.puppetlabs.com site as of August
    # 2013. Nokogiri is also incredibly fucked up to try and install with
    # Bundler. Anyway, that's why we're sinning with regexes.
    def process_headers_with_nokogiri
      require 'nokogiri'
      output_fragment = Nokogiri::HTML::DocumentFragment.parse(self.output)
      output_fragment.css('h1,h2,h3,h4,h5,h6').each do |header|
        header[:id] = generate_id(header.text)
        @all_headers ||= []
        @all_headers << {
          'text'  => header.text,
          'level' => header.name.split('')[-1].to_i,
          'id'    => header[:id]
        }
      end
      self.output = output_fragment.to_html

#       self.output.gsub!(/<h(\d)([^>]*)>(.*?)<\/h\1>/) { |header_tag|
#         header_tag.gsub(/id="[^'"]+/, '\0' + rand(20).to_s)
#       }
    end


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