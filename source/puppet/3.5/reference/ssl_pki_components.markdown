---
layout: default
title: "SSL Internals: Components of Puppet's PKI"
---

[cert_sign]: TODO
[ssl_basics]: TODO
[autosigning]: TODO
[csr_attributes]: TODO
[external_ca]: TODO
[agent_web_server]: todo
[replace_expired_certificate]: todo
[attributes_and_extensions]: todo
[ssldir]: todo
[https_wiki]: todo
[http_endpoints]: /references/3.stable/developer/file.http_api_index.html
[replace_mangled_certificate]: todo
[sign_alt_names]: todo
[autosign]: todo
[multi_master]: /guides/scaling_multiple_masters.html#centralize-the-certificate-authority

[wiki_pki]: http://en.wikipedia.org/wiki/Public_key_infrastructure

[dns_alt_names]: /references/3.latest/configuration.html#dnsaltnames
[ssl_client_header]: /references/3.latest/configuration.html#sslclientheader
[ssl_client_verify_header]: /references/3.latest/configuration.html#sslclientverifyheader
[masterport]: /references/3.latest/configuration.html#masterport
[certname]: /references/3.latest/configuration.html#certname
[cadir]: /references/3.latest/configuration.html#cadir
[cacrl]: /references/3.latest/configuration.html#cacrl
[cacert]: /references/3.latest/configuration.html#cacert
[cakey]: /references/3.latest/configuration.html#cakey
[capub]: /references/3.latest/configuration.html#capub
[cert_inventory]: /references/3.latest/configuration.html#certinventory
[caprivatedir]: /references/3.latest/configuration.html#caprivatedir
[capass]: /references/3.latest/configuration.html#capass
[csrdir]: /references/3.latest/configuration.html#csrdir
[serial]: /references/3.latest/configuration.html#serial
[signeddir]: /references/3.latest/configuration.html#signeddir
[requestdir]: /references/3.latest/configuration.html#requestdir
[hostcsr]: /references/3.latest/configuration.html#hostcsr
[certdir]: /references/3.latest/configuration.html#certdir
[hostcert]: /references/3.latest/configuration.html#hostcert
[localcacert]: /references/3.latest/configuration.html#localcacert
[hostcrl]: /references/3.latest/configuration.html#hostcrl
[privatedir]: /references/3.latest/configuration.html#privatedir
[passfile]: /references/3.latest/configuration.html#passfile
[privatekeydir]: /references/3.latest/configuration.html#privatekeydir
[hostprivkey]: /references/3.latest/configuration.html#hostprivkey
[publickeydir]: /references/3.latest/configuration.html#publickeydir
[hostpubkey]: /references/3.latest/configuration.html#hostpubkey
[rest_authconfig]: /references/3.latest/configuration.html#restauthconfig

[authorization]: todo
[auth_conf]: todo

[ssl_background]: todo
[ca]: todo
[cert_manage]: todo
[cert_autosign]: todo
[ca_name]: /references/latest/configuration.html#caname
[anatomy_subject]: todo
[background_keypair]: todo
[puppet.conf]: todo
[anatomy_altnames]: todo
[background_csr]: todo
[ca_server]: todo
[server]: todo
[waitforcert]: todo
[background_crl]: todo

<!-- The following references are not used in the text:
[cert_sign]:
[ssl_basics]:
[autosigning]:
[agent_web_server]:
[replace_expired_certificate]:
[https_wiki]:
[http_endpoints]:
[replace_mangled_certificate]:
[sign_alt_names]:
[autosign]:
[wiki_pki]:
[ssl_client_header]:
[ssl_client_verify_header]:
[masterport]:
[rest_authconfig]:
[authorization]:
-->

<!-- The following references are not used in the text:
[ssl_basics]:
[autosigning]:
[csr_attributes]:
[replace_expired_certificate]:
[attributes_and_extensions]:
[http_endpoints]:
[replace_mangled_certificate]:
[sign_alt_names]:
[wiki_pki]:
[dns_alt_names]:
[certname]:
[requestdir]:
[hostcsr]:
[certdir]:
[hostcert]:
[localcacert]:
[hostcrl]:
[privatedir]:
[passfile]:
[privatekeydir]:
[hostprivkey]:
[publickeydir]:
[hostpubkey]:
-->

