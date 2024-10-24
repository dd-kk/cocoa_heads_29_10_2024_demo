//
//  OperationUseCaseTests.swift
//
//
//  Created by User on 15.10.2024.
//


import Combine
import RemoteAsyncOperation
import XCTest

final class OperationUseCaseTests: XCTestCase {
    let etherOrder = EtherOrder(uid: UUID())
    
//====================================================================================================
    func testSimpleTakeOnFirstPutRequest() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted on PUT-request")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testSimpleFailOnFirstPutRequest() throws {
        let expectation = XCTestExpectation(description: "Order declined on PUT-request")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .error(error422(declineReason: "order_cancelled"))
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectFailure(useCase, for: expectation, reason: "order_cancelled")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testSimpleTakeOnSecondPutRequest() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted on PUT-request after retry")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .error(error500()),
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testSimpleDeclineOnSecondPutRequest() throws {
        let expectation = XCTestExpectation(description: "Order declined on second PUT-request after retry by 200 response")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .error(error500()),
                .declined("order_cancelled")
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectFailure(useCase, for: expectation, reason: "order_cancelled")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testSimpleTakeOnFifthPutRequest() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted on PUT-request after 4 retries")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .error(error500()),
                .error(error500()),
                .error(error500()),
                .error(error500()),
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testSimpleTakeOnSecondPutRequestAfterProcessing() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted on PUT-request after getting processing response")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testTakeOnSecondGetRequestAfterProcessing() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted on GET-request after first getting processing response")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .processing,
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testTakeOnThirdGetRequestAfterProcessingAndError() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted on GET-request after first getting processing response and an error")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .processing,
                .error(error500()),
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testDeclineByErrorOnSecondGetRequestAfterProcessing() throws {
        let expectation = XCTestExpectation(description: "Order declined by error on GET-request after first getting processing response")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .processing,
                .error(error422(declineReason: "order_cancelled"))
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectFailure(useCase, for: expectation, reason: "order_cancelled")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testDeclineOnSecondGetRequestAfterProcessing() throws {
        let expectation = XCTestExpectation(description: "Order declined on GET-request after first getting processing response")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .processing,
                .declined("order_cancelled")
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectFailure(useCase, for: expectation, reason: "order_cancelled")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testPutAcceptRequestFirstDetailsRequestFails() throws {
        let expectation = XCTestExpectation(description: "Order accepted on PUT-request and first gets error on details request, but succeds after retry")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .accepted
            ],
            orderDetailsResults: [
                .error(error500()),
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testPutAcceptRequestFirstDetailsRequestFailsFourTimes() throws {
        let expectation = XCTestExpectation(description: "Order accepted on PUT-request and gets error on details request four times, but succeds after fifth retry")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .accepted
            ],
            orderDetailsResults: [
                .error(error500()),
                .error(error500()),
                .error(error500()),
                .error(error500()),
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testTCPAcceptDuringFirstPutRequest() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted by tcp packet while PUT-request returns processing")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .longProcessing(0.1)
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        experiment.sendTCPAccept(uid: etherOrder.uid, after: 0.01)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testTCPDeclineDuringFirstPutRequest() throws {
        let expectation = XCTestExpectation(description: "Order declined by tcp packet while PUT-request returns processing")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .longProcessing(0.1)
            ],
            getRequestResults: [
                .longProcessing(0.1),
                .longProcessing(0.1)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectFailure(useCase, for: expectation, reason: "order_cancelled")
        experiment.sendTCPReject(uid: etherOrder.uid, after: 0.01, reason: "order_cancelled")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testTCPAcceptDuringGetProcessingRequest() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted by tcp packet while GET-request returns processing")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .longProcessing(0.1),
                .longProcessing(0.1)
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        experiment.sendTCPAccept(uid: etherOrder.uid, after: 0.12)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testTCPDeclineDuringGetRequest() throws {
        let expectation = XCTestExpectation(description: "Order declined by tcp packet while GET-request returns processing")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .longProcessing(0.1),
                .longProcessing(0.1)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectFailure(useCase, for: expectation, reason: "order_cancelled")
        experiment.sendTCPReject(uid: etherOrder.uid, after: 0.12, reason: "order_cancelled")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testTCPAcceptDuringPutRequestFailing() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted by tcp packet while PUT-request fails")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .longError(error500(), 0.1),
                .longError(error500(), 0.1),
                .longError(error500(), 0.1)
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        experiment.sendTCPAccept(uid: etherOrder.uid, after: 0.12)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testTCPDeclineDuringPutRequestFailing() throws {
        let expectation = XCTestExpectation(description: "Order declined by tcp packet while PUT-request fails")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .longError(error500(), 0.1),
                .longError(error500(), 0.1),
                .longError(error500(), 0.1)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectFailure(useCase, for: expectation, reason: "order_cancelled")
        experiment.sendTCPReject(
            uid: self.etherOrder.uid,
            after: 0.18,
            reason: "order_cancelled"
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testTCPAcceptIgnoredDueToDifferentUID() throws {
        let expectation = XCTestExpectation(description: "Order declined by error on GET request despite receiving tcp packet for some other accepted order")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .longProcessing(0.05)
            ],
            getRequestResults: [
                .longError(error422(declineReason: "order_cancelled"), 0.05)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectFailure(useCase, for: expectation, reason: "order_cancelled")
        experiment.sendTCPAccept(uid: UUID(), after: 0.02)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testTCPDeclineIgnoredDueToDifferentUID() throws {
        let expectation = XCTestExpectation(description: "Order accepted on GET request despite receiving tcp packet with decline reason for some other order")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .longProcessing(0.1)
            ],
            getRequestResults: [
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(useCase, for: expectation)
        experiment.sendTCPReject(uid: UUID(), after: 0.05, reason: "order_cancelled")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testTCPAcceptDuringFirstPutRequestAfterDetailsFailedThreeTimes() throws {
        let expectation = XCTestExpectation(description: "Order successfully accepted by tcp packet, but order details could be retreived only after four retries")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .longProcessing(0.1)
            ],
            orderDetailsResults: [
                .error(error500()),
                .error(error500()),
                .error(error500()),
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        experiment.sendTCPAccept(
            uid: self.etherOrder.uid,
            after: 0.01
        )
        let cancellable = expectSuccess(useCase, for: expectation)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        wait(for: [expectation], timeout: 0.2)
    }
//====================================================================================================
    func testDelayBeforeFirstGetRequestWorks() throws {
        let expectation = XCTestExpectation(description: "Fisrt GET-request to get operations status is delayed according to specified value")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ]
        )
        let useCase = experiment.setup()
        let cancellable = useCase.take(
            etherOrder: etherOrder,
            delayBeforeFirstGetRequest: 1
        )
            .sink { _ in
                fatalError("Result is supposed to be unknown")
            } receiveValue: { _ in
                fatalError("Result is supposed to be unknown")
            }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: {
            expectation.fulfill()
        })
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testNoDelayBetweenPUTSuccessAndDetailsRequest() throws {
        let expectation = XCTestExpectation(description: "Order details are requested right after it is known to be accepted")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(
            useCase,
            intervalBetweenRetries: 0.2,
            delayBeforeFirstGetRequest: 0.2,
            for: expectation
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testNoDelayBetweenFirstGETSuccessAndDetailsRequest() throws {
        let expectation = XCTestExpectation(description: "Order details are requested right after it is known to be accepted")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(
            useCase,
            intervalBetweenRetries: 0.2,
            for: expectation
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
    func testNoDelayBetweenCommonGETSuccessAndDetailsRequest() throws {
        let expectation = XCTestExpectation(description: "Order details are requested right after it is known to be accepted")
        expectation.assertForOverFulfill = true
        let experiment = Experiment(
            putRequestResults: [
                .processing
            ],
            getRequestResults: [
                .processing,
                .accepted
            ],
            orderDetailsResults: [
                .details(etherOrder.uid)
            ]
        )
        let useCase = experiment.setup()
        let cancellable = expectSuccess(
            useCase,
            intervalBetweenRetries: 0.05,
            for: expectation
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        wait(for: [expectation], timeout: 0.1)
    }
//====================================================================================================
}
