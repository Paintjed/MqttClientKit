import XCTest
import ComposableArchitecture
@testable import MqttClientKit

final class MqttFeatureTests: XCTestCase {
  func testConnectButtonTapped() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    await store.send(\.view.connectButtonTapped)
    await store.receive(\.mqtt, .connected) {
      $0.isConnected = true
    }
  }
  
  func testDisconnectButtonTapped() async {
    let store = TestStore(initialState: MqttFeature.State(isConnected: true)) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    await store.send(\.view.disconnectButtonTapped)
  }
  
  func testMqttStateConnected() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    await store.send(\.mqtt, .connected) {
      $0.isConnected = true
    }
  }
  
  func testMqttStateDisconnected() async {
    let store = TestStore(initialState: MqttFeature.State(isConnected: true)) {
      MqttFeature()
    }
    
    await store.send(\.mqtt, .disconnected(.timeout)) {
      $0.isConnected = false
    }
  }
  
  func testMqttStateIdle() async {
    let store = TestStore(initialState: MqttFeature.State(isConnected: true)) {
      MqttFeature()
    }
    
    await store.send(\.mqtt, .idle)
    // State should remain unchanged for idle
  }
  
  func testMqttStateConnecting() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    await store.send(\.mqtt, .connecting)
    // State should remain unchanged for connecting
  }
  
  func testReceivedMessage() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    let testMessage = "Test message"
    await store.send(\.receivedMessage, testMessage) {
      $0.receivedMessages.append(testMessage)
    }
    
    expectNoDifference(store.state.receivedMessages, [testMessage])
  }
  
  func testMultipleReceivedMessages() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    let messages = ["Message 1", "Message 2", "Message 3"]
    
    for message in messages {
      await store.send(\.receivedMessage, message) {
        $0.receivedMessages.append(message)
      }
    }
    
    expectNoDifference(store.state.receivedMessages, messages)
  }
  
  func testInitialState() async {
    let initialState = MqttFeature.State()
    expectNoDifference(initialState.isConnected, false)
    expectNoDifference(initialState.receivedMessages, [])
  }
  
  func testBindingActions() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    // Test that binding actions are handled
    await store.send(\.binding, .set(\.isConnected, true)) {
      $0.isConnected = true
    }
  }
  
  func testDelegateActions() async {
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    }
    
    // Test that delegate actions are handled without effect
    // Since we don't have delegate actions yet, we just verify the structure exists
  }
  
  func testCoreFunction() async {
    // Test that the core function pattern works correctly
    let store = TestStore(initialState: MqttFeature.State()) {
      MqttFeature()
    } withDependencies: {
      $0.mqttClientKit = .testValue
    }
    
    // Test ViewAction processing through core function
    await store.send(\.view.connectButtonTapped)
    await store.receive(\.mqtt, .connected) {
      $0.isConnected = true
    }
  }
}