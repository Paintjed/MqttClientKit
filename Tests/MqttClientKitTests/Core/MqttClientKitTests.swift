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
func testMqttClientKitInfoEdgeCases() async throws {
    // Test with empty values
    let emptyInfo = MqttClientKitInfo(address: "", port: 0, clientID: "")
    #expect(emptyInfo.address == "")
    #expect(emptyInfo.port == 0)
    #expect(emptyInfo.clientID == "")
    
    // Test with typical values
    let standardInfo = MqttClientKitInfo(address: "mqtt.broker.com", port: 8883, clientID: "client-123")
    #expect(standardInfo.address == "mqtt.broker.com")
    #expect(standardInfo.port == 8883)
    #expect(standardInfo.clientID == "client-123")
    
    // Test with special characters
    let specialInfo = MqttClientKitInfo(address: "192.168.1.1", port: 1883, clientID: "client_測試-123")
    #expect(specialInfo.address == "192.168.1.1")
    #expect(specialInfo.clientID == "client_測試-123")
}

@Test
func testMqttClientKitInfoEquatable() async throws {
    let info1 = MqttClientKitInfo(address: "localhost", port: 1883, clientID: "test")
    let info2 = MqttClientKitInfo(address: "localhost", port: 1883, clientID: "test")
    let info3 = MqttClientKitInfo(address: "localhost", port: 1883, clientID: "different")
    
    #expect(info1 == info2)
    #expect(info1 != info3)
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
func testMqttClientKitErrorAllCombinations() async throws {
    let errors: [MqttClientKitError] = [
        .timeout,
        .closeUnexpect,
        .noConnection,
        .underlying(NSError(domain: "Test", code: 1))
    ]
    
    // Test each error against itself and others
    for (i, error1) in errors.enumerated() {
        for (j, error2) in errors.enumerated() {
            if i == j {
                #expect(error1 == error2)
            } else {
                #expect(error1 != error2)
            }
        }
    }
}

@Test
func testMqttClientKitErrorLocalizedError() async throws {
    let timeout = MqttClientKitError.timeout
    let closeUnexpect = MqttClientKitError.closeUnexpect
    let noConnection = MqttClientKitError.noConnection
    let underlying = MqttClientKitError.underlying(NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Custom error message"]))
    
    // Test LocalizedError conformance
    #expect(timeout.errorDescription != nil)
    #expect(closeUnexpect.errorDescription != nil)
    #expect(noConnection.errorDescription != nil)
    #expect(underlying.errorDescription != nil)
    
    #expect(timeout.recoverySuggestion != nil)
    #expect(closeUnexpect.recoverySuggestion != nil)
    #expect(noConnection.recoverySuggestion != nil)
    #expect(underlying.recoverySuggestion != nil)
    
    // Test specific recovery suggestion for underlying error
    #expect(underlying.recoverySuggestion == "Custom error message")
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
func testMqttClientKitStateComprehensive() async throws {
    let allStates: [MqttClientKit.State] = [
        .idle,
        .connected,
        .connecting,
        .disconnected(.timeout),
        .disconnected(.closeUnexpect),
        .disconnected(.noConnection),
        .disconnected(.underlying(NSError(domain: "Test", code: 1)))
    ]
    
    // Test each state against itself and others
    for (i, state1) in allStates.enumerated() {
        for (j, state2) in allStates.enumerated() {
            if i == j {
                #expect(state1 == state2)
            } else {
                #expect(state1 != state2)
            }
        }
    }
}

@Test
func testMqttClientKitStateSendable() async throws {
    let state = MqttClientKit.State.connected
    
    // Test that State can be passed between tasks
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            let localState = state
            #expect(localState == .connected)
        }
        
        group.addTask {
            let localState = MqttClientKit.State.disconnected(.timeout)
            #expect(localState != .connected)
        }
    }
}


@Test
func testMqttClientKitTestValue() async throws {
    let testValue = MqttClientKit.testValue
    
    let connectStream = await testValue.connect(.init(address: "", port: 0, clientID: ""))
    for await state in connectStream {
        #expect(state == .connected)
    }
    
    try await testValue.disconnect()
    
    let isActive = try await testValue.isActive()
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
func testMqttClientKitSendableCompliance() async throws {
    let testValue = MqttClientKit.testValue
    let info = MqttClientKitInfo(address: "localhost", port: 1883, clientID: "test")
    
    // Test that all methods can be called concurrently
    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            _ = await testValue.connect(info)
        }
        
        group.addTask {
            _ = try? await testValue.isActive()
        }
        
        group.addTask {
            _ = testValue.received()
        }
    }
}

