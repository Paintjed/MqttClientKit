//
//  MqttClientKitState.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/7/15.
//

import ComposableArchitecture

extension MqttClientKit {
  @CasePathable
  public enum State: Equatable, Sendable {
    case idle
    case connected
    case connecting
    case disconnected(MqttClientKitError)
  }
}