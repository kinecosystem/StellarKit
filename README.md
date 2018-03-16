# StellarKit

A framework for interacting with the [Stellar](https://www.stellar.org) blockchain network.  StellarKit communicates with Horizon nodes.

## Concepts

#### Accounts

Stellar represents an account as an `ED25519` key-pair.  The public key represents the account on the network, and the secret key is used only for signing transactions.

The textual representation of a public key uses the following format:

`G<base32 representation of key + 2 byte CRC>`

**Example:** `GCDXVSRN7TORSWS6N3FEHV3KUKGK4F74ZJDRENEAKVDWXIEFR5BOKMGK`

#### Assets

An asset represents a transferable unit.  Stellar uses a native unit, called a Lumen, which is used for paying transaction fees and account maintenance.  The network also supports non-native, or user-defined, assets, which are identified via a code and an issuer.

An asset issuer is an account which has been trusted to issue an asset.

#### Trust

In order to receive a non-native asset, an account must trust the issuer.  This allows multiple assets with the same code to coexist.

## Design

StellarKit exposes `Stellar`, which is a struct with static methods.  In addition to method-specific parameters, each method takes a parameter called `configuration`, of type `Stellar.Configuration`.

##### Stellar.Configuration

```
struct Configuration {
    let node: Node
    let asset: Asset
}
```

* `node` represents the Horizon node.
* `asset` defines the asset to be used by a method, if no asset is passed via its `asset` parameter.

##### Stellar.Node

```
struct Node {
    let baseURL: URL
    let networkId: NetworkId
}
```

* `baseURL` is the URL of the Horizon node.  It is used to construct URLs for Horizon API end-points.
* `networkId` identifies the Stellar network to which the Horizon node belongs.

##### NetworkId

```
enum NetworkId {
    case test
    case main
    case custom(String)
}
```

Stellar identifies a network via a pre-defined string.  The Stellar Development Foundation runs two public networks.  One is the live network, and the other is for testing.  Developers may establish private networks, using their own identifiers.

* `test` represents the Stellar Foundation's test net.
* `main` represents the Stellar Foundation's public (live) net.
* `custom` allows a user-defined identifier to be provided, to be used with private networks.
