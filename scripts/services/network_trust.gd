extends RefCounted
## Official ISRG roots, bundled for Windows installations whose root store is not yet populated.
## Hostname/IP, expiry and the entire certificate chain are still verified by TLS.
static func options() -> TLSOptions:
	var certificate:=X509Certificate.new()
	if certificate.load("res://config/network_ca.pem")!=OK:return TLSOptions.client()
	return TLSOptions.client(certificate)
