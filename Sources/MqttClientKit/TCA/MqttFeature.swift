//
//  MqttFeature.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/8/30.
//
//  A composable MQTT feature that combines publisher and subscriber functionality.
//  This is the recommended approach for new code.

import ComposableArchitecture
import Foundation
import MQTTNIO
import NIOCore
import OSLog

@Reducer
public struct MqttFeature {
  private let logger = Logger(subsystem: "MqttClientKit", category: "MqttFeature")
  
  public init() {}
  
  // MARK: - State
  @ObservableState
  public struct State: Equatable, Sendable {
    public var publisher: MqttPublisherFeature.State
    public var subscriber: MqttSubscriberFeature.State
    
    // Connection management (optional, for unified features)
    public var connectionInfo: MqttClientKitInfo
    public var connectionState: MqttClientKit.State
    public var isConnecting: Bool
    public var showingConnectionSettings: Bool
    
    public init(
      publisher: MqttPublisherFeature.State = MqttPublisherFeature.State(),
      subscriber: MqttSubscriberFeature.State = MqttSubscriberFeature.State(),
      connectionInfo: MqttClientKitInfo = MqttClientKitInfo(
        address: "localhost",
        port: 1883,
        clientID: UUID().uuidString
      ),
      connectionState: MqttClientKit.State = .idle,
      isConnecting: Bool = false,
      showingConnectionSettings: Bool = false
    ) {
      self.publisher = publisher
      self.subscriber = subscriber
      self.connectionInfo = connectionInfo
      self.connectionState = connectionState
      self.isConnecting = isConnecting
      self.showingConnectionSettings = showingConnectionSettings
    }
    
    // Computed properties
    public var isConnected: Bool {
      if case .connected = connectionState {
        return true
      }
      return false
    }
    
    public var canConnect: Bool {
      !isConnecting && !isConnected
    }
    
    public var canDisconnect: Bool {
      isConnected
    }
  }
  
  // MARK: - Actions
  @CasePathable
    public enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
        case view(ViewAction)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        
        // Child feature actions
        case publisher(MqttPublisherFeature.Action)
        case subscriber(MqttSubscriberFeature.Action)
        
        // Connection management actions
        case mqttStateChanged(MqttClientKit.State)
        case connectionEffectStarted
        
        @CasePathable
        public enum ViewAction: Equatable {
            // Lifecycle actions
            case task
            
            // Connection actions
            case connect
            case disconnect
            case showConnectionSettings
            case hideConnectionSettings
        }
        
        @CasePathable
        public enum Delegate: Equatable {
            case connectionStatusChanged(MqttClientKit.State)
            case messagePublished(MQTTPublishInfo)
            case messageReceived(MQTTPublishInfo)
            case subscriptionAdded(MQTTSubscribeInfo)
            case subscriptionRemoved(String)
            case errorOccurred(MqttClientKitError)
        }
    }
  
  // MARK: - Body
  public var body: some ReducerOf<Self> {
    BindingReducer()
    
    Scope(state: \.publisher, action: \.publisher) {
      MqttPublisherFeature()
    }
    
    Scope(state: \.subscriber, action: \.subscriber) {
      MqttSubscriberFeature()
    }
    
    Reduce(core)
  }
  
  // MARK: - Core Reducer
  public func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .view(viewAction):
      return handleViewAction(&state, viewAction)
      
    case .binding:
      return .none
      
    case let .delegate(delegateAction):
      return handleDelegateAction(&state, delegateAction)
      
    case let .publisher(.delegate(publisherDelegate)):
      return handlePublisherDelegate(publisherDelegate)
      
    case let .subscriber(.delegate(subscriberDelegate)):
      return handleSubscriberDelegate(subscriberDelegate)
      
    case .publisher, .subscriber:
      // Child actions are handled by their respective reducers
      return .none
      
    case let .mqttStateChanged(mqttState):
      return handleMqttStateChange(&state, mqttState)
      
    case .connectionEffectStarted:
      state.isConnecting = true
      return .none
    }
  }
}

