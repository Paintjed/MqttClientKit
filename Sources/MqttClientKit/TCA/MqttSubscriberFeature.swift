//
//  MqttSubscriberFeature.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/8/30.
//

import ComposableArchitecture
import Foundation
import MQTTNIO
import NIOCore
import OSLog

@Reducer
public struct MqttSubscriberFeature {
  private let logger = Logger(subsystem: "MqttClientKit", category: "MqttSubscriberFeature")
  
  public init() {}
  
  // MARK: - State
  @ObservableState
  public struct State: Sendable, Equatable {
    public var subscriptions: IdentifiedArrayOf<MQTTSubscribeInfo>
    public var messages: IdentifiedArrayOf<MQTTPublishInfo>
    public var maxMessages: Int
    public var lastError: MqttClientKitError?
    
    public init(
      subscriptions: IdentifiedArrayOf<MQTTSubscribeInfo> = [],
      messages: IdentifiedArrayOf<MQTTPublishInfo> = [],
      maxMessages: Int = 100,
      lastError: MqttClientKitError? = nil
    ) {
      self.subscriptions = subscriptions
      self.messages = messages
      self.maxMessages = maxMessages
      self.lastError = lastError
    }
    
    // Computed properties
    public var activeSubscriptions: IdentifiedArrayOf<MQTTSubscribeInfo> {
      IdentifiedArrayOf(subscriptions.filter(\.isActive))
    }
    
    public var hasError: Bool {
      lastError != nil
    }
  }
    
    // MARK: - Body
    public var body: some ReducerOf<Self> {
      BindingReducer()
      Reduce(core)
    }
    
}

extension MqttSubscriberFeature {
  // MARK: - Actions
  @CasePathable
  public enum Action: Equatable, BindableAction, ComposableArchitecture.ViewAction {
    case view(ViewAction)
    case binding(BindingAction<State>)
    case delegate(Delegate)
    
    // Internal actions
    case messageReceived(MQTTPublishInfo)
    case subscribeCompleted(String)
    case subscribeFailed(String, MqttClientKitError)
    case unsubscribeCompleted(String)
    case unsubscribeFailed(String, MqttClientKitError)
    case messageStreamStarted
    case messageStreamFailed(MqttClientKitError)
    
    @CasePathable
    public enum ViewAction: Equatable {
      // Subscription management
      case subscribe(MQTTSubscribeInfo)
      case unsubscribe(String)
      
      // Message management
      case clearMessages
      case clearError
      
      // UI actions
      case task
    }
    
    @CasePathable
    public enum Delegate: Equatable {
      case messageReceived(MQTTPublishInfo)
      case subscriptionAdded(MQTTSubscribeInfo)
      case subscriptionRemoved(String)
      case errorOccurred(MqttClientKitError)
    }
  }
    
  // MARK: - Core Reducer
  public func core(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .view(viewAction):
      return handleViewAction(&state, viewAction)
      
    case .binding:
      // Clear error when user interacts
      state.lastError = nil
      return .none
      
    case let .delegate(delegateAction):
      return handleDelegateAction(&state, delegateAction)
      
    case let .messageReceived(publishInfo):
      return handleMessageReceived(&state, publishInfo)
      
    case let .subscribeCompleted(topicFilter):
      logger.info("Successfully subscribed to: \(topicFilter)")
      return .none
      
    case let .subscribeFailed(topicFilter, error):
      if let index = state.subscriptions.firstIndex(where: { $0.topicFilter == topicFilter }) {
        state.subscriptions.remove(id: state.subscriptions[index].id)
      }
      state.lastError = error
      logger.error("Failed to subscribe to \(topicFilter): \(error.localizedDescription)")
      return .send(.delegate(.errorOccurred(error)))
      
    case let .unsubscribeCompleted(topicFilter):
      if let index = state.subscriptions.firstIndex(where: { $0.topicFilter == topicFilter }) {
        let subscription = state.subscriptions[index]
        state.subscriptions.remove(id: subscription.id)
        logger.info("Successfully unsubscribed from: \(topicFilter)")
        return .send(.delegate(.subscriptionRemoved(topicFilter)))
      }
      return .none
      
    case let .unsubscribeFailed(topicFilter, error):
      state.lastError = error
      logger.error("Failed to unsubscribe from \(topicFilter): \(error.localizedDescription)")
      return .send(.delegate(.errorOccurred(error)))
      
    case .messageStreamStarted:
      logger.info("Message stream started")
      return .none
      
    case let .messageStreamFailed(error):
      state.lastError = error
      logger.error("Message stream failed: \(error.localizedDescription)")
      return .send(.delegate(.errorOccurred(error)))
    }
  }
}

