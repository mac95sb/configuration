# Outbound mail

The Mac's built-in Postfix sends mail directly to recipient mail servers as
`mail.maclong.dev`. It does not receive internet mail or use an external SMTP
relay.

Only programs running on this Mac can submit messages. Postfix listens on the
loopback address and rejects connections from the local network and internet.
Messages sent with macOS `mail` use `noreply@maclong.dev`; applications can use
an address on their own authorised domain.

SPF and DMARC identify permitted mail, while opportunistic TLS encrypts delivery
when the recipient supports it. The built-in mail stack does not add DKIM
signatures, and the residential reverse-DNS record does not match the mail
hostname, so some providers may reject messages or place them in spam.
