# NF notes here

# This was very helpful: http://www.runtime-era.com/2012/12/reopen-and-modify-ruby-classes-monkey.html
# August 8, 2013

module Jekyll
  module Convertible

    alias original_do_layout do_layout
    def do_layout(payload, layouts)
      $stdout.puts(payload['page']['title'])
      original_do_layout(payload, layouts)
    end

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