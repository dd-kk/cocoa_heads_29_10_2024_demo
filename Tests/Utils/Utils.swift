//
//  File.swift
//  
//
//  Created by User on 16.10.2024.
//

import Combine
import Foundation
import RemoteAsyncOperation
import XCTest
//====================================================================================================
extension Array {
    mutating func popFirst() -> Element? {
        let result = first
        self = Array(self.dropFirst())
        return result
    }
}
//====================================================================================================
extension OperationUseCaseTests {
//====================================================================================================
    func error422(declineReason: String) -> HTTPError {
        HTTPError(userInfo: ["decline_reason": declineReason])
    }
    
    func error500() -> HTTPError {
        HTTPError(userInfo: [AnyHashable : Any]())
    }
//====================================================================================================
    struct Experiment {
        let putRequestResults: [EtherTakingResult]
        let getRequestResults: [EtherTakingResult]
        let orderDetailsResults: [AcceptedOrderDetailsResult]
        let httpClient = HTTPClientMock()
        let tcpClient = TCPClientMock()
        
        init(
            putRequestResults: [EtherTakingResult],
            getRequestResults: [EtherTakingResult] = [EtherTakingResult](),
            orderDetailsResults: [AcceptedOrderDetailsResult] = [AcceptedOrderDetailsResult]()) {
            self.putRequestResults = putRequestResults
            self.getRequestResults = getRequestResults
            self.orderDetailsResults = orderDetailsResults
        }
//====================================================================================================
        enum AcceptedOrderDetailsResult {
            case details(UUID)
            case error(HTTPError)
        }
        
        private func acceptedOrderDTOs(
            _ results: [AcceptedOrderDetailsResult]
        ) -> [AnyPublisher<AcceptedOrderDetailsDto, HTTPError>] {
            results.map({ result in
                switch result {
                case .details(let uid):
                    Just(AcceptedOrderDetailsDto(uid: uid))
                        .setFailureType(to: HTTPError.self)
                        .eraseToAnyPublisher()
                case .error(let error):
                    Fail<AcceptedOrderDetailsDto, HTTPError>(error: error)
                        .eraseToAnyPublisher()
                }
            })
        }
//====================================================================================================
        func sendTCPReject(
            uid: UUID,
            after delay: TimeInterval,
            reason: String
        ) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                self.tcpClient.etherOrderDeclinedSubject.send(
                    EtherOrderDeclineInfo(
                        uid: uid,
                        reason: reason
                    )
                )
            })
        }
//====================================================================================================
        func sendTCPAccept(
            uid: UUID,
            after delay: TimeInterval
        ) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                self.tcpClient.etherOrderAcceptedSubject.send(
                    uid
                )
            })
        }
//====================================================================================================
        enum EtherTakingResult {
            case accepted
            case processing
            case longProcessing(TimeInterval)
            case declined(String)
            case error(HTTPError)
            case longError(HTTPError, TimeInterval)
        }
//====================================================================================================
        private func etherTakingResponseDTOs(
            _ results: [EtherTakingResult]
        ) -> [AnyPublisher<EtherOrderTakeResponseDto, HTTPError>] {
            return results
                .map { result in
                    switch result {
                    case .accepted:
                        Just(EtherOrderTakeResponseDto(result: .accepted))
                        .setFailureType(to: HTTPError.self)
                        .eraseToAnyPublisher()
                    case .longProcessing(let delay):
                        Just(EtherOrderTakeResponseDto(result: .processing))
                        .delay(for: .seconds(delay), scheduler: RunLoop.main)
                        .setFailureType(to: HTTPError.self)
                        .eraseToAnyPublisher()
                    case .processing:
                        Just(EtherOrderTakeResponseDto(result: .processing))
                        .setFailureType(to: HTTPError.self)
                        .eraseToAnyPublisher()
                    case .declined(let reason):
                        Just(EtherOrderTakeResponseDto(result: .declined(reason)))
                        .setFailureType(to: HTTPError.self)
                        .eraseToAnyPublisher()
                    case .error(let error):
                        Fail<EtherOrderTakeResponseDto, HTTPError>(error: error)
                            .eraseToAnyPublisher()
                    case .longError(let error, let delay):
                        Fail<EtherOrderTakeResponseDto, HTTPError>(error: error)
                            .delay(for: .seconds(delay), scheduler: RunLoop.main)
                            .eraseToAnyPublisher()
                    }
                }
        }
//====================================================================================================
        func setup() -> OperationUseCase {
            // PUT-request mock responses
            var putEtherTakingResponses: [AnyPublisher<EtherOrderTakeResponseDto, HTTPError>] = etherTakingResponseDTOs(
                putRequestResults
            )
            httpClient.takeEtherOrderClosure = { _ -> AnyPublisher<EtherOrderTakeResponseDto, HTTPError> in
                putEtherTakingResponses.popFirst()!
            }
            // GET-request mock responses
            var getEtherTakingResponses: [AnyPublisher<EtherOrderTakeResponseDto, HTTPError>] = etherTakingResponseDTOs(
                getRequestResults
            )
            httpClient.takingOperationStatusClosure = { _ -> AnyPublisher<EtherOrderTakeResponseDto, HTTPError> in
                getEtherTakingResponses.popFirst()!
            }
            // GET order details mock responses
            var orderDetailsResponses: [AnyPublisher<AcceptedOrderDetailsDto, HTTPError>] = acceptedOrderDTOs(
                orderDetailsResults
            )
            httpClient.getAcceptedOrderDetailsClosure = { _ -> AnyPublisher<AcceptedOrderDetailsDto, HTTPError> in
                return orderDetailsResponses.popFirst()!
            }
            return OperationUseCase(
                httpClient: httpClient,
                tcpClient: tcpClient
            )
        }
//====================================================================================================
    }
//====================================================================================================
    func expectSuccess(
        _ useCase: OperationUseCase,
        intervalBetweenRetries: TimeInterval = 0.001,
        delayBeforeFirstGetRequest: TimeInterval = 0.001,
        for expectation: XCTestExpectation
    ) -> AnyCancellable {
        useCase.take(
            etherOrder: etherOrder,
            intervalBetweenRetries: intervalBetweenRetries,
            delayBeforeFirstGetRequest: delayBeforeFirstGetRequest
        )
        .sink { _ in } receiveValue: { acceptedOrder in
            XCTAssertEqual(acceptedOrder.uid, self.etherOrder.uid)
            expectation.fulfill()
        }
    }
//====================================================================================================
    func expectFailure(_ useCase: OperationUseCase, for expectation: XCTestExpectation, reason: String) -> AnyCancellable {
        useCase.take(etherOrder: etherOrder)
            .sink { completion in
                if case .failure(let decline) = completion {
                    XCTAssertEqual(decline.reason, reason)
                    expectation.fulfill()
                }
            } receiveValue: { _ in
            }
    }
//====================================================================================================
}
