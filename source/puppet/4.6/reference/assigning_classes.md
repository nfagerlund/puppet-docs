---
title: Assigning classes to nodes
---


[console]: {{pe}}/console_classes_groups_getting_started.html
[hiera]: {{hiera}}/puppet.html#assigning-classes-to-nodes-with-hiera-hierainclude
[node_definitions]: ./lang_node_definitions.html
[enc]: ./nodes_external.html
[ldap]: ./nodes_ldap.html
[compilation]: ./lang_summary.html#compilation-and-catalogs
[main manifest]: ./dirs_manifest.html
[rp]: {{pe}}/r_n_p_intro.html

[Classes][] are Puppet's main unit of configuration. Most of the work of managing systems with Puppet can be divided into two categories:

* Designing classes that manage significant chunks of system configuration.
* Assigning those classes to nodes, which tells Puppet how to manage each system.

Although classes are always written in the Puppet language, you can assign classes with multiple tools. You can even combine multiple tools to provide different configuration tools for different parts of your business.

## Best practice: only assign role classes to nodes

**Before** you start assigning classes to nodes, we recommend that you read our [pages about the roles and profiles method][rp] and follow their advice. In short:

* Write two layers of wrapper classes (the eponymous roles and profiles) to build complete system configurations.
* Only assign "role" classes to your nodes.

Those pages demonstrate the benefits in more detail, but the summary is that this lets you manage your nodes with a small, consciously designed interface that's suited to your own infrastructure, rather than a large, randomly accreted interface that requires a lot of boilerplate and fussing around.

##







> ### How merging works
>
> Every node **always** gets a **node object** (which may be empty or may contain classes, parameters, and an environment) from the configured `node_terminus`. (This setting takes effect where the catalog is compiled; on the puppet master server when using an agent/master arrangement, and on the node itself when using puppet apply. The default node terminus is `plain`, which returns an empty node object; the `exec` terminus calls an ENC script to determine what should go in the node object.) Every node **may** also get a **node definition** from the site manifest (usually called site.pp).
>
> When compiling a node's catalog, Puppet will include **all** of the following:
>
> * Any classes specified in the node object it received from the node terminus
> * Any classes or resources which are in the site manifest but outside any node definitions
> * Any classes or resources in the most specific node definition in site.pp that matches the current node (if site.pp contains any node definitions)
>     * Note 1: If site.pp contains at least one node definition, it **must** have a node definition that matches the current node; compilation will fail if a match can't be found.
>     * Note 2: If the node name resembles a dot-separated fully qualified domain name, Puppet will make multiple attempts to match a node definition, removing the right-most part of the name each time. Thus, Puppet would first try `agent1.example.com`, then `agent1.example`, then `agent1`. This behavior isn't mimicked when calling an ENC, which is invoked only once with the agent's full node name.
>     * Note 3: If no matching node definition can be found with the node's name, Puppet will try one last time with a node name of `default`; most users include a `node default {}` statement in their site.pp file. This behavior isn't mimicked when calling an ENC.

