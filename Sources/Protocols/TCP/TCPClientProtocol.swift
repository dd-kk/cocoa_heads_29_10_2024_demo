//
//  File.swift
//  
//
//  Created by User on 15.10.2024.
//

import Foundation
import Combine

public struct EtherOrderDeclineInfo {
    public let uid: UUID
    public let reason: String
    
    public init(uid: UUID, reason: String) {
        self.uid = uid
        self.reason = reason
    }
}

public protocol TCPClientProtocol {
    var etherOrderAccepted: AnyPublisher<UUID, Never> { get }
    var etherOrderDeclined: AnyPublisher<EtherOrderDeclineInfo, Never> { get }
    // ...
}
