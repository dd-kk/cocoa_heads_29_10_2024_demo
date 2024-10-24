//
//  HTTPClientMock.swift
//
//
//  Created by User on 15.10.2024.
//

import Combine
import Foundation
import RemoteAsyncOperation

class HTTPClientMock: HTTPClientProtocol {
    var takeEtherOrderClosure: ((UUID) -> AnyPublisher<EtherOrderTakeResponseDto, HTTPError>)?
    var takingOperationStatusClosure: ((UUID) -> AnyPublisher<EtherOrderTakeResponseDto, HTTPError>)?
    var getAcceptedOrderDetailsClosure: ((UUID) -> AnyPublisher<AcceptedOrderDetailsDto, HTTPError>)?
    
    func take(
        etherOrder: UUID
    ) -> AnyPublisher<EtherOrderTakeResponseDto, HTTPError> {
        return takeEtherOrderClosure.map({ $0(etherOrder) })!
    }
    
    func takingOperationStatus(
        etherOrder: UUID
    ) -> AnyPublisher<EtherOrderTakeResponseDto, HTTPError> {
        return takingOperationStatusClosure.map({ $0(etherOrder) })!
    }
    
    func getAcceptedOrderDetails(
        _ uid: UUID
    ) -> AnyPublisher<AcceptedOrderDetailsDto, HTTPError> {
        return getAcceptedOrderDetailsClosure.map({ $0(uid) })!
    }
}
