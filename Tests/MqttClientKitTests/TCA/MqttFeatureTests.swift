//
//  MqttFeatureTests.swift
//  MqttClientKitTests
//
//  Created by Jed Lu on 2025/8/31.
//

import XCTest
import ComposableArchitecture
@testable import MqttClientKit
import MQTTNIO
import NIOCore

@MainActor
final class MqttFeatureTests: XCTestCase {
  
  // MARK: - Initial State Tests
  func testInitialState() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    XCTAssertEqual(store.state.connectionState, .idle)
    XCTAssertEqual(store.state.isConnecting, false)
    XCTAssertEqual(store.state.showingConnectionSettings, false)
    XCTAssertEqual(store.state.isConnected, false)
    XCTAssertEqual(store.state.canConnect, true)
    XCTAssertEqual(store.state.canDisconnect, false)
  }
  
  func testInitialStateWithSubscriptions() async {
    let state = MqttFeature.State.withSubscriptions([
      "home/temperature", 
      "home/humidity"
    ])
    
    let store = TestStore(initialState: state) {
      MqttFeature()
    }
    
    XCTAssertEqual(store.state.subscriber.subscriptions.count, 2)
    XCTAssertEqual(store.state.subscriber.subscriptions[0].topicFilter, "home/temperature")
    XCTAssertEqual(store.state.subscriber.subscriptions[1].topicFilter, "home/humidity")
  }
  
  // MARK: - Connection Management Tests
  func testConnectionFlow() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
      
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    await store.send(\.view.connect)
    await store.receive(\.connectionEffectStarted) {
      $0.isConnecting = true
    }
    await store.receive(\.mqttStateChanged, .connected) {
      $0.connectionState = .connected
      $0.isConnecting = false
    }
    await store.receive(\.delegate.connectionStatusChanged, .connected)
  }
  
  func testConnectionError() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    await store.send(\.mqttStateChanged, .disconnected(.timeout)) {
      $0.connectionState = .disconnected(.timeout)
      $0.isConnecting = false
    }
    await store.receive(\.delegate.connectionStatusChanged, .disconnected(.timeout))
  }
  
  // MARK: - Connection-Based Message Stream Tests
  func testConnectionSuccessTriggersMessageStream() async {
    // Test verifies that message stream starts only after successful connection
    // .task action should not immediately start message receiving
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
      
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    // .task should not trigger any message stream actions
    await store.send(\.view.task)
    // No subscriber actions should be triggered
    
    // Message stream should start when connection is established
    await store.send(\.mqttStateChanged, .connected) {
      $0.connectionState = .connected
      $0.isConnecting = false
    }
    
    // Verify delegate action is sent
    await store.receive(\.delegate.connectionStatusChanged, .connected)
    
    // Verify message stream starts when connected
    await store.receive(\.subscriber.view.task)
    await store.receive(\.subscriber.messageStreamStarted)
  }
  
  func testEndToEndMessageFlow() async {
    // Tests complete message flow from connection to message reception
    // Verifies connection-based automatic message stream startup
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    store.exhaustivity = .off(showSkippedAssertions: false)
    
    // .task should not trigger message receiving
    await store.send(\.view.task)
    // No immediate subscriber actions
    
    // Establish connection first
    await store.send(\.mqttStateChanged, .connected) {
      $0.connectionState = .connected
      $0.isConnecting = false
    }
    await store.receive(\.delegate.connectionStatusChanged, .connected)
    
    // Now message stream should start
    await store.receive(\.subscriber.view.task)
    await store.receive(\.subscriber.messageStreamStarted)
    
    // testValue automatically generates 3 "painting" messages
    // Verify we receive them and they're forwarded as delegate actions
    var messageCount = 0
    let expectedMessageCount = 3
    
    while messageCount < expectedMessageCount {
      // Each message should trigger:
      // 1. subscriber.messageReceived (updates subscriber.messages)
      // 2. delegate.messageReceived (forwarded to parent)
      await store.receive(\.subscriber.messageReceived) { state in
        // Verify message is stored in subscriber
        messageCount += 1
        expectNoDifference(state.subscriber.messages.count, messageCount)
        
        // Verify it's a "painting" topic message from testValue
        XCTAssertFalse(state.subscriber.messages.isEmpty, "Expected messages to be stored")
        guard let latestMessage = state.subscriber.messages.last else {
          XCTFail("Expected latest message to exist")
          return
        }
        
        expectNoDifference(latestMessage.topicName, "painting")
      }
      
      await store.receive(\.delegate.messageReceived)
    }
    
    // Final verification
    expectNoDifference(store.state.subscriber.messages.count, expectedMessageCount)
  }
  
  func testMessageReceivingWithSubscriptions() async {
    // Tests message receiving with pre-configured subscriptions
    // Verifies that connection-based message stream works with existing subscriptions
    // Initialize with pre-configured subscriptions
    let initialState = MqttFeature.State.withSubscriptions([
      "painting", // This matches testValue's generated messages
      "home/temperature"
    ])
    
    let store = TestStore(initialState: initialState) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    store.exhaustivity = .off(showSkippedAssertions: false)
    
    // Verify initial subscriptions are set
    expectNoDifference(store.state.subscriber.subscriptions.count, 2)
    expectNoDifference(store.state.subscriber.subscriptions[0].topicFilter, "painting")
    expectNoDifference(store.state.subscriber.subscriptions[1].topicFilter, "home/temperature")
    
    // .task should not start message receiving immediately
    await store.send(\.view.task)
    // No immediate subscriber actions
    
    // Establish connection first
    await store.send(\.mqttStateChanged, .connected) {
      $0.connectionState = .connected
      $0.isConnecting = false
    }
    await store.receive(\.delegate.connectionStatusChanged, .connected)
    
    // Now message stream should start
    await store.receive(\.subscriber.view.task)
    await store.receive(\.subscriber.messageStreamStarted)
    
    // Should receive the painting messages since we have a matching subscription
    var receivedMessages = 0
    let expectedPaintingMessages = 3
    
    while receivedMessages < expectedPaintingMessages {
      await store.receive(\.subscriber.messageReceived) { state in
        receivedMessages += 1
        
        // Safely verify message is stored in subscriber
        XCTAssertFalse(state.subscriber.messages.isEmpty, "Expected messages to be stored")
        guard let latestMessage = state.subscriber.messages.last else {
          XCTFail("Expected latest message to exist")
          return
        }
        
        expectNoDifference(latestMessage.topicName, "painting")
        
        // Verify message content structure (JSON from testValue)
        let payloadString = String(buffer: latestMessage.payload)
        XCTAssertTrue(payloadString.contains("total_stripes"))
        XCTAssertTrue(payloadString.contains("current_stripe"))
      }
      
      // Verify delegate forwarding
      await store.receive(\.delegate.messageReceived)
    }
    
    // Final state verification
    expectNoDifference(store.state.subscriber.messages.count, expectedPaintingMessages)
    expectNoDifference(store.state.subscriber.subscriptions.count, 2) // Subscriptions unchanged
  }
  
  // MARK: - UI Integration Tests  
  func testConnectionSettingsFlow() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    await store.send(\.view.showConnectionSettings) {
      $0.showingConnectionSettings = true
    }
    
    await store.send(\.view.hideConnectionSettings) {
      $0.showingConnectionSettings = false
    }
  }
  
  // MARK: - Child Feature Delegate Tests
  func testPublisherDelegateIntegration() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    let publishInfo = MQTTPublishInfo(
      qos: .atMostOnce,
      retain: false,
      topicName: "test/topic",
      payload: ByteBuffer(string: "Hello"),
      properties: .init([])
    )
    
    await store.send(\.publisher.delegate.messagePublished, publishInfo)
    await store.receive(\.delegate.messagePublished, publishInfo)
    
    await store.send(\.publisher.delegate.publishErrorOccurred, .noConnection)
    await store.receive(\.delegate.errorOccurred, .noConnection)
  }
  
  func testSubscriberDelegateIntegration() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    let publishInfo = MQTTPublishInfo(
      qos: .atMostOnce,
      retain: false,
      topicName: "test/topic",
      payload: ByteBuffer(string: "Hello"),
      properties: .init([])
    )
    
    let subscribeInfo = MQTTSubscribeInfo(
      topicFilter: "test/+",
      qos: .atLeastOnce
    )
    
    await store.send(\.subscriber.delegate.messageReceived, publishInfo)
    await store.receive(\.delegate.messageReceived, publishInfo)
    
    await store.send(\.subscriber.delegate.subscriptionAdded, subscribeInfo)
    await store.receive(\.delegate.subscriptionAdded, subscribeInfo)
    
    await store.send(\.subscriber.delegate.subscriptionRemoved, "test/+")
    await store.receive(\.delegate.subscriptionRemoved, "test/+")
    
    await store.send(\.subscriber.delegate.errorOccurred, .timeout)
    await store.receive(\.delegate.errorOccurred, .timeout)
  }
  
  // MARK: - Computed Properties Tests
  func testConnectionStateComputedProperties() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
      
    store.exhaustivity = .off(showSkippedAssertions: true)
    
    // Test idle state
    XCTAssertEqual(store.state.isConnected, false)
    XCTAssertEqual(store.state.canConnect, true)
    XCTAssertEqual(store.state.canDisconnect, false)
    
    // Test connecting state
    await store.send(\.mqttStateChanged, .connecting) {
      $0.connectionState = .connecting
      $0.isConnecting = false
    }
    XCTAssertEqual(store.state.isConnected, false)
    XCTAssertEqual(store.state.canConnect, true)
    XCTAssertEqual(store.state.canDisconnect, false)
    
    // Test connected state
    await store.send(\.mqttStateChanged, .connected) {
      $0.connectionState = .connected
    }
      
    XCTAssertEqual(store.state.isConnected, true)
    XCTAssertEqual(store.state.canConnect, false)
    XCTAssertEqual(store.state.canDisconnect, true)
  }
  
  // MARK: - Convenience Initializers Tests
  func testPublisherOnlyInitializer() async {
    let connectionInfo = MqttClientKitInfo(
      address: "mqtt.example.com",
      port: 8883,
      clientID: "publisher-client"
    )
    
    let state = MqttFeature.State.publisherOnly(connectionInfo: connectionInfo)
    
    XCTAssertEqual(state.connectionInfo.address, "mqtt.example.com")
    XCTAssertEqual(state.connectionInfo.port, 8883)
    XCTAssertEqual(state.connectionInfo.clientID, "publisher-client")
    XCTAssertEqual(state.subscriber.subscriptions.count, 0)
  }
}
