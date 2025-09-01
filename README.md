# MqttClientKit

A modern Swift package providing a composable, async/await-based MQTT client built for iOS and macOS applications. Designed with The Composable Architecture (TCA) integration and Swift 6.0 concurrency safety.

## Features

- **Modern Swift API**: Async/await-based operations with full Swift 6.0 sendable compliance
- **TCA Integration**: Ready-to-use TCA features for connection, publishing, and subscription management
- **Actor-Safe**: Thread-safe connection management using Swift actors
- **Comprehensive Testing**: Mock implementations and extensive test coverage
- **iOS Optimized**: Uses `.singletonNIOTSEventLoopGroup` for optimal iOS Network.framework compatibility
- **Error Handling**: Detailed error types with localized descriptions and recovery suggestions
- **Modular Architecture**: Clean separation between core functionality and TCA features

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

Add this package to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/jedlu/MqttClientKit.git", from: "1.0.0")
```

Then add the appropriate target to your dependencies:

```swift
.target(
  name: "YourTarget",
  dependencies: [
    .product(name: "MqttClientKit", package: "MqttClientKit"),
    // For TCA features only:
    .product(name: "MqttFeatures", package: "MqttClientKit")
  ]
)
```

## Core API

### MqttClientKit

The main client provides async/await operations:

```swift
import MqttClientKit

let client = MqttClientKit.liveValue

// Connect and listen to connection states
let connectionStream = await client.connect(MqttClientKitInfo(
  address: "localhost",
  port: 1883,
  clientID: "my-app"
))

for await state in connectionStream {
  switch state {
  case .connected:
    print("Connected!")
  case .disconnected(let error):
    print("Disconnected: \(error?.localizedDescription ?? "Unknown")")
  case .connecting, .idle:
    break
  }
}

// Publish messages
try await client.publish(MQTTPublishInfo(
  qos: .atLeastOnce,
  retain: false,
  topicName: "home/temperature",
  payload: ByteBuffer(string: "23.5"),
  properties: .init([])
))

// Subscribe to topics
try await client.subscribe(MQTTSubscribeInfo(
  topicFilters: [MQTTSubscribeInfo.TopicFilter(
    topicFilter: "home/+",
    qos: .atLeastOnce
  )]
))

// Receive messages
for try await message in client.received() {
  print("Received: \(String(buffer: message.payload)) on \(message.topicName)")
}
```

## TCA Integration

### MqttFeature

Main orchestrating feature that combines connection, publishing, and subscription:

```swift
import MqttClientKit
import ComposableArchitecture

struct MyView: View {
  let store: StoreOf<MqttFeature>
  
  var body: some View {
    MqttExampleView(store: store)
  }
}

// Initialize in your app
Store(initialState: MqttFeature.State()) {
  MqttFeature()
}
```

### MqttPublisherFeature

Provides both UI-driven and programmatic publishing capabilities:

```swift
// Direct publishing without UI state dependency
store.send(.publish(publishInfo))

// Convenience method for quick publishing
store.send(.publishWithDetails(
  topic: "home/temperature", 
  payload: "23.5", 
  qos: .atLeastOnce, 
  retain: true
))

// Traditional UI-driven publishing (for forms)
store.send(.view(.publishButtonTapped))
store.send(.view(.clearFormButtonTapped))
```

### MqttSubscriberFeature

Manages dynamic subscriptions and message history with action-based subscription API:

```swift
// Subscribe to topics directly with action
store.send(.view(.subscribe(MQTTSubscribeInfo(
  topicFilter: "home/temperature", 
  qos: .atLeastOnce
))))

// Unsubscribe from topics
store.send(.view(.unsubscribe(subscriptionID)))

// View received messages
store.state.messages // Array of received messages

// Clear messages and errors
store.send(.view(.clearMessages))
store.send(.view(.clearError))
```

## Example Applications

The package includes two example implementations:

### Simple MQTT Client
Basic MQTT functionality with minimal setup - perfect for learning the core API.

### Advanced TCA Client  
Full-featured application demonstrating:
- Connection management with settings UI
- Real-time publishing with form validation
- Dynamic subscription management
- Message history with configurable limits
- Error handling and recovery

Run the examples:

```bash
swift run Examples
```

## Testing

### Mock Implementation
Use the test implementation for unit tests:

```swift
import MqttClientKit

let store = TestStore(initialState: MyFeature.State()) {
  MyFeature()
} withDependencies: {
  $0.mqttClientKit = .testValue
}
```

### Test Structure
- **Core Tests**: Swift Testing for models and core functionality
- **TCA Tests**: XCTest for feature integration and state management
- **Comprehensive Coverage**: Connection states, error handling, concurrent operations

## Architecture

### Core Layer
- `MqttClientKit`: Main client interface
- `ConnectionManager`: Actor-based connection management
- `MqttClientKitModels`: Data types and error definitions

### Dependencies Layer
- Live implementation using MQTT-NIO
- Test implementation for mocking
- TCA dependency registration

### TCA Layer
- `MqttFeature`: Main orchestrating feature
- `MqttPublisherFeature`: Publishing operations
- `MqttSubscriberFeature`: Subscription management

### Examples Layer
- `ExampleSelectionView`: Navigation between examples
- `SimpleMqttView`: Basic implementation
- `MqttExampleView`: Advanced TCA implementation

## Error Handling

The library provides detailed error types with recovery suggestions:

```swift
enum MqttClientKitError {
  case timeout              // Check Wi-Fi connection
  case closeUnexpect        // Ensure device stays online
  case noConnection         // Establish connection first
  case underlying(Error)    // Wrapped system errors
}
```

## License

MIT