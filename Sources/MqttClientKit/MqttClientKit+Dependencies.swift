//
//  MqttClientKit+Dependencies.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/7/15.
//

import ComposableArchitecture

extension DependencyValues {
  public var mqttClientKit: MqttClientKit {
    get { self[MqttClientKit.self] }
    set { self[MqttClientKit.self] = newValue }
  }
}