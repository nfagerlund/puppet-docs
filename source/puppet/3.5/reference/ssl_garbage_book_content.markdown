old stuff
---------------

### Default PKI Requirements

By default, Puppet is configured to require the following infrastructure:

* All certificates in use across the Puppet deployment **must** be signed by the same certificate authority (CA). (However, if you are using an [external CA][external_ca], it is possible to use two CAs instead of one.)
* All agent nodes **must** have a signed certificate. If they do not, they cannot request configuration data, although they can download the CA's credentials and request a certificate. It isn't strictly necessary for each node certificate to be unique, but it is highly recommended.
* Any puppet master server must have a signed certificate. Additionally, the hostname at which agent nodes contact it **must** be present in the certificate, either as the Subject CN value or as one of the Subject Alternative Name (DNS) values.

Puppet has built-in CA tools and certificate request tools to fulfill these requirements; alternately, an external CA can fulfill them. For details on how to issue certificates, see [Signing and Managing Certificates with Puppet's CA][cert_sign].

### Certificate Roles: Agent/Master and CA

There is essentially no difference between an agent certificate and a puppet master certificate. They both must have CA:FALSE in their "X509v3 Basic Constraints" subsection, and they both may contain one or more alternate DNS names.

This means that a puppet master certificate may also be used as a puppet agent certificate. A puppet master server may use puppet agent to fetch a catalog and configure itself; this entails contacting itself over HTTPS, presenting its certificate to itself to verify that it can provide services, presenting its certificate to itself to verify that it can access services, accepting the certificate both times, and carrying on as normal. By default, the puppet master would use the same copy of the certificate both times; however, it's also possible to configure the puppet master and puppet agent processes to use different `ssldir`s, by specifying different values for the setting in the `[agent]` and `[master]` config blocks. In this case, you would also need to specify distinct `certname` values in each block, since the CA will only permit one certificate to use a given certname.

By contrast, the CA certificate can only be used to sign certificates; it cannot be used to request a catalog or to provide services as a puppet master.

### The CA Puppet Master Server

Since the CA certificate cannot be used to provide services, agents never communicate directly with the CA; CA-related traffic passes through a puppet master, which may invoke CA functionality at certain times.

A master that accepts traffic on behalf of the Puppet CA is referred to as a "CA puppet master." A CA puppet master can:

* Accept CSRs from not-yet-authorized clients and store them for review
* Trigger autosigning on received CSRs, if configured (see [the Configuring Autosigning page][autosign])
* Serve existing signed certificates (including the CA certificate) to clients
* Serve a copy of the CRL to clients
* Serve information about certificate status to specifically authorized clients
* Allow specifically authorized clients to sign or revoke certificates

This refers only to the services the puppet master process provides over the network. In addition, a user with shell access and superuser privileges on the puppet master server can use the `puppet cert` command line tool to view certificate information and sign/revoke certificates. For details, see [Signing and Managing Certificates][cert_sign].



HTTPS
-----

Network communication between agent nodes and puppet masters happens over industry-standard [HTTPS][https_wiki], which wraps the HTTP protocol with TLS/SSL.

* Most of Puppet's traffic also requires client authentication, so it behaves somewhat differently from most HTTPS on the public internet.
* Puppet's traffic is usually on port 8140 (configurable with the [`masterport` setting][masterport]) instead of the default web HTTPS port of 443.

### Encryption

In HTTPS, all traffic is encrypted by SSL. This includes header information and the requested URL path --- there is no way to tell what the client requested until the request is decrypted. This provides in-transit protection for all of Puppet's traffic, so that eavesdroppers on the network cannot decrypt requests or replies.

Technically, the keys embedded in certificates are not used for traffic encryption; they are used to negotiate the secure exchange of a temporary key, which is then used for traffic encryption.

### Server Authentication

> **Note:** In general, "server" means either the puppet master server or whatever proxy is terminating SSL for it (see the section on SSL termination below). However, this can be reversed when using [puppet agent's web server][agent_web_server].

In SSL, a server must present a valid certificate (for which it possesses the corresponding private key) when clients connect to it. The client will use their copy of the CA certificate to validate the signature on the server's certificate. This allows clients to verify that the server is who it claims to be.

In human-centered over-the-internet HTTPS, the user of a client is presented with a verified organization name, and must use social knowledge about that organization to decide whether to trust the connection.

In Puppet, clients are configured ahead of time to connect to the server at a particular hostname. When presented with the certificate, they will check both the certname (Subject CN) and any alternate DNS names (X509v3 Subject Alternative Name), all of which have presumably been verified by the CA before signing the certificate. If the hostname the client reached the server at is included in that list of verified names, the client will treat the server as a trustworthy puppet master. If not, the client will reject the connection.

This means that a man-in-the-middle attacker cannot simply intercept an agent request and impersonate a puppet master; they would need the private key for a puppet master certificate that includes the hostname they are impersonating.

### Client Authentication

> **Note:** In general, "client" means the puppet agent application when contacting a puppet master server. However, this can be reversed when using [puppet agent's web server][agent_web_server].

Client authentication is an additional security measure available in TLS/SSL. It is not used by most HTTPS traffic on the public internet.

In client-authenticated SSL, the client must also present a valid certificate when connecting to a server. The client's certificate will be validated by the server to verify the client's identity. If the server disbelieves the client's identity, or if the identity is valid but not authorized to access a given resource, the server can reject the connection.

In Puppet's case, this means an agent node must have a signed certificate in order to access most of the services provided by the puppet master server. The list of service endpoints requiring client authentication can be configured in auth.conf; see below. By default, services involving configuration data (catalogs, facts, file content, etc.) require client auth, but unauthenticated clients can submit CSRs.

Once the client is authenticated, the server will also check to make sure the client is _authorized_ to access any given service. See ["Authorization"][authorization] below.

### Revoked Certificates

The Puppet CA maintains a certificate revocation list (CRL). This is a document that identifies certificates that are no longer trusted.

Clients regularly retrieve a copy of the CRL from the CA puppet master. (TODO: find out when.) A CA puppet master should already have access to the CRL; non-CA puppet masters must either regularly run puppet agent targeting a CA puppet master, or must have the CRL regularly deployed by some out-of-band process. (If you are using an external CA, you must distribute this file manually to all interested nodes.) Any SSL-terminating front-end web server for a puppet master must be configured to use the puppet master's CRL, and most web servers must be restarted in order to reload a CRL that has been changed.

If any certificate presented to a client or server is included in the CRL, that client or server will reject the connection, regardless of any other bona-fides in that certificate.

### Puppet Master Web Servers and SSL Termination

Since a puppet master provides services over HTTPS, it must run a web server, accept inbound connections, and terminate SSL.

* When bootstrapping a puppet master or testing that it is properly configured, Puppet can run a built-in web server based on Ruby's WEBrick library.
    * In this case, the puppet master runs as a single Ruby process and terminates SSL itself, using the configured CA and puppet master certificates. (Note that the WEBrick server cannot be used in a production deployment, as it is unable to handle simultaneous connections.)
* When running normally, the puppet master should be managed by a web server capable of running Rack applications. (For example: Apache using the Passenger module, or Unicorn with Nginx proxying requests to it.)
    * In this case, a front-end web server terminates SSL and passes some information to the puppet master process. There may be multiple layers of proxying involved, and the verification information must persist through all of them.
    * The front-end server must be configured to use the Puppet CA certificate to validate client identities, and to identify itself using the puppet master's certificate.
    * After validating a request, the front-end will insert validation information into the HTTP request headers. (These modified headers should persist through any additional proxies being used.) Then, whatever Rack server is managing the puppet master will set special environment variables based on the request headers, following the common gateway interface (CGI) standard. The puppet master process will then read the environment variables to check whether the request was validated and to find the certname of the client.
    * The default headers / variable names are `X-Client-DN` / `HTTP_X_CLIENT_DN` and `X-Client-Verify` / `HTTP_X_CLIENT_VERIFY`; these can be changed by configuring the front-end web server to insert information into different headers, translating those headers to CGI-style environment variable names, then using those variable names as the new values for the [`ssl_client_header`][ssl_client_header] and [`ssl_client_verify_header`][ssl_client_verify_header] settings in the puppet master's puppet.conf.

### Differences Between Agent/Master and Standalone Puppet Apply

In an agent/master deployment, a node being managed by Puppet will use HTTPS to do most or all of the following:

* Download a node object (containing information like its environment) from a puppet master
* Download plugins (like custom facts, types, and providers) from a puppet master
* Upload its facts to a puppet master
* Download a catalog from a puppet master
* Upload its report to a puppet master

By default, nodes running puppet apply to locally compile and apply their catalogs won't contact a puppet master for any of these things. However, a puppet apply node can be configured to:

* Download plugins from a puppet master
* Upload its facts to a PuppetDB server
* Download exported resources from a PuppetDB server
* Upload its catalog to a PuppetDB server

All of these tasks would still use client-authenticated HTTPS, and the node would still require a signed certificate for them.



Authorization
-----

The agent's identity determines which services it is authorized to access on the master. These permissions are controlled by the master's HTTP authorization config file, `auth.conf`.

### Puppet Master's HTTP Endpoints

The puppet master provides several services over HTTPS. These network services make up the complete interface between the puppet master and any puppet agent nodes.

Each service is presented as an HTTP "endpoint." This is a fuzzy term


### auth.conf


> For practical information on auth.conf's syntax and capabilities, [see the auth.conf documentation][auth_conf].

The auth.conf file is an ordered list of access rules. Each request that comes in

The location of auth.conf defaults to `/etc/puppetlabs/puppet/auth.conf` for Puppet Enterprise and `/etc/puppet/auth.conf` for open source Puppet. It can be configured with the [`rest_authconfig` setting][rest_authconfig].


#### Authenticated and Unauthenticated Services

### Certname vs. Node Name

#### Referencing the Certname in Puppet Manifests

#### Referencing the Node Name in Puppet Manifests

### Secondary Validation Systems (fileserver.conf)


Authorizing Non-Puppet-Agent Clients
-----

### Issuing Certificates

### Using Client Certificates with Curl


Puppet Agent's Web Server (Puppet Kick)
-----

> **Deprecation note:** The agent web server is deprecated, mostly because opening a port on every agent node turned out to not be the best idea. It will be removed in a future version of Puppet. You can use MCollective with the Puppet plugin to trigger runs today, and we're investigating lighter weight orchestration solutions for triggering Puppet runs.

### Enabling the Agent Server

### Authorizing Access for the Run Service
