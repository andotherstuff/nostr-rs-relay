# NIP-70 (Protected Tag) Support

## What is the goal

We want to implement NIP-70 support for protected tags. You can read the spec from the link in the resources section below to better understand what needs to be implemented from the Nostr protocol side.

## Protected Tags

When the "-" tag is present, that means the event is "protected".

A protected event is an event that can only be published to relays by its author. This is achieved by relays ensuring that the author is authenticated before publishing their own events or by just rejecting events with ["-"] outright.

The default behavior of a relay MUST be to reject any event that contains ["-"].

Relays that want to accept such events MUST first require that the client perform the NIP-42 AUTH flow and then check if the authenticated client has the same pubkey as the event being published and only accept the event in that case.

## High level requirements
- Add a configuration setting in `/config.toml` to turn on/off support for protected tags and ensure that if someone turns this setting on that we also require that the authentication setting is turned on.
- The relay should attempt to authenticate users that attempt to publish events containing a "-" (protected) tag and reject any events with that tag from non-authenticated users.

## References
[NIP-70: Protected Tag](https://github.com/nostr-protocol/nips/blob/master/70.md)
[NIP-42: Authentication](https://github.com/nostr-protocol/nips/blob/master/42.md)

