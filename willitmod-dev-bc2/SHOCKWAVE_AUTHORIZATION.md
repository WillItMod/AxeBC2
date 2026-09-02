# ShockWave use clarification for AxeBC2

- Authorization status: `confirmed`
- Authorized scope: `official-bitcoinii-network`
- Received: 2026-09-02
- Source: written message from `BrokenMachine` in the BitcoinII Discord,
  identified to the release maintainer as a BitcoinII project developer
- Original evidence SHA-256:
  `0b1ef9f6957d351c0c947bbc260ddfb8d66988d3254ea0269382a13405f0ac1e`

The release maintainer received this written clarification:

> You're releasing a node software compiled from the Official BitcoinII source
> code in direct support of the BitcoinII network, the license restrictions
> therefor do not apply to you. You are free to proceed and publish the AxeBC2
> app. The ShockWave license restricts those who would take ShockWave from the
> BitcoinII source and deploy it in other "Alt Coins", other cryptocurrency
> blockchains, etc.

The original screenshot is retained by the release maintainer and is not
committed here, avoiding unrelated Discord account, channel, and interface
metadata. The SHA-256 above identifies that evidence without redistributing it.

## Release scope

This clarification is relied upon only for an image that:

1. compiles the official BitcoinII Core `v31.1.0` source without patching it;
2. pins upstream commit `8daaf7b12e71d3646eed787f040bf2899a69dc1c`;
3. preserves the upstream copyright and licence notices; and
4. operates solely as a BitcoinII node in direct support of the BitcoinII
   network.

It is not recorded as permission to extract, adapt, or deploy ShockWave on any
other coin, blockchain, distributed-ledger network, service, protocol, or
derivative implementation.

Upstream notices:

- <https://github.com/Bitcoin-II/BitcoinII-Core/blob/v31.1.0/README.md#license-pertaining-to-the-shockwave-difficulty-adjustment-algorithm>
- <https://github.com/Bitcoin-II/BitcoinII-Core/blob/v31.1.0/src/pow.cpp#L60-L118>
