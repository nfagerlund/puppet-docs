(insert yaml frontmatter)

(I think the title should be something like "Writing Functions in Ruby (Modern API)" — a lot of internal material refers to this as, quote, "the four-ex API," and sir I do not like it. For one thing, it should long outlive the Puppet 4 series, so let's not tie it to that.

Another potential name for the API is "the Puppet::Functions API," because the prior api was based on the Puppet::Parser::Functions namespace instead.

If you've got any thoughts about naming here, btw...)

-----

Structure:

I'll leave the structure to you. This isn't quite a language page, like the one about functions written in puppet was; it's something a bit different, and we're not teaching ruby. Glad to talk this over with you, but feel free to put your own stamp on it.

-----

Intro:

I suggest writing the intro stuff last. probably something to the effect of:

* Ruby functions run on the puppet master, not on the agent.
* You can write custom functions in Puppet or in Ruby; the ruby ones are a bit more capable.
* There's an older Ruby API for functions (`Puppet::Parser::Functions`), and a modern (better) one (`Puppet::Functions`, only works in Puppet 4+).

Here's the spec: https://github.com/puppetlabs/puppet-specifications/blob/master/language/func-api.md
Here are a bunch of examples in the core Puppet code: https://github.com/puppetlabs/puppet/tree/master/lib/puppet/functions/


-----


Basically, you make a ruby file and store it in a module under `lib/puppet/functions/<NAME>.rb`. That file contains exactly one thing: a call to the Puppet::Functions.create_function() method, which takes

