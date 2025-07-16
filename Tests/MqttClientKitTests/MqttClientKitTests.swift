import Testing
import Foundation
@testable import MqttClientKit

@Test
func testMqttClientKitInfoInit() async throws {
    let info = MqttClientKitInfo(address: "localhost", port: 1883, clientID: "testClient")
    #expect(info.address == "localhost")
    #expect(info.port == 1883)
    #expect(info.clientID == "testClient")
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
func testMqttClientKitStateEquatable() async throws {
    #expect(MqttClientKit.State.idle == .idle)
    #expect(MqttClientKit.State.connected == .connected)
    #expect(MqttClientKit.State.connecting == .connecting)
    #expect(MqttClientKit.State.disconnected(.timeout) == .disconnected(.timeout))
    #expect(MqttClientKit.State.disconnected(.timeout) != .disconnected(.closeUnexpect))
}
