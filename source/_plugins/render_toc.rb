# Invoke as: {% render_toc %}
# This depends entirely on that add_header_ids monkey patch, and the page.all_headers data it adds.
# We expect all_headers to be an array of hashes representing all headers in order of appearance.
# Each header object is:
# {
#   'text'  => String,
#   'level' => Integer (from one to six),
#   'id'    => String (no leading #)
# }

# For now, we are mimicking the original TOC.

module Jekyll
  class RenderTocTag < Liquid::Tag
    def initialize(tag_name, something_bogus, tokens)
      super
    end

    def render(context)
      all_headers = context.environments.first['page']['all_headers']
      return '' if (all_headers == nil or all_headers.empty?)
      toc_fragment = ''
      header_range = (2..3)

      toc_fragment << start_toc

      all_headers.each do |header|
        next unless header_range.include?(header['level'])
        toc_fragment << build_toc_item(header)
      end

      toc_fragment << end_toc
      toc_fragment
    end

    def start_toc
      %Q{<ol class="toc">\n}
    end
    def end_toc
      @depth ||= 0
      end_string ||= ''
      while @depth >= 0
        end_string << %Q{</li>\n</ol>\n}
        @depth -= 1
      end
      end_string
    end


# Nick's dev notes
# ------------
#
# (note that I might have discovered some edge cases while coding; you'll have to read the code to be sure)
#
# Each header consists of:
#
# <li>header text [<ol>all following headers of a higher level</ol>]</li>
#
# oh, I think I see how to do this.
# we'll keep a "depth" instance variable, and a "last level" instance variable.
# If the current level is greater than the last, we increment depth; if lower, we decrement.
# depth increases every time you see a higher level, decreases every time you see a lower level, never drops below 0. Depth only exists to protect against escapes.
#
#
# Wrapper for whole thing looks like:
#
# <ol class="toc">
#
# #EVERYTHING
#
# </li></ol>
#
# Each item looks like:
#
# # When last level is nil
#
# <li class="toc-lv#{level}">#TEXT AND LINK
#
# # When level = last level or (level < last level and depth == 0)
# </li>
# <li class="toc-lv#{level}">#TEXT AND LINK
#
# # When level > last level
# <ol class="toc">
# <li class="toc-lv#{level}">#TEXT AND LINK
#
# # When level < last level and depth > 0
# </li>
# </ol>
# </li>
# <li class="toc-lv#{level}">#TEXT AND LINK

    def build_toc_item(header)
      @depth ||= 0
      @last_level ||= nil

      li_and_link = %Q{<li class="toc-lv#{header['level']}"><a href="##{header['id']}">#{header['text']}</a>}
      text = ''
      if @last_level == nil
        text = li_and_link
      elsif header['level'] == @last_level
        text = %Q{</li>\n} + li_and_link
      elsif header['level'] > @last_level
        text = "\n" + %Q{<ol class="toc">\n} + li_and_link
        @depth += 1
      elsif header['level'] < @last_level and @depth > 0
        text = %Q{</li>\n} + %Q{</ol>\n} + %Q{</li>\n} + li_and_link
        @depth -= 1
      elsif header['level'] < @last_level and @depth == 0
        text = %Q{</li>\n} + li_and_link
      else
        text = "Something went wrong! Level is #{header['level']}, last level is #{@last_level}, depth is #{@depth}."
      end
      @last_level = header['level']
      text
    end


  end
end

Liquid::Template.register_tag('render_toc', Jekyll::RenderTocTag)
