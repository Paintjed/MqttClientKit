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
.package(url: "https://github.com/jedlu/MqttClientKit.git", from: "1.0.0")
```

And add `MqttClientKit` to your target dependencies.

### MqttClientKit API

`MqttClientKit` provides the following core functionalities:

- `connect(info: MqttClientKitInfo) -> AsyncStream<State>`: Establishes a connection to the MQTT broker.
- `disconnect() async throws -> ()`: Disconnects from the MQTT broker.
- `publish(info: MQTTPublishInfo) async throws -> ()`: Publishes a message to a specified topic.
- `subscribe(info: MQTTSubscribeInfo) async throws -> MQTTSuback?`: Subscribes to a topic.
- `unsubscribe(topic: Topic) async throws -> ()`: Unsubscribes from a topic.
- `isActive() throws -> Bool`: Checks if the client is currently connected.
- `received() -> AsyncThrowingStream<MQTTPublishInfo, Error>`: Provides an asynchronous stream of received MQTT messages.

### Example Application

The `Examples` executable target demonstrates how to use `MqttClientKit` with The Composable Architecture (TCA).

To run the example:

```bash
swift run Examples
```

The example connects to an MQTT broker (defaulting to `localhost:1883`). You can change the broker address by modifying the `address` parameter in `Sources/Examples/TCA/MqttFeature.swift` within the `connectButtonTapped` action.

### Testing
Use the `testValue` for unit tests or previews:
```swift
let mockClient = MqttClientKit.testValue
// Use mockClient in your tests
```

## License
MIT