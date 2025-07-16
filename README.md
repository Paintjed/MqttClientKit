# MqttClientKit

A Swift package providing a composable, async/await-based MQTT client abstraction for use with The Composable Architecture (TCA) and other Swift projects.

## Features
- Async/await API for connecting, publishing, subscribing, and receiving MQTT messages
- Integration-ready for TCA via dependency injection
- Test/mock implementation (`testValue`) for easy unit testing
- Error handling with localized descriptions and recovery suggestions

## Usage

### Add Dependency
Add this package to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/your-username/MqttClientKit.git", from: "1.0.0")
```

And add `MqttClientKit` to your target dependencies.

### Basic Example
```swift
import MqttClientKit

let client = MqttClientKit.liveValue
let info = MqttClientKitInfo(address: "broker.hivemq.com", port: 1883, clientID: "myClient")

// Connect
let stream = await client.connect(info)
for await state in stream {
    print("State: \(state)")
}

// Publish
let publishInfo = MQTTPublishInfo(
    qos: .atLeastOnce,
    retain: false,
    topicName: "test/topic",
    payload: ByteBuffer(data: Data("Hello MQTT!".utf8)),
    properties: .init([])
)
try await client.publish(publishInfo)

// Subscribe
let subscribeInfo = MQTTSubscribeInfo(topicFilter: "test/topic", qos: .atLeastOnce)
try await client.subscribe(subscribeInfo)

// Receive
let receivedStream = client.received()
for try await message in receivedStream {
    let payloadString = message.payload.getString(at: 0, length: message.payload.readableBytes) ?? ""
    print("Received: \(message.topicName), payload: \(payloadString)")
}
```

### Testing
Use the `testValue` for unit tests or previews:
```swift
let mockClient = MqttClientKit.testValue
// Use mockClient in your tests
```

## License
MIT
