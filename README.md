![CocoaPods Compatible](https://img.shields.io/cocoapods/v/SaltEdge-iOS-Swift.svg?style=flat)
[![Twitter URL](https://img.shields.io/twitter/url/https/twitter.com/fold_left.svg?style=social&label=Follow%20%40saltedge)](http://twitter.com/saltedge)

<p align="center">
  <a href="https://www.saltedge.com/products/spectre">
    <img src="https://raw.githubusercontent.com/saltedge/sca-identity-service-example/master/docs/images/saltedge_logo.png" alt="Salt Egde Logo" width="96" height="96">
  </a>
</p>

# iOS Example application

This application is a Proof Of Concept, designated to demonstrate (simulate) communication between Salt Edge API and Mobile Client.

## Requirements

- iOS 12.0+ / macOS 10.13+
- Swift 5+
  
# Salt Edge iOS / macOS Swift SDK

A handful of classes to help you interact with the Salt Edge API from your iOS / macOS app.
Last SDK version (3+) supports Salt Edge API v5.

## Requirements

- iOS 10.0+ / macOS 10.13+
- Swift 5+

## Installation via CocoaPods

#### Add the pod to your `Podfile`  

for Salt Edge API v5 use

```ruby
pod 'SaltEdge-iOS-Swift', '~> 3.5.1'
```

for Salt Edge API v4 (***Deprecated***) use 
```ruby
pod 'SaltEdge-iOS-Swift', '~> 1.1.2'
```

#### Install the pod

`$ pod install`

#### Import SDK into your app

`import SaltEdge`

## Init SDK

Replace the `appId`, `appSecret`.

To setup Salt Edge API, call in `AppDelegate.swift`:
```swift
SERequestManager.shared.set(appId: appId, appSecret: appSecret)
```

*Note*: You can find your `appId` and `appSecret` on your [secrets](https://www.saltedge.com/clients/profile/secrets) page (Eligible only for Salt Edge API).
`customerId` - is the unique identifier of the new customer.

## SERequestManager

A class designed with convenient methods for interacting with and querying the Salt Edge API. Contains methods for fetching entities (Connections, Transactions, Accounts, etc.), for requesting connect url for creating, reconnecting and refreshing Connections via a `SEWebView`, and also for creating Connections via the REST API.

Each successful request via `SERequestManager` returns `SEResponse` containing `data` and `meta`.

Each failed request returns standard Swift `Error` .

Use the manager to interact with the provided API:

```swift
let connectionParams = SEConnectionParams(
    consent: SEConsent(scopes: ["account_details", "transactions_details"]),
    countryCode: "XF",
    providerCode: "fakebank_simple_xf",
    credentials: ["login": "username", "password": "secret"]
)
SERequestManager.shared.createConnection(with: connectionParams) { response in
    switch response {
    case .success(let value):
        // value.data is a valid SEConnection
    case .failure(let error):
        // Handle error
    }
}
```

## Get customer secret

To access the Salt Edge SDK functionality, it is necсessary to get a [Customer secret](https://docs.saltedge.com/account_information/v5/#customers-create). To get a customer secret, you can make a request via `SERequestManager`.

After successful request, you should link the received customer secret with the request manager:

```swift
SERequestManager.shared.set(customerSecret: "received-customer-secret")
```

**Note:** You must save the received customer secret in you storage(e.g. UserDefaults) and for all future Salt Edge SDK usage, you should link the stored customer secret.

### Example

```swift
let defaults = UserDefaults.standard
if let secret = defaults.string(forKey: "customerSecret") {
    SERequestManager.shared.set(customerSecret: secret)
} else {
    let params = SECustomerParams(identifier: "your-customer-unique-id")
    SERequestManager.shared.createCustomer(with: params) { response in
        switch response {
        case .success(let value):
            // Save customer secret to your storage and then link it with API manager
            defaults.set(value.data.secret, forKey: "customerSecret")

            SERequestManager.shared.set(customerSecret: value.data.secret)
            case .failure(let error):
            // Handle error
        }
    }
}
```

## SEWebView

A small `WKWebView` subclass for using [Salt Edge Connect](https://docs.saltedge.com/account_information/v5/#salt_edge_connect) within your iOS app.

### Example

Let your view controller conform to the `SEWebViewDelegate` protocol.

```swift
class MyViewController : UIViewController, SEWebViewDelegate {
  // ... snip ...
}
```

Instantiate a `SEWebView` and add it to the controller:

```swift
let connectWebView = SEWebView(frame: self.view.bounds)
connectWebView.stateDelegate = self
self.view.addSubview(connectWebView)
```

Implement the `SEWebViewDelegate` methods in the controller:

```swift
// ... snip ...

func webView(_ webView: SEWebView, didReceiveCallbackWithResponse response: SEConnectResponse) {
    switch response.stage {
    case .success:
	    // Connection successfully connected
    case .fetching:
	    // Connection is fetching. You can safe connection secret if it is present.
    case .error:
	    // Handle error
    }
}

func webView(_ webView: SEWebView, didReceiveCallbackWithError error: Error) {
	// Handle error
}
```

Load the Salt Edge Connect URL into the web view and you're good to go:

```swift
SERequestManager.shared.createConnectSession(params: connectSessionParams) { response in
	switch response {
	case .success(let value):
		if let url = URL(string: value.data.connectUrl) {
		    self.webView.load(URLRequest(url: url))
		}
	case .failure(let error):
		// Handle error
	}
}

```

## Models

There are some provided models for serializing the objects received in the API responses. These represent the Providers, Connections, Accounts, Transactions, provider fields and their options. Whenever you request a resource that returns one of these types, they will always get serialized into Swift structures. For instance, the `getAllTransactions(for connectionSecret: String, params: SETransactionParams? = nil, completion: SEHTTPResponse<[SETransaction]>)` method has a `SEResponse` containing `data` and `meta` where `data` is `[SETransaction]` in it's success callback.

Models, contained within the components:

* `SEProvider`
* `SEConnection`
* `SEAccount`
* `SETransaction`
* `SEConnectSessionResponse`
* `SEAttempt`
* `SEConsent`
* `SECountry`
* `SECustomer`
* `SEStage`
* `SEError`
* `SEProviderField`
* `SEProviderFieldOption`

For a supplementary description of the models listed above that is not included in the sources docs, feel free to visit the [Salt Edge API Reference](https://docs.saltedge.com/account_information/v5/)

### Models extra

Some of models have `extra` field of type `[String: Any]`. In case you need to get any field, you can do the following:

```swift
let account = SEAccount()

guard let accountExtra = account.extra else { return }

let anyValue = accountExtra["string_key"]
```

Some of key-pairs have predifinied extensions:

```swift
let transaction = SETransaction()

guard let transactionExtra = transaction.extra else { return }

let possibleDuplicate: Bool = transactionExtra.possibleDuplicate
```

## Documentation

Documentation is available for all of the components. Use quick documentation (Alt+Click) to get a quick glance at the documentation for a method or a property.

## Running the demo

To run the contained here demo app, you have to set the demo with your App ID, App Secret and choose desired API.

To setup Salt Edge API, call:
```swift
SERequestManager.shared.set(appId: appId, appSecret: appSecret)
```

Set up the `appId`,  `appSecret` and `customerId` constants to your App ID and corresponding App Secret in [AppDelegate.swift:69-72](https://github.com/saltedge/saltedge-ios-swift/blob/master/Example/saltedge-ios/AppDelegate.swift#L69-L72).

## Versioning

The current version of the SDK is [3.5.1](https://github.com/saltedge/saltedge-ios-swift/releases/tag/3.5.1), and supports the latest available version of Salt Edge API. Any backward-incompatible changes in the API will result in changes to the SDK.

## Changelog

See the [Changelog](CHANGELOG.md) file.

## License

See the [LICENSE](LICENSE) file.

## References

1. [How to... instructions](HOWTO.md)
1. [Salt Edge API General](https://docs.saltedge.com/general/)
1. [Salt Edge Client Dashboard](https://www.saltedge.com/clients/dashboard)
1. [Salt Edge API v5 Reference](https://docs.saltedge.com/account_information/v5/)

For more information, feel free to [contact us](https://www.saltedge.com/pages/contact)
---
Copyright © 2014 Salt Edge Inc. https://www.saltedge.com
