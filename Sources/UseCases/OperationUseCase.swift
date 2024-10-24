//
//  OperationUseCase.swift
//
//
//  Created by User on 15.10.2024.
//

import Foundation
import Combine

public struct OperationUseCase {
    let httpClient: HTTPClientProtocol
    let tcpClient: TCPClientProtocol
    
    public init(httpClient: HTTPClientProtocol, tcpClient: TCPClientProtocol) {
        self.httpClient = httpClient
        self.tcpClient = tcpClient
    }
}
//==================================================================================================== 
extension OperationUseCase {
    public func take(
        etherOrder: EtherOrder,
        intervalBetweenRetries: TimeInterval = 0.001,
        delayBeforeFirstGetRequest: TimeInterval = 0.001
    ) -> AnyPublisher<AcceptedOrder, OrderTakingFailure> {
        let tcpAccept = tcpPacketAboutAccepted(order: etherOrder)
        let tcpDecline = tcpPacketAboutDeclined(order: etherOrder)
        let httpPublisher = attemptToAccept(
            order: etherOrder,
            intervalBetweenRetries: intervalBetweenRetries,
            delayBeforeFirstGetRequest: delayBeforeFirstGetRequest
        )
        
        return httpPublisher
            .merge(with: tcpAccept)
            .merge(with: tcpDecline)
            .first()
            .flatMap({ result in
                return publish(
                    result: result,
                    for: etherOrder,
                    intervalBetweenRetries: intervalBetweenRetries
                )
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func publish(
        result: EtherTakingOperationResult,
        for etherOrder: EtherOrder,
        intervalBetweenRetries: TimeInterval
    ) -> AnyPublisher<AcceptedOrder, OrderTakingFailure> {
        switch result {
        case .acceptedNoDetails:
            return self.getAcceptedOrderDetails(
                uid: etherOrder.uid,
                intervalBetweenRetries: intervalBetweenRetries
            )
        case .declined(let reason):
            return Fail<AcceptedOrder, OrderTakingFailure>(error: OrderTakingFailure(reason: reason))
                .eraseToAnyPublisher()
        }
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private enum EtherTakingOperationResult {
        case acceptedNoDetails
        case declined(String)
    }
    
    private enum EtherTakingOperationState {
        case putRequestNotAcknowledgedYet
        case putRequestAcknowledgedGetNotStarted
        case runningGetRequests
        case result(EtherTakingOperationResult)
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private struct EtherTakingOperation {
        var state: EtherTakingOperationState
        var order: EtherOrder
        var intervalBetweenRetries: TimeInterval
        var delayBeforeFirstGetRequest: TimeInterval
        
        func move(
            to updatedState: EtherTakingOperationState
        ) -> EtherTakingOperation {
            return EtherTakingOperation(
                state: updatedState,
                order: order,
                intervalBetweenRetries: intervalBetweenRetries,
                delayBeforeFirstGetRequest: delayBeforeFirstGetRequest
            )
        }
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func tcpPacketAboutAccepted(
        order: EtherOrder
    ) -> AnyPublisher<EtherTakingOperationResult, Never> {
        tcpClient.etherOrderAccepted
            .filter({ $0 == order.uid })
            .map({ _ in
                EtherTakingOperationResult.acceptedNoDetails
            })
            .eraseToAnyPublisher()
    }
    
    private func tcpPacketAboutDeclined(
        order: EtherOrder
    ) -> AnyPublisher<EtherTakingOperationResult, Never> {
        tcpClient.etherOrderDeclined
            .filter({ $0.uid == order.uid })
            .map({ info in
                EtherTakingOperationResult.declined(info.reason)
            })
            .eraseToAnyPublisher()
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func getAcceptedOrderDetails(
        uid: UUID,
        intervalBetweenRetries: TimeInterval
    ) -> AnyPublisher<AcceptedOrder, OrderTakingFailure> {
        return httpClient.getAcceptedOrderDetails(uid)
            .map({ dto in
                AcceptedOrder(uid: dto.uid)
            })
            .catch { _ in
                return pause(for: intervalBetweenRetries)
                    .setFailureType(to: OrderTakingFailure.self)
                    .flatMap { _ in
                        return getAcceptedOrderDetails(
                            uid: uid,
                            intervalBetweenRetries: intervalBetweenRetries
                        )
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func parseOperation(
        from error: HTTPError,
        starting operation: EtherTakingOperation
    ) -> EtherTakingOperation {
        if let declineReason = error.userInfo["decline_reason"] as? String {
            return operation.move(
                to: .result(.declined(declineReason))
            )
        } else {
            return operation
        }
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func parseOperation(
        dto: EtherOrderTakeResponseDto,
        starting operation: EtherTakingOperation
    ) -> EtherTakingOperation {
        return switch dto.result {
        case .accepted:
            operation.move(
                to: .result(.acceptedNoDetails)
            )
        case .declined(let reason):
            operation.move(
                to: .result(.declined(reason))
            )
        case .processing:
            switch operation.state {
            case .putRequestNotAcknowledgedYet:
                operation.move(
                    to: .putRequestAcknowledgedGetNotStarted
                )
            default:
                operation.move(
                    to: .runningGetRequests
                )
            }
        }
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func attemptGetRequest(
        starting operation: EtherTakingOperation
    ) -> AnyPublisher<EtherTakingOperation, Never> {
        return httpClient.takingOperationStatus(etherOrder: operation.order.uid)
            .map { dto in
                self.parseOperation(dto: dto, starting: operation)
            }
            .catch({ error in
                Just(self.parseOperation(from: error, starting: operation))
                    .setFailureType(to: Never.self)
            })
            .eraseToAnyPublisher()
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func attemptPutRequest(
        starting operation: EtherTakingOperation
    ) -> AnyPublisher<EtherTakingOperation, Never> {
        return httpClient.take(etherOrder: operation.order.uid)
            .map { dto in
                self.parseOperation(dto: dto, starting: operation)
            }
            .catch({ error in
                Just(self.parseOperation(from: error, starting: operation))
                    .setFailureType(to: Never.self)
            })
            .eraseToAnyPublisher()
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func iterate(
        operation: EtherTakingOperation
    ) -> AnyPublisher<EtherTakingOperation, Never> {
        switch operation.state {
        case .putRequestNotAcknowledgedYet:
            return putRequest(
                starting: operation
            )
        case .putRequestAcknowledgedGetNotStarted:
            return firstGetRequest(
                starting: operation
            )
        case .result:
            return Just(operation)
                .setFailureType(to: Never.self)
                .eraseToAnyPublisher()
        case .runningGetRequests:
            return commonGetRequest(
                starting: operation
            )
        }
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func putRequest(
        starting operation: EtherTakingOperation
    ) -> AnyPublisher<EtherTakingOperation, Never> {
        return attemptPutRequest(starting: operation)
            .flatMap { operation in
                return iterate(
                    operation: operation
                )
            }
            .eraseToAnyPublisher()
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func commonGetRequest(
        starting operation: EtherTakingOperation
    ) -> AnyPublisher<EtherTakingOperation, Never> {
        return attemptGetRequest(starting: operation)
            .flatMap { operation in
                if case .result = operation.state {
                    return iterate(
                        operation: operation
                    )
                } else {
                    return pause(for: operation.intervalBetweenRetries)
                        .flatMap { _ in
                            return iterate(
                                operation: operation
                            )
                        }
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func firstGetRequest(
        starting operation: EtherTakingOperation
    ) -> AnyPublisher<EtherTakingOperation, Never> {
        return pause(for: operation.delayBeforeFirstGetRequest)
            .flatMap { _ in
                attemptGetRequest(starting: operation)
                    .flatMap { operation in
                        if case .result = operation.state {
                            return iterate(
                                operation: operation
                            )
                        } else {
                            return pause(for: operation.intervalBetweenRetries)
                                .flatMap { _ in
                                    return iterate(
                                        operation: operation
                                    )
                                }
                                .eraseToAnyPublisher()
                        }
                    }
            }
            .eraseToAnyPublisher()
    }
}
//==================================================================================================== 
extension OperationUseCase {
    private func attemptToAccept(
        order: EtherOrder,
        intervalBetweenRetries: TimeInterval,
        delayBeforeFirstGetRequest: TimeInterval
    ) -> AnyPublisher<EtherTakingOperationResult, Never> {
        iterate(
            operation: EtherTakingOperation(
                state: .putRequestNotAcknowledgedYet,
                order: order,
                intervalBetweenRetries: intervalBetweenRetries,
                delayBeforeFirstGetRequest: delayBeforeFirstGetRequest
            )
        )
        .compactMap { operation in
            switch operation.state {
            case .result(let etherTakingOperationResult):
                return etherTakingOperationResult
            default:
                return nil
            }
        }
        .eraseToAnyPublisher()
    }
}
//====================================================================================================