<!-- The following references are not used in the text:
[http_endpoints]:
-->


Since Puppet secures its network communications with HTTPS, it requires an X.509 public key infrastructure (PKI) certificates to secure traffic and authenticate nodes. To fill this need, it includes a built-in CA and certificate distribution infrastructure. (Alternately, an [external CA][external_ca] can be used.)

This page describes the built-in certificate infrastructure, as well as where the various Puppet components locate their certificate data and how they use it.

> **Note:** This page assumes basic familiarity with client-authenticated HTTPS, SSL, X.509 certificates, and public key cryptography. If you need a refresher on any of these, please visit our [background series on SSL topics][ssl_background].



Backend Implementation
-----

In this version of Puppet, all certificate and encryption functionality is based on OpenSSL, via the Ruby OpenSSL bindings.

The exact version of OpenSSL used will depend on your system. Puppet Enterprise packages its own version; open source Puppet installations will use the system version.



The Puppet CA
-----

Puppet's certificate authority (CA) resides on **one specially designated puppet master server.** It consists of:

* A collection of data files on disk
* Several network services
* A multi-purpose command-line tool
* A web interface for signing certificates (PE-only)
* Optional rules for automatically signing certain certificates

Generally, every Puppet deployment has its own unique CA, which isn't shared with other deployments.

