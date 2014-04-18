---
layout: default
title: "SSL: X.509 Certificate Attributes Used by Puppet"
---



X.509 certificates can have many kinds of data embedded, but Puppet only uses a subset of this data.

* **Certname:** Puppet uses the CN ("common name") portion of the Subject field as the unique identifier for each certificate. Within Puppet, this is often referred to as the "certname" to distinguish it from other forms of identity.
    * When a puppet agent node or puppet master is requesting a certificate, it uses its [`certname` setting][certname] (which defaults to the node's fully qualified domain name) as the requested Subject CN. If a node's `certname` setting is changed after it already has a certificate, it assumes that certificate belongs to someone else and will request a new certificate with the new name.
    * Puppet does not use other portions of the Subject field (C, ST, O, OU, etc.) to distinguish nodes from each other. In certificates issued by Puppet's built-in CA, those fields are left blank and only the CN is specified.
* **Alternate DNS names:** In the "X509v3 extensions" section of the certificate, the "X509v3 Subject Alternative Name" subsection may include any number of "DNS:" entries, each of which should be a hostname. These entries allow the bearer of the certificate to present itself under any of these host names when acting as a server, which enables multiple puppet masters to have distinctive certnames but provide services at a common generic hostname (like puppet.example.com) behind a load balancer or proxy.
    * Alternate DNS names must be included in the original CSR, before the certificate is signed. When constructing a CSR, a Puppet node will use its [`dns_alt_names` setting][dns_alt_names] to decide which alternate names to request (if any). If a certificate is signed without the alternate names it needs, you must [replace it][replace_mangled_certificate].
    * Since alternate names can allow a node to impersonate another node when acting as a server, they are treated specially by Puppet's CA tools. In the Signing Certificates reference, see the section on [signing certificates with DNS alt names][sign_alt_names] for more detail.
    * In general, acting as a server means being a puppet master, but see also the section on [puppet agent's web server][agent_web_server] below.
* **Validity:** Each certificate has a period for which it is valid, with a start date and an end date. Outside that period, any agent or master presented with that certificate will consider it invalid and reject the connection. Expired certificates will have to be [replaced][replace_expired_certificate].
    * The CA sets the validity period when it signs a new certificate, using the value of its `ca_ttl` setting (defaults to five years).
* **Public key:** The public key embedded in the certificate is used for encrypting communications and verifying that the bearer of the certificate possesses the corresponding private key.
* **Signature:** The CA's signature proves that the bearer of this certificate is authorized to use Puppet services and go by the certname or any alternate DNS names in that certificate.
* **Constraints and Key Usage:** In the "X509v3 extensions" section of the certificate, there are several subsections that determine how the certificate can be used:
    * In the "X509v3 Basic Constraints" subsection, the "CA" entry determines whether the certificate can sign other certificates. Every Puppet certificate except the CA certificate should have `CA:FALSE` set. The CA certificate should have `CA:TRUE`.
    * In the "X509v3 Key Usage" subsection, the CA certificate should have the "Certificate Sign" and "CRL Sign" abilities, and no others. All other certificates should have the "Digital Signature" and "Key Encipherment" abilities, and no others.
    * The "X509v3 Extended Key Usage" subsection should be absent from the CA certificate. In all other certificates, it should include "TLS Web Server Authentication" and "TLS Web Client Authentication," and no other abilities.
* **Arbitrary extensions:** These are only used in a limited fashion today. See the page on [CSR attributes and cert extensions][attributes_and_extensions] for details.

