//
//  TCPClientMock.swift
//
//
//  Created by User on 15.10.2024.
//

import Combine
import Foundation
import RemoteAsyncOperation

class TCPClientMock: TCPClientProtocol {
    var etherOrderAcceptedSubject = PassthroughSubject<UUID, Never>()
    var etherOrderDeclinedSubject = PassthroughSubject<EtherOrderDeclineInfo, Never>()
    
    var etherOrderAccepted: AnyPublisher<UUID, Never> {
        etherOrderAcceptedSubject
            .eraseToAnyPublisher()
    }
    var etherOrderDeclined: AnyPublisher<EtherOrderDeclineInfo, Never> {
        etherOrderDeclinedSubject
            .eraseToAnyPublisher()
    }
}