![A drawing of the CA's components](./images/ssl_internals_ca_components.jpg)

> ### Why Just One CA?
>
> **Reason one:** All certificates in a deployment must be signed by the same CA private key. (Mostly.)
>
> If multiple CA certificates were in use, the deployment would be split, and nodes using one CA would be unable to communicate with nodes using the other. This is a limitation in Puppet's SSL handling.
>
> (There is one strict situation where multiple CAs can be used; see the [external CA docs][external_ca] for details.)
>
> **Reason two:** Splitting the CA's brain can lead to data corruption.
>
> It's possible to distribute the same CA private key to multiple servers and have them both provide CA services, which will still allow all nodes to communicate with each other. However, this causes the CA to have a split brain.
>
> The CA is the canonical source of knowledge about which certificates exist, which certificates have been revoked, and what the serial number of the next certificate should be. If more than one server acts as CA, their memories about the deployment's certificates will diverge. This can result in duplicate serial numbers (which makes certificates difficult to revoke), missing revoked items in the CRL, inability to serve certificates to nodes that requested them from the other CA, and more.
>
> This can be mitigated by using spaced-out initial serial numbers on multiple CAs and regularly syncing certificate data and reconciling CRLs and inventory, or by keeping CA data on an NFS share. However, centralizing the CA is easier and less prone to data corruption.

### Disabling the CA

A puppet master server generally assumes it is the only puppet master in a deployment, and that it will have to serve as the CA. If it's actually one of many, it must be configured to not be a CA.

This is controlled by the [`ca` setting][ca], which defaults to `true`. Set it to `false` to disable CA functions on a puppet master.

    # puppet.conf
    [master]
    ca = false

You will also have to direct all CA traffic to the one CA server. Several options for this are described in the guide to [using multiple puppet masters][multi_master].

### Initializing the CA

If the [`ca` setting][ca] is set to true and the required CA data files (see below) don't already exist, Puppet will automatically create a CA when certain actions are attempted. This initializes the data files and allows the network services and CLI tools to be used.

* When Puppet Enterprise installs the puppet master role, it creates a CA automatically. No further action is needed.
* When a WEBrick puppet master is started (with the `puppet master` command), it will create a CA if one doesn't exist yet and `ca = true`.
    * Note that the behavior of puppet master processes managed by a front-end web server in this situation is undefined, and might result in a race between two processes that both think they need to create a CA. When bootstrapping a new puppet master, it's best to briefly start and stop a WEBrick process first with, e.g., `sudo puppet master --verbose --no-daemonize` followed by `^C` after a short delay.
* When any of `puppet cert`'s actions are used, it will create a CA if one doesn't exist yet. (The puppet cert subcommand always forces `ca = true`; it shouldn't be used on non-CA nodes.)

When initializing a new CA, the [`ca_name`][ca_name] setting is used to choose the common name (CN) used for the certificate's [Subject][anatomy_subject].

### The CA's Data Files

[inpage_ca_data]: #the-cas-data-files

The CA stores its data in a subdirectory of Puppet's [`ssldir`][ssldir]. (It reads its `ssldir` value from the `[master]` section of puppet.conf.)

All of the directories and unique files in the ssldir have common default names, but these names can be overridden by settings in puppet.conf. In practice, almost no one overrides these, but the relevant settings are mentioned here for completeness.

All of the CA's files must be owned by the user that the puppet master process runs as (usually `puppet` for open source or `pe-puppet` for Puppet Enterprise). The ownership and mode of the files are managed by the puppet master process when it starts up.

The CA's files are laid out in the ssldir as follows:

* `ca` _(directory)_ --- Contains all CA infrastructure. This directory must only exist on the CA puppet master server, and only if you are using Puppet's built-in CA. Mode: 0770. Setting: [`cadir`][cadir].
    * `ca_crl.pem` --- The master copy of the certificate revocation list (CRL) managed by the CA. Mode: 0664. Setting: [`cacrl`][cacrl].
    * `ca_crt.pem` --- The CA's self-signed certificate, which is provided to any node on request. Mode: 0660. Setting: [`cacert`][cacert].
    * `ca_key.pem` --- The CA's private key. Tied for most security-critical file in the entire Puppet certificate infrastructure. Mode: 0660. Setting: [`cakey`][cakey].
    * `ca_pub.pem` --- The CA's public key. Mode: Not specified. Setting: [`capub`][capub].
    * `inventory.txt` --- A list of all certificates the CA has signed, along with their serial numbers and validity periods. Mode: 0644. Setting: [`cert_inventory`][cert_inventory].
    * `private` _(directory)_ --- Contains only one file. Mode: 0770. Setting: [`caprivatedir`][caprivatedir].
        * `ca.pass` --- The (randomly generated) password to the CA's private key. Tied for most security-critical file in the entire Puppet certificate infrastructure. Mode: 0660. Setting: [`capass`][capass].
    * `requests` _(directory)_ --- Contains certificate signing requests (CSRs) that were received but have not yet been signed. The CA deletes CSRs from this directory after signing them. Mode: Not specified. Setting: [`csrdir`][csrdir].
        * `<name>.pem` --- Individual CSR files.
    * `serial` --- A file containing the serial number for the next certificate the CA will sign. This is incremented with each new certificate signed. Mode: 0644. Setting: [`serial`][serial].
    * `signed` _(directory)_ --- Contains copies of all certificates the CA has signed. Mode: 0770. Setting: [`signeddir`][signeddir].
        * `<name>.pem` --- Individual signed certificate files.

### The CA's Network Services

The puppet master provides an HTTPS API that allows agent nodes to retrieve catalogs, submit reports, and more.  When also acting as a CA (`ca = true` in puppet.conf), it adds four additional CA-related HTTPS endpoints. Agent nodes (and other kinds of clients) can use these endpoints to interact with the CA.

#### Submitting Certificate Signing Requests

The [`certificate_request`][http_csr] endpoint can accept incoming CSRs from agent nodes. When a CSR arrives, the puppet master will put it into the `$ssldir/ca/requests` directory, where it will await decision.

This endpoint can also return any previously received CSR, when requested by name. Agent nodes use this before submitting a CSR, to check whether they have already submitted one.

#### Retrieving Signed Certificates

The [`certificate`][http_cert] endpoint can return any certificate by name from the `$ssldir/ca/signed` directory. It can also return the CA certificate when a name of `ca` is requested.

When first initialized, agent nodes use this endpoint to retrieve a copy of the CA certificate, which they will use to validate all future HTTPS contact with the puppet master server.

After submitting a CSR, an agent node will repeatedly hit this endpoint until it successfully retrieves a cert it can use. Until it receives one, it cannot request a configuration catalog from the puppet master.

#### Retrieving the CRL

The [`certificate_revocation_list`][http_crl] endpoint returns a copy of the curent CRL.

Agents will only hit this endpoint if they do not already have a cached copy of the CRL. This happens if the node has just retrieved its certificate for the first time, or if the local copy of the CRL has been deleted.

Thus, if you need to update the CRL, you must delete the cached CRL file on every agent node.

#### Controlling the CA

The [`certificate_status`][http_status] endpoint can control the CA itself, and has multiple functions:

* It can return information about any existing certificate or pending CSR.
* It can list the combined set of all existing certificates and pending CSRs.
* It can sign certificates.
* It can revoke and delete certificates.

This is useful for building alternate interfaces to the CA's signing and revocation tools, which can take the place of the `puppet cert` subcommand. The Puppet Enterprise console's request manager page is the main example.

#### Security

Like all of the puppet master's HTTPS services, access to the CA endpoints can be controlled with the [auth.conf][auth_conf] file. Each one has default access rules, which most users should leave in place.

* The `certificate_request` and `certificate` endpoints are available without authentication required, since agent nodes need to access them before they have certificates. (If they required authentication, it would cause a chicken/egg problem.)
* The `certificate_revocation_list` endpoint requires authentication, but is open to all authenticated nodes.
* The `certificate_status` endpoint needs higher security, since it can control the CA. In open source Puppet, it is closed to all nodes by default. In Puppet Enterprise, it is only open to the PE console's certificate, since the console's request manager page depends on it.


[http_csr]: /references/latest/developer/file.http_certificate_request.html
[http_cert]: /references/latest/developer/file.http_certificate.html
[http_status]: /references/latest/developer/file.http_certificate_status.html
[http_crl]: /references/latest/developer/file.http_certificate_revocation_list.html


### The `puppet cert` Command-Line Tool

Admin users with sudo permissions on the CA puppet master server can manage the Puppet CA via [the `puppet cert` subcommand](/references/latest/man/cert.html). It allows a user to:

* Examine certificates and pending CSRs
* Sign new certificates
* Revoke and "clean" (delete) certificates
* Recover from a corrupted inventory file

Signing a certificate will create a file in the `$ssldir/ca/signed/` directory and delete the corresponding CSR from the `$ssldir/ca/requests/` directory. Revoking a certificate will add it to the CRL. Cleaning a certificate will add it to the CRL and remove its file from the `$ssldir/ca/signed/` directory.

* For practical details, see the documentation on [signing and managing certificates][cert_manage].

> **Note:** Puppet also includes several confusing subcommands that look like they control the CA: `puppet certificate`, `puppet certificate_request`, and `puppet certificate_revocation_list`. These were an experimental interface to some of the SSL-related subsystems, and they never became particularly useful. Today, nearly all CA management should happen with the `puppet cert` subcommand alone.

### The Puppet Enterprise Request Manager

In Puppet Enterprise, the PE console includes a page for viewing and signing pending certificate requests. It provides a friendlier interface for the most common subset of `puppet cert`'s functionality.

* For more details, see [the PE manual's page on node request management](/pe/latest/console_cert_mgmt.html).

### Autosigning

When the CA receives a new CSR via its `certificate_request` endpoint, it may optionally perform some check to see whether the certificate can be automatically signed. If the answer is affirmative, it will autosign the certificate and create a file for it in the `$ssldir/ca/signed/` directory; if not, it will leave the CSR in the `$ssldir/ca/requests/` directory to be either manually signed or deleted.

The autosigning check may be a simple config file or an external policy executable.

* For configuration details, see the documentation on [autosigning certificates][cert_autosign].



Agent and Master Certificate Infrastructure
-----

The puppet agent and puppet master services both use a similar structure for their certificate data, and they interact in the CA in roughly the same way. (Their usage of certificates differs, but the infrastructure is the same.)


### Required Credentials

For normal Puppet operations, any agent or master process requires the following credentials:

* A [key pair][background_keypair] unique to this node. The private key remains private; the public key becomes part of the certificate.
* A local copy of the CA certificate. Used to validate certificates presented by other members of the deployment.
* A certificate signed by the deployment's CA. Used to identify the node when connecting to other members of the deployment.
    * The certificate must contain the node's own public key.
    * The [subject CN][anatomy_subject] must match the value of the process's [`certname` setting][certname]. (The value of the setting is read from the appropriate config block in [puppet.conf][].)
    * If used by a puppet master, the hostname the master provides services at must either match the subject CN or be included in the cert's list of [alternative DNS names][anatomy_altnames].
* A copy of the CA's certificate revocation list (CRL). Used to validate certificates presented by other members of the deployment.

An example of a certificate usable by an agent or master, with its various pieces of metadata identified, can be seen on our page about [certificate anatomy][anatomy].

### Initializing Agents and Masters

If the credentials above aren't present when an agent or master process is started, Puppet will usually attempt to create them and/or request them from the CA.

#### CSR Contents

When a node generates a [CSR][background_csr] to submit to the CA, it will check its configuration to decide what information to insert into the request.

* The [`certname` setting][certname] determines the [Subject CN][anatomy_subject] that will be requested. It also dictates the filenames for most of the node's SSL-related files.
* The [`dns_alt_names` setting][dns_alt_names] determines any [alternative DNS names][anatomy_altnames] that will be requested. When using the CA tools to list and sign certificates, CSRs with alternative names are treated specially, and require an explicit override before they can be signed.
* The config file identified by the [`csr_attributes` setting][csr_attributes] determines any custom CSR attributes or certificate extensions that will be requested. (Only used in Puppet 3.4.0 and later.) More details are available at the documentation for [CSR attributes and certificate extensions][attributes_and_extensions].

#### Initializing Agents

When an agent node begins a Puppet run, it checks to make sure it has the necessary credentials, as listed above. If it doesn't have them, it will take action to acquire them:

* If the key pair files aren't present, the agent will generate new ones and place them at `$ssldir/private_keys/<certname>.pem` and `$ssldir/public_keys/<certname>.pem`.
* If a local copy of the CA certificate is not present, the agent will contact the CA puppet master specified in the [`ca_server` setting][ca_server] (defaults to the value of the [`server` setting][server]) and request the certificate named `ca`.
* If a certificate is not present, the agent will contact the CA server and request a certificate named `<certname>`.
    * If the CA has signed that certificate, it will return it; the agent will store it at `$ssldir/certs/<certname>.pem`.
        * If the agent receives a cert which doesn't match the agent's private key, it will exit with a fatal error. This generally indicates a duplicate certname in the deployment or a rebuilt node whose old certificate was not cleaned. An admin user will have to resolve the conflict, usually by cleaning the offending cert on the CA and deleting the agent's entire `ssldir`.
    * If the CA hasn't signed a certificate for that agent, it will return a not found error. This may mean the agent has requested a cert but an admin user hasn't signed it yet, or it may mean the agent has never requested a cert. To figure out which is the case, the agent will check for an existing [CSR][background_csr] in two places: locally at `$ssldir/certificate_requests/<certname>.pem`, and remotely on the CA server.
        * If it finds an existing CSR in either place, it will either continue to request a certificate (at the interval specified by the [`waitforcert` setting][waitforcert]; defaults to `2m`) or exit (if `waitforcert = 0`).
        * If it _doesn't_ find an existing CSR, it will generate a CSR and submit it to the CA, then make another attempt to request a certificate.
* If a local copy of the [CRL][background_crl] is not present, the agent will contact the CA server and request it.

This process of credential acquisition is illustrated below:

![A diagram of the process of acquiring agent credentials, as described above.][agent_credentials]

[agent_credentials]: ./images/ssl_internals_agent_credentials.jpg

#### Initializing CA Puppet Masters

When a CA puppet master starts up, it checks to make sure it has the necessary credentials, as listed above. If it doesn't have them, it will take action to acquire them. This mostly resembles the agent process described above.

**Unlike an agent node,** a CA puppet master will briefly take control of the CA and cause it to sign its certificate. This allows the CA master to bootstrap itself without waiting for an admin user to sign its certificate request.

#### Initializing Non-CA Puppet Masters

A Non-CA puppet master cannot acquire its own credentials on startup. It will partially attempt to acquire them, by generating a key pair and a CSR, but it will be unable to submit the CSR to the CA server, or retrieve the CA certificate or CRL.

Instead, a non-CA master's credentials can be acquired by doing a puppet agent run, with an agent process configured with the values the master certificate needs. This generally entails running `puppet agent --test --dns_alt_names=list,of,names`, logging into the CA master to sign the certificate, then running `puppet agent --test` again.

Unfortunately, if the non-CA master process is started before its credentials are in place, it will leave behind partial credentials that will prevent using puppet agent to retrieve good ones. (A local CSR will be present, which will block the agent from submitting a legit CSR.) Additionally, if a master process is started without `ca = false` being set in puppet.conf, it will create a second, competing CA that will prevent good credentials from being retrieved.

In both cases, you should delete the entire `ssldir` on the server, make sure `ca = false` is set, then run an agent process with the necessary alt names set.


### SSL Data Files (`ssldir`)

The agent and master services store their credential data in Puppet's [`ssldir`][ssldir]. They read their `ssldir` values from the `[agent]` and `[master]` sections of puppet.conf, respectively.

All of the directories and unique files in the ssldir have common default names, but these names can be overridden by settings in puppet.conf. In practice, almost no one overrides these, but the relevant settings are mentioned here for completeness.

> Note: Node-specific files are identified by [`certname`][certname] value. On a server that acts as a puppet master, any master and agent processes that share a certname will use the same certificate and private key files. This is generally considered fine, although the ownership of the files may churn a bit.

All of the SSL-relevant files used by a Puppet service must be owned by the user that the service runs as. For puppet agent, this is usually `root` or `Administrator`. For puppet master, this is usually `puppet` for open source or `pe-puppet` for Puppet Enterprise. The permissions mode of the `ssldir` should be 0771. The ownership and mode of the `ssldir` and its contents are managed by the Puppet processes when they start up.

The layout of the ssldir is as follows:

* `ca` _(directory)_ --- Contains CA infrastructure. On normal agent nodes and non-CA puppet masters, this directory should not exist. Its contents are [described above][inpage_ca_data].
* `certificate_requests` _(directory)_ --- Contains any CSRs generated by this node in preparation for submission to the CA. CSRs persist in this directory even after they have been submitted and signed. Mode: Not specified. Setting: [`requestdir`][requestdir].
    * `<certname>.pem` --- This node's CSR. Mode: 0644. Setting: [`hostcsr`][hostcsr].
* `certs` _(directory)_ --- Contains any signed certificates present on this node. This includes the node's own certificate, as well as a copy of the CA certificate (for use when validating certificates presented by other nodes). Mode: Not specified. Setting: [`certdir`][certdir].
    * `<certname>.pem` --- This node's certificate. Mode: 0644. Setting: [`hostcert`][hostcert].
    * `ca.pem` --- A local copy of the CA certificate. Mode: 0644. Setting: [`localcacert`][localcacert].
* `crl.pem` --- A copy of the certificate revocation list (CRL) retrieved from the CA, for use by puppet agent or puppet master. Mode: 0644. Setting: [`hostcrl`][hostcrl].
* `private` _(directory)_ --- Usually does not contain any files. Mode: 0750. Setting: [`privatedir`][privatedir].
    * `password` --- The password to a node's private key. Usually not present. The conditions in which this file would exist are not defined. Mode: 0640. Setting: [`passfile`][passfile].
* `private_keys` _(directory)_ --- Contains any private keys present on this node. This should generally only include the node's own private key, although on the CA it may also contain any private keys created by the `puppet cert generate` command. It will never contain the private key for the CA certificate. Mode: 0750. Setting: [`privatekeydir`][privatekeydir].
    * `<certname>.pem` --- This node's private key. Mode: 0600. Setting: [`hostprivkey`][hostprivkey].
* `public_keys` _(directory)_ --- Contains any public keys generated by this node in preparation for generating a CSR. Mode: Not specified. Setting: [`publickeydir`][publickeydir].
    * `<certname>.pem` --- This node's public key. Mode: 0644. Setting: [`hostpubkey`][hostpubkey].



HTTPS Authentication and Authorization
-----

Puppet's normal operation involves agent nodes making HTTPS requests to one or more puppet master servers, which respond with configuration data tailored to each node.

During this communication, agent nodes use the master's certificate to ensure that the configurations they fetch are legitimate, and masters use the agent's certificate to ensure the node is authorized to receive configurations.

### Authenticated and Unauthenticated Requests

In nearly all HTTPS requests, the agent will authenticate the master. The one exception is when initially retrieving the CA certificate, since the agent can't authenticate the master until it has the CA cert.

The master will authenticate the agent as specified by its [auth.conf][] file. By default, it will allow unauthenticated access to the `certificate` and `certificate_request` HTTPS endpoints, and require authentication for all other requests.


### Authenticating the Puppet Master




### Client Authentication

