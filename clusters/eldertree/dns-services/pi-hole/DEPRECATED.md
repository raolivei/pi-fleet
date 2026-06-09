# Deprecated — replaced by BIND9

Pi-hole removed in favor of `dns-services/bind` ([#232](https://github.com/raolivei/pi-fleet/issues/232)).

- Adblock was never used
- BIND sidecar did all `eldertree.local` + RFC2136 work

Helm chart retained at `helm/pi-hole/` for reference until a later cleanup PR deletes it.
