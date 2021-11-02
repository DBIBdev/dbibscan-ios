//
//  DatalessTicketValidatorTests.swift
//  PretixScanTests
//
//  Created by Konstantin Kostov on 02/11/2021.
//  Copyright © 2021 rami.io. All rights reserved.
//

import XCTest
@testable import pretixSCAN


class DatalessTicketValidatorTests: XCTestCase {
    private let jsonDecoder = JSONDecoder.iso8601withFractionsDecoder
    
    func testSignedAndValid() throws {
        // arrange
        let qrCode = "E4BibyTSylQOgeKjuMPiTDxi5HXPuTVsx1qCli3IL0143gj0EZXOB9iQInANxRFJTt4Pf9nXnHdB91Qk/RN0L5AIBABSxw2TKFnSUNUCKAEAPAQA"
        let ds = mockDataStore
        let sut = DatalessTicketValidator(dataStore: ds)
        
        // act
        var resultResponse: RedemptionResponse?
        var resultError: Error?
        let expectation = expectation(description: "Redeem")
        sut.redeem(mockCheckInListAllProducts, mockEvent, qrCode, force: false, ignoreUnpaid: false, answers: nil, as: "entry", completionHandler: {(response, err) in
            resultResponse = response
            resultError = err
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 5, handler: nil)
        
        XCTAssertNotNil(resultResponse)
        XCTAssertNil(resultError)
        XCTAssertEqual(resultResponse!.status, .redeemed)
    }
    
    func testSignedAndRevoked() throws {
        // arrange
        let qrCode = "E4BibyTSylQOgeKjuMPiTDxi5HXPuTVsx1qCli3IL0143gj0EZXOB9iQInANxRFJTt4Pf9nXnHdB91Qk/RN0L5AIBABSxw2TKFnSUNUCKAEAPAQA"
        let ds = mockDataStoreRevoked
        let sut = DatalessTicketValidator(dataStore: ds)
        
        // act
        var resultResponse: RedemptionResponse?
        var resultError: Error?
        let expectation = expectation(description: "Redeem")
        sut.redeem(mockCheckInListAllProducts, mockEvent, qrCode, force: false, ignoreUnpaid: false, answers: nil, as: "entry", completionHandler: {(response, err) in
            resultResponse = response
            resultError = err
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 5, handler: nil)
        
        XCTAssertNotNil(resultResponse)
        XCTAssertNil(resultError)
        XCTAssertEqual(resultResponse!.status, .error)
        XCTAssertEqual(resultResponse!.errorReason, .revoked)
    }
    
    func testSignedUnknownProduct() throws {
        // arrange
        let qrCode = "OUmw2Ro3YOMQ4ktAlAIsDVe4Xsr1KXla/0SZVN34qIZWtUX0hx1DXDHxaCatGTNzOeCMjHQABR5E6ESCOOx1g7AIkBhVkdDdJJTVSZWCKAEAPAQA"
        let ds = mockDataStore
        let sut = DatalessTicketValidator(dataStore: ds)
        
        // act
        var resultResponse: RedemptionResponse?
        var resultError: Error?
        let expectation = expectation(description: "Redeem")
        sut.redeem(mockCheckInListAllProducts, mockEvent, qrCode, force: false, ignoreUnpaid: false, answers: nil, as: "entry", completionHandler: {(response, err) in
            resultResponse = response
            resultError = err
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 5, handler: nil)
        
        XCTAssertNotNil(resultResponse)
        XCTAssertNil(resultError)
        XCTAssertEqual(resultResponse!.status, .error)
        XCTAssertEqual(resultResponse!.errorReason, .product)
    }
    
    func testSignedInvalidSignature() throws {
        // arrange
        let qrCode = "EFAKEyTSylQOgeKjuMPiTDxi5HXPuTVsx1qCli3IL0143gj0EZXOB9iQInANxRFJTt4Pf9nXnHdB91Qk/RN0L5AIBABSxw2TKFnSUNUCKAEAPAQA"
        let ds = mockDataStore
        let sut = DatalessTicketValidator(dataStore: ds)
        
        // act
        var resultResponse: RedemptionResponse?
        var resultError: Error?
        let expectation = expectation(description: "Redeem")
        sut.redeem(mockCheckInListAllProducts, mockEvent, qrCode, force: false, ignoreUnpaid: false, answers: nil, as: "entry", completionHandler: {(response, err) in
            resultResponse = response
            resultError = err
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 5, handler: nil)
        
        XCTAssertNotNil(resultResponse)
        XCTAssertNil(resultError)
        XCTAssertEqual(resultResponse!.status, .error)
        XCTAssertEqual(resultResponse!.errorReason, .invalid)
    }
    
    class MockDataStore: DatalessDataStore {
        private let keys: [String]
        private let revoked: [String]
        private let questions: [Question]
        private let items: [Item]
        private let checkIns: [QueuedRedemptionRequest]
        
        var stored: [Codable] = []
        
        init(keys: [String], revoked: [String], questions: [Question], items: [Item], checkIns: [QueuedRedemptionRequest]) {
            self.keys = keys
            self.revoked = revoked
            self.questions = questions
            self.items = items
            self.checkIns = checkIns
        }
        
        func getValidKeys(for event: Event) -> Result<[EventValidKey], Error> {
            .success(keys.map({EventValidKey(secret: $0)}))
        }
        
        func getRevokedKeys(for event: Event) -> Result<[RevokedSecret], Error> {
            .success(revoked.map({RevokedSecret(id: 0, secret: $0)}))
        }
        
        func getItem(by identifier: Identifier, in event: Event) -> Item? {
            return items.first(where: {$0.identifier == identifier})
        }
        
        func getQuestions(for item: Item, in event: Event) -> Result<[Question], Error> {
            return .success(questions)
        }
        
        func getQueuedCheckIns(_ secret: String, eventSlug: String) -> Result<[QueuedRedemptionRequest], Error> {
            return .success(checkIns)
        }
        
        func store<T>(_ resource: T, for event: Event) where T : Model {
            stored.append(resource)
        }
    }
    
    var mockEvent: Event {
        let eventJsonData = testFileContents("event1", "json")
        return try! jsonDecoder.decode(Event.self, from: eventJsonData)
    }
    
    var mockSignedTicket: SignedTicketData {
        let qrCode = "E4BibyTSylQOgeKjuMPiTDxi5HXPuTVsx1qCli3IL0143gj0EZXOB9iQInANxRFJTt4Pf9nXnHdB91Qk/RN0L5AIBABSxw2TKFnSUNUCKAEAPAQA"
        return SignedTicketData(base64: qrCode, keys: mockEvent.validKeys!)!
    }
    
    var mockDataStore: DatalessDataStore {
        return MockDataStore(keys: mockEvent.validKeys!.pems, revoked: [], questions: [], items: mockItems, checkIns: [])
    }
    
    var mockDataStoreRevoked: DatalessDataStore {
        return MockDataStore(keys: mockEvent.validKeys!.pems, revoked: ["E4BibyTSylQOgeKjuMPiTDxi5HXPuTVsx1qCli3IL0143gj0EZXOB9iQInANxRFJTt4Pf9nXnHdB91Qk/RN0L5AIBABSxw2TKFnSUNUCKAEAPAQA"], questions: [], items: mockItems, checkIns: [])
    }
    
    var mockItems: [Item] {
        ["item1", "item2"].map({item -> Item in
            let jsonData = testFileContents(item, "json")
            return try! jsonDecoder.decode(Item.self, from: jsonData)
        })
    }
    
    var mockQuestions: [Question] {
        ["question1", "question2", "question3"].map({item -> Question in
            let jsonData = testFileContents(item, "json")
            return try! jsonDecoder.decode(Question.self, from: jsonData)
        })
    }
    
    var mockCheckInLists: [CheckInList] {
        ["list1", "list2", "list4", "list5"].map({item -> CheckInList in
            let jsonData = testFileContents(item, "json")
            return try! jsonDecoder.decode(CheckInList.self, from: jsonData)
        })
    }
    
    var mockCheckInListAllProducts: CheckInList {
        mockCheckInLists[3]
    }
    
    var mockAnswerableQuestions: [Question] {
        return mockQuestions.filter({$0.askDuringCheckIn})
    }
    
    func answer(for question: Identifier, value: String) -> Answer {
        return Answer(question: question, answer: value, questionStringIdentifier: nil, options: [], optionStringIdentifiers: [])
    }

}
