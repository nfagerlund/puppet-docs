---
layout: default
built_from_commit: 4e0b2b9b2c68e41c386308d71d23d9b26fbfa154
title: 'Resource Type: router'
canonical: /puppet/latest/reference/types/router.html
---

> **NOTE:** This page was generated from the Puppet source code on 2016-08-10 20:10:55 -0500

router
-----

* [Attributes](#router-attributes)

<h3 id="router-description">Description</h3>

Manages connected router.

<h3 id="router-attributes">Attributes</h3>

<pre><code>router { 'resource title':
  <a href="#router-attribute-url">url</a> =&gt; <em># <strong>(namevar)</strong> An SSH or telnet URL at which to access the...</em>
  # ...plus any applicable <a href="{{puppet}}/metaparameter.html">metaparameters</a>.
}</code></pre>

<h4 id="router-attribute-url">url</h4>

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

An SSH or telnet URL at which to access the router, in the form
`ssh://user:pass:enable@host/` or `telnet://user:pass:enable@host/`.

([↑ Back to router attributes](#router-attributes))





> **NOTE:** This page was generated from the Puppet source code on 2016-08-10 20:10:55 -0500