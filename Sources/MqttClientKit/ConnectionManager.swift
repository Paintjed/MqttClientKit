//
//  ConnectionManager.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/7/15.
//

import MQTTNIO

package actor ConnectionManager {
  private var connection: MQTTClient?
  
  package func setConnection(_ client: MQTTClient?) {
    connection = client
  }
  
  package func getConnection() throws -> MQTTClient {
    guard let connection else {
      throw MQTTError.noConnection
    }
    return connection
  }
  
  package func clearConnection() {
    connection = nil
  }
  
  package func isConnectionActive() throws -> Bool {
    return try getConnection().isActive()
  }
}