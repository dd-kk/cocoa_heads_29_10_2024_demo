//
//  File.swift
//  
//
//  Created by User on 15.10.2024.
//

import Foundation
import Combine

public protocol HTTPClientProtocol {
    func take(
        etherOrder: UUID
    ) -> AnyPublisher<EtherOrderTakeResponseDto, HTTPError>
    
    func takingOperationStatus(
        etherOrder: UUID
    ) -> AnyPublisher<EtherOrderTakeResponseDto, HTTPError>
    
    func getAcceptedOrderDetails(
        _ uid: UUID
    ) -> AnyPublisher<AcceptedOrderDetailsDto, HTTPError>
}