@Test
func testMqttClientKitAsyncOperations() async throws {
    let testValue = MqttClientKit.testValue
    
    // Test async isActive
    let isActive1 = try await testValue.isActive()
    #expect(isActive1 == true)
    
    // Test async disconnect
    try await testValue.disconnect()
    
    // Test async publish
    let pubInfo = MQTTPublishInfo(
        qos: .atLeastOnce,
        retain: false,
        topicName: "test-topic",
        payload: ByteBuffer(string: "test"),
        properties: .init([])
    )
    try await testValue.publish(pubInfo)
    
    // Test async subscribe
    let subInfo = MQTTSubscribeInfo(topicFilter: "test-topic", qos: .atLeastOnce)
    _ = try await testValue.subscribe(subInfo)
    
    // Test async unsubscribe
    try await testValue.unsubscribe("test-topic")
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

@Test
func testMqttClientKitTestValueSubscriptionLogic() async throws {
    let testValue = MqttClientKit.testValue
    
    // Test subscription logic
    let subInfo = MQTTSubscribeInfo(topicFilter: "test-topic", qos: .atLeastOnce)
    _ = try await testValue.subscribe(subInfo)
    
    // Publish to subscribed topic
    let pubInfo = MQTTPublishInfo(
        qos: .atLeastOnce,
        retain: false,
        topicName: "test-topic",
        payload: ByteBuffer(string: "subscribed message"),
        properties: .init([])
    )
    try await testValue.publish(pubInfo)
    
    // Publish to non-subscribed topic (should not appear in received)
    let nonSubPubInfo = MQTTPublishInfo(
        qos: .atLeastOnce,
        retain: false,
        topicName: "non-subscribed-topic",
        payload: ByteBuffer(string: "non-subscribed message"),
        properties: .init([])
    )
    try await testValue.publish(nonSubPubInfo)
    
    // Test received messages
    let receivedStream = testValue.received()
    var receivedCount = 0
    var foundSubscribedMessage = false
    
    for try await info in receivedStream {
        receivedCount += 1
        if info.topicName == "test-topic" {
            foundSubscribedMessage = true
            #expect(info.payload == ByteBuffer(string: "subscribed message"))
        }
        // Break after reasonable number to avoid infinite loop
        if receivedCount >= 10 { break }
    }
    
    #expect(foundSubscribedMessage)
}

@Test
func testMqttClientKitTestValueUnsubscribe() async throws {
    let testValue = MqttClientKit.testValue
    
    // Subscribe first
    let subInfo = MQTTSubscribeInfo(topicFilter: "temp-topic", qos: .atLeastOnce)
    _ = try await testValue.subscribe(subInfo)
    
    // Publish to see it's working
    let pubInfo = MQTTPublishInfo(
        qos: .atLeastOnce,
        retain: false,
        topicName: "temp-topic",
        payload: ByteBuffer(string: "temp message"),
        properties: .init([])
    )
    try await testValue.publish(pubInfo)
    
    // Now unsubscribe
    try await testValue.unsubscribe("temp-topic")
    
    // Publish again - should not appear in received stream
    try await testValue.publish(pubInfo)
    
    // Test that we only get the default painting messages, not the temp-topic ones
    let receivedStream = testValue.received()
    var paintingCount = 0
    var tempTopicCount = 0
    
    for try await info in receivedStream {
        if info.topicName == "painting" {
            paintingCount += 1
        } else if info.topicName == "temp-topic" {
            tempTopicCount += 1
        }
        
        if paintingCount >= 3 { break } // We expect 3 painting messages
    }
    
    #expect(paintingCount == 3)
    #expect(tempTopicCount == 0) // Only the one before unsubscribe
}

@Test
func testMqttClientKitDependencyValues() async throws {
    try await withDependencies {
        $0.mqttClientKit = .testValue
    } operation: {
        @Dependency(\.mqttClientKit) var testMqttClient
        
        let isActive = try await testMqttClient.isActive()
        #expect(isActive == true)
        
        let connectStream = await testMqttClient.connect(MqttClientKitInfo(address: "test", port: 1883, clientID: "test"))
        for await state in connectStream {
            #expect(state == .connected)
            break
        }
    }
}

@Test
func testMqttClientKitStressTest() async throws {
    let testValue = MqttClientKit.testValue
    
    // Test multiple concurrent operations
    await withTaskGroup(of: Void.self) { group in
        // Multiple connect calls
        for i in 1...5 {
            group.addTask {
                let info = MqttClientKitInfo(address: "localhost", port: 1883, clientID: "client-\(i)")
                let stream = await testValue.connect(info)
                for await state in stream {
                    #expect(state == .connected)
                    break
                }
            }
        }
        
        // Multiple isActive calls
        for _ in 1...10 {
            group.addTask {
                let isActive = try? await testValue.isActive()
                #expect(isActive == true)
            }
        }
        
        // Multiple publish calls
        for i in 1...5 {
            group.addTask {
                let pubInfo = MQTTPublishInfo(
                    qos: .atLeastOnce,
                    retain: false,
                    topicName: "stress-test-\(i)",
                    payload: ByteBuffer(string: "message-\(i)"),
                    properties: .init([])
                )
                try? await testValue.publish(pubInfo)
            }
        }
        
        // Multiple subscribe/unsubscribe calls
        for i in 1...3 {
            group.addTask {
                let subInfo = MQTTSubscribeInfo(topicFilter: "topic-\(i)", qos: .atLeastOnce)
                _ = try? await testValue.subscribe(subInfo)
                try? await testValue.unsubscribe("topic-\(i)")
            }
        }
    }
}

@Test
func testMqttClientKitErrorScenarios() async throws {
    // Test that testValue handles all operations without throwing
    let testValue = MqttClientKit.testValue
    
    // These should not throw
    try await testValue.disconnect()
    try await testValue.disconnect() // Double disconnect
    
    let isActive = try await testValue.isActive()
    #expect(isActive == true)
    
    // Test multiple unsubscribes of same topic
    try await testValue.unsubscribe("non-existent-topic")
    try await testValue.unsubscribe("non-existent-topic")
    
    // Test publish to various topics
    let topics = ["test", "test/subtopic", "very/deep/topic/structure", "123", ""]
    for topic in topics {
        let pubInfo = MQTTPublishInfo(
            qos: .atLeastOnce,
            retain: false,
            topicName: topic,
            payload: ByteBuffer(string: "test message"),
            properties: .init([])
        )
        try await testValue.publish(pubInfo)
    }
}
