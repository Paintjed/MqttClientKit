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
  
  // MARK: - Connection Settings Tests
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
  
  // MARK: - Child Feature Integration Tests
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