// MARK: - Private Helper Methods
extension MqttFeature {
  private func handleViewAction(_ state: inout State, _ action: Action.ViewAction) -> Effect<Action> {
    switch action {
    case .task:
      // .task now only handles view lifecycle initialization
      // Message stream will be started when connection is established
      return .none
      
    case .connect:
      return connectToMqtt(state)
      
    case .disconnect:
      return disconnectFromMqtt()
      
    case .showConnectionSettings:
      state.showingConnectionSettings = true
      return .none
      
    case .hideConnectionSettings:
      state.showingConnectionSettings = false
      return .none
    }
  }
  
  private func handleDelegateAction(_ state: inout State, _ action: Action.Delegate) -> Effect<Action> {
    switch action {
    case .connectionStatusChanged, .messagePublished, .messageReceived, 
         .subscriptionAdded, .subscriptionRemoved, .errorOccurred:
      // These are outbound delegate actions, no internal handling needed
      return .none
    }
  }
  
  private func handlePublisherDelegate(_ delegate: MqttPublisherFeature.Action.Delegate) -> Effect<Action> {
    switch delegate {
    case let .messagePublished(publishInfo):
      return .send(.delegate(.messagePublished(publishInfo)))
    case let .publishErrorOccurred(error):
      return .send(.delegate(.errorOccurred(error)))
    }
  }
  
  private func handleSubscriberDelegate(_ delegate: MqttSubscriberFeature.Action.Delegate) -> Effect<Action> {
    switch delegate {
    case let .messageReceived(publishInfo):
      return .send(.delegate(.messageReceived(publishInfo)))
    case let .subscriptionAdded(subscription):
      return .send(.delegate(.subscriptionAdded(subscription)))
    case let .subscriptionRemoved(topicFilter):
      return .send(.delegate(.subscriptionRemoved(topicFilter)))
    case let .errorOccurred(error):
      return .send(.delegate(.errorOccurred(error)))
    }
  }
  
  private func handleMqttStateChange(_ state: inout State, _ mqttState: MqttClientKit.State) -> Effect<Action> {
    state.connectionState = mqttState
    state.isConnecting = false
    
    logger.info("MQTT state changed to: \(String(describing: mqttState))")
    
    var effects: [Effect<Action>] = [.send(.delegate(.connectionStatusChanged(mqttState)))]
    
    // Start message stream when connection is established
    if case .connected = mqttState {
      effects.append(.send(.subscriber(.view(.task))))
    }
    
    return .merge(effects)
  }
  
  private func connectToMqtt(_ state: State) -> Effect<Action> {
    return .run { send in
      await send(.connectionEffectStarted)
      @Dependency(\.mqttClientKit) var mqttClient
      
      let stream = await mqttClient.connect(state.connectionInfo)
      for await mqttState in stream {
        await send(.mqttStateChanged(mqttState))
      }
    }
  }
  
  private func disconnectFromMqtt() -> Effect<Action> {
    return .run { send in
      @Dependency(\.mqttClientKit) var mqttClient
      
      do {
        try await mqttClient.disconnect()
      } catch {
        let mqttError = error as? MqttClientKitError ?? .underlying(error)
        await send(.delegate(.errorOccurred(mqttError)))
      }
    }
  }
}

// MARK: - Convenience Initializers
extension MqttFeature.State {
  /// Initialize with pre-configured subscriptions
  public static func withSubscriptions(_ topics: [String], qos: MQTTQoS = .atMostOnce) -> Self {
    let subscriptions = topics.map { topic in
      MQTTSubscribeInfo(topicFilter: topic, qos: qos)
    }
    
    return Self(
      subscriber: MqttSubscriberFeature.State(
        subscriptions: IdentifiedArrayOf(uniqueElements: subscriptions)
      )
    )
  }
  
  /// Initialize for publish-only use case
  public static func publisherOnly(connectionInfo: MqttClientKitInfo) -> Self {
    return Self(connectionInfo: connectionInfo)
  }
  
  /// Initialize for subscriber-only use case
  public static func subscriberOnly(topics: [String] = [], connectionInfo: MqttClientKitInfo) -> Self {
    return Self.withSubscriptions(topics).with {
      $0.connectionInfo = connectionInfo
    }
  }
}

// MARK: - Helper Extension
private extension MqttFeature.State {
  func with(_ configure: (inout Self) -> Void) -> Self {
    var copy = self
    configure(&copy)
    return copy
  }
}
