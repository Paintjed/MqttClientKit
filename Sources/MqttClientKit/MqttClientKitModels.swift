//
//  MqttClientKitModels.swift
//  MqttClientKit
//
//  Created by Jed Lu on 2025/7/15.
//

import Foundation

public typealias Topic = String

public struct MqttClientKitInfo: Equatable, Sendable {
  public var address: String
  public var port: Int
  public var clientID: String

  public init(address: String, port: Int, clientID: String) {
    self.address = address
    self.port = port
    self.clientID = clientID
  }
}

public enum MqttClientKitError: LocalizedError, Equatable, Sendable {
  case timeout
  case closeUnexpect
  case noConnection
  case underlying(Swift.Error)

  public var errorDescription: String? {
    switch self {
    case .timeout:
      "Connection Timeout"
    case .closeUnexpect:
      "Connection Closed Unexpectedly"
    case .underlying:
      "Underlying Error"
    case .noConnection:
      "No Connection"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .timeout:
      "Check if the device's Wi-Fi is connected to the router."
    case .closeUnexpect:
      "Ensure the device stays online during the connection process."
    case .noConnection:
      "No connection"
    case .underlying(let error):
      "\(error.localizedDescription)"
    }
  }

  public static func == (lhs: MqttClientKitError, rhs: MqttClientKitError) -> Bool {
    switch (lhs, rhs) {
    case (.timeout, .timeout),
      (.closeUnexpect, .closeUnexpect),
      (.noConnection, .noConnection):
      true
    case (.underlying(let lhsError), .underlying(let rhsError)):
      lhsError.localizedDescription == rhsError.localizedDescription
    default:
      false
    }
  }
}