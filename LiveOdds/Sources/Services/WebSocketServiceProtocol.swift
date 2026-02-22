import Foundation
import Combine

protocol WebSocketServiceProtocol: AnyObject, Sendable {
    var oddsPublisher: AnyPublisher<Odds, Never> { get }

    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { get }

    var connectionState: ConnectionState { get }

    func connect()
    func disconnect()
}
