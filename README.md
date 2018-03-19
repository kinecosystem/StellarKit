# StellarKit

A framework for interacting with the [Stellar](https://www.stellar.org) blockchain network.  StellarKit communicates with Horizon nodes.

## <a name="concepts"></a>Concepts

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

StellarKit exposes `Stellar`, which is a stateless struct with static methods.  In addition to method-specific parameters, each method takes a parameter called `node`, of type `Stellar.Node`.

##### Stellar.Node

```Swift
struct Node {
    let baseURL: URL
    let networkId: NetworkId
}
```

* `baseURL` is the URL of the Horizon node.  It is used to construct URLs for Horizon API end-points.
* `networkId` identifies the Stellar network to which the Horizon node belongs.

##### NetworkId

```Swift
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

##### Account

```Swift
public protocol Account {
    var publicKey: String? { get }

    var sign: ((Data) throws -> Data)? { get }
}
```

`StellarKit` does not contain an implementation of the account concept.  Instead, it relies on the `Account` protocol to provide the required functionality.

* `publicKey` is the string representation of the account's public key, as described in the <a href="#concepts">Concepts</a> section.
* `sign` is a closure which accepts a Data object to be signed, and returns the signature.

This design allows `StellarKit` to remain agnostic with respect to encryption implementations and account storage mechanisms.  It also avoids 3rd-party dependencies, as iOS (and macos) have no native implementations of ED25519 algorithms.

##### Promises

Most `Stellar` methods return a `Promise`, which is an abstraction over asynchronous processes which allows for chaining actions.  `StellarKit` uses a minimal implementation provided by [KinUtil](https://github.com/kinfoundation/kin-util-ios), to avoid 3rd-party dependencies.

## Functionality

At this time, `StellarKit` supports the following operations:

* making payments
* retrieving balances
* trusting non-native assets
* retrieving account details
* observing changes

Inline documentation describes how to use each method.

## Getting Started

The Stellar network is designed for the usage of non-native assets.  This section describes how to prepare an account to send and receive such assets.

1. [Create the account](https://www.stellar.org/developers/horizon/reference/resources/operation.html#create-account) on the network.

   This operation requires a funding account which has sufficient Lumens to provide the necessary reserve.  It is customary to provide extra to allow the account to pay transaction fees.  This operation is typically performed by a service, and is outside the scope of this framework.

2. [Trust the asset](https://www.stellar.org/developers/horizon/reference/resources/operation.html#change-trust).

   This operation is performed by `Stellar.trust(...)`.

   ```Swift
   public static func trust(asset: Asset,
                            account: Account,
                            configuration: Configuration) -> Promise<String>
   ```