// MARK: - Private Helper Methods
extension MqttSubscriberFeature {
  private func handleViewAction(_ state: inout State, _ action: Action.ViewAction) -> Effect<Action> {
    switch action {
    case let .subscribe(subscribeInfo):
      return addSubscription(&state, subscribeInfo)
      
    case let .unsubscribe(subscriptionID):
      return removeSubscription(&state, subscriptionID)
      
    case .clearMessages:
      state.messages.removeAll()
      return .none
      
    case .clearError:
      state.lastError = nil
      return .none
      
    case .task:
      return startMessageStream()
    }
  }
  
  private func handleDelegateAction(_ state: inout State, _ action: Action.Delegate) -> Effect<Action> {
    switch action {
    case .messageReceived, .subscriptionAdded, .subscriptionRemoved, .errorOccurred:
      // These are outbound delegate actions, no internal handling needed
      return .none
    }
  }
  
  private func handleMessageReceived(_ state: inout State, _ publishInfo: MQTTPublishInfo) -> Effect<Action> {
    state.messages.append(publishInfo)
    
    // Keep only last maxMessages messages for performance
    if state.messages.count > state.maxMessages {
      state.messages.removeFirst()
    }
    
    return .send(.delegate(.messageReceived(publishInfo)))
  }
  
  private func addSubscription(_ state: inout State, _ subscribeInfo: MQTTSubscribeInfo) -> Effect<Action> {
    state.subscriptions.append(subscribeInfo)
    
    let topicFilter = subscribeInfo.topicFilter
    
    return .run { send in
      @Dependency(\.mqttClientKit) var mqttClient
      
      do {
        // Check if client is active before subscribing
        guard try await mqttClient.isActive() else {
          throw MqttClientKitError.noConnection
        }
        
        _ = try await mqttClient.subscribe(subscribeInfo)
        await send(.subscribeCompleted(topicFilter))
        await send(.delegate(.subscriptionAdded(subscribeInfo)))
      } catch {
        let mqttError = error as? MqttClientKitError ?? .underlying(error)
        await send(.subscribeFailed(topicFilter, mqttError))
      }
    }
  }
  
  private func removeSubscription(_ state: inout State, _ subscriptionID: String) -> Effect<Action> {
    guard let subscription = state.subscriptions[id: subscriptionID] else {
      return .none
    }
    
    let topicFilter = subscription.topicFilter
    
    return .run { send in
      @Dependency(\.mqttClientKit) var mqttClient
      
      do {
        // Check if client is active before unsubscribing
        guard try await mqttClient.isActive() else {
          throw MqttClientKitError.noConnection
        }
        
        try await mqttClient.unsubscribe(topicFilter)
        await send(.unsubscribeCompleted(topicFilter))
      } catch {
        let mqttError = error as? MqttClientKitError ?? .underlying(error)
        await send(.unsubscribeFailed(topicFilter, mqttError))
      }
    }
  }
  
  private func startMessageStream() -> Effect<Action> {
    return .run { send in
      await send(.messageStreamStarted)
      @Dependency(\.mqttClientKit) var mqttClient
      
      do {
        let stream = mqttClient.received()
        for try await publishInfo in stream {
          await send(.messageReceived(publishInfo))
        }
      } catch {
        let mqttError = error as? MqttClientKitError ?? .underlying(error)
        await send(.messageStreamFailed(mqttError))
      }
    }
  }
}