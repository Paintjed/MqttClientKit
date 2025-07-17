import Testing
import Foundation
@testable import MqttClientKit
import ComposableArchitecture
import NIOCore
import MQTTNIO

@Test
func testMqttClientKitInfoInit() async throws {
    let info = MqttClientKitInfo(address: "localhost", port: 1883, clientID: "testClient")
    #expect(info.address == "localhost")
    #expect(info.port == 1883)
    #expect(info.clientID == "testClient")
}

@Test
func testMqttClientKitErrorDescriptions() async throws {
    #expect(MqttClientKitError.timeout.errorDescription == "Connection Timeout")
    #expect(MqttClientKitError.closeUnexpect.errorDescription == "Connection Closed Unexpectedly")
    #expect(MqttClientKitError.noConnection.errorDescription == "No Connection")
    let underlying = NSError(domain: "Test", code: 1)
    #expect(MqttClientKitError.underlying(underlying).errorDescription == "Underlying Error")
}

@Test
func testMqttClientKitErrorRecoverySuggestion() async throws {
    #expect(MqttClientKitError.timeout.recoverySuggestion == "Check if the device's Wi-Fi is connected to the router.")
    #expect(MqttClientKitError.closeUnexpect.recoverySuggestion == "Ensure the device stays online during the connection process.")
    #expect(MqttClientKitError.noConnection.recoverySuggestion == "No connection")
    let underlying = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
    #expect(MqttClientKitError.underlying(underlying).recoverySuggestion == "Test error")
}

@Test
func testMqttClientKitErrorEquatable() async throws {
    #expect(MqttClientKitError.timeout == .timeout)
    #expect(MqttClientKitError.closeUnexpect == .closeUnexpect)
    #expect(MqttClientKitError.noConnection == .noConnection)
    let err1 = NSError(domain: "Test", code: 1)
    let err2 = NSError(domain: "Test", code: 1)
    #expect(MqttClientKitError.underlying(err1) == MqttClientKitError.underlying(err2))
    let err3 = NSError(domain: "Test", code: 2)
    #expect(MqttClientKitError.underlying(err1) != MqttClientKitError.underlying(err3))
}

@Test
func testMqttClientKitStateEquatable() async throws {
    #expect(MqttClientKit.State.idle == .idle)
    #expect(MqttClientKit.State.connected == .connected)
    #expect(MqttClientKit.State.connecting == .connecting)
    #expect(MqttClientKit.State.disconnected(.timeout) == .disconnected(.timeout))
    #expect(MqttClientKit.State.disconnected(.timeout) != .disconnected(.closeUnexpect))
}


@Test
func testMqttClientKitTestValue() async throws {
    let testValue = MqttClientKit.testValue
    
    let connectStream = await testValue.connect(.init(address: "", port: 0, clientID: ""))
    for await state in connectStream {
        #expect(state == .connected)
    }
    
    try await testValue.disconnect()
    
    let isActive = try testValue.isActive()
    #expect(isActive == true)
    
    let receivedStream = testValue.received()
    var count = 0
    for try await info in receivedStream {
        count += 1
        #expect(info.topicName == "painting")
    }
    #expect(count == 3)
}

@Test
func testMqttClientKitPublishSubscribe() async throws {
    let testValue = MqttClientKit.testValue

    // 1. Connect
    let connectStream = await testValue.connect(.init(address: "test.mosquitto.org", port: 1883, clientID: "gemini-test"))
    for await state in connectStream {
        #expect(state == .connected)
    }

    // 2. Subscribe
    let subInfo = MQTTSubscribeInfo(topicFilter: "gemini-test-topic", qos: .atLeastOnce)
    _ = try? await testValue.subscribe(subInfo)

    // 3. Publish
    let pubInfo = MQTTPublishInfo(
        qos: .atLeastOnce,
        retain: false,
        topicName: "gemini-test-topic",
        payload: ByteBuffer(string: "hello"),
        properties: .init([])
    )
    try? await testValue.publish(pubInfo)

    // 4. Receive
    let receivedStream = testValue.received()
    var receivedMessages = 0
    for try await receivedInfo in receivedStream {
        #expect(receivedInfo.topicName == "gemini-test-topic" || receivedInfo.topicName == "painting")
        if receivedInfo.topicName == "gemini-test-topic" {
            #expect(receivedInfo.payload == ByteBuffer(string: "hello"))
        }
        receivedMessages += 1
    }
    #expect(receivedMessages == 4)


    // 5. Unsubscribe
    try? await testValue.unsubscribe("gemini-test-topic")

    // 6. Disconnect
    try await testValue.disconnect()
}