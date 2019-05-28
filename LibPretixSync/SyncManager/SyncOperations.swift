//
//  SyncOperations.swift
//  PretixScan
//
//  Created by Daniel Jilg on 04.05.19.
//  Copyright © 2019 rami.io. All rights reserved.
//

import Foundation

class APIClientOperation: Operation {
    // MARK: - Public Properties
    let apiClient: APIClient
    let event: Event
    let checkInList: CheckInList
    let dataStore: DataStore

    /// If not nil, the error that occurred during fetch
    var error: Error?

    // MARK: - Private Properties
    fileprivate var urlSessionTask: URLSessionTask?

    // MARK: - KVO Property Management
    private var _executing = false
    private var _finished = false

    override var isAsynchronous: Bool { return true }

    override var isExecuting: Bool {
        get {
            return _executing
        } set {
            willChangeValue(forKey: "isExecuting")
            _executing = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }

    override var isFinished: Bool {
        get {
            return _finished
        } set {
            willChangeValue(forKey: "isFinished")
            _finished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }

    init(apiClient: APIClient, dataStore: DataStore, event: Event, checkInList: CheckInList) {
        self.apiClient = apiClient
        self.event = event
        self.checkInList = checkInList
        self.dataStore = dataStore
    }

    // MARK: - Management Methods
    override func start() {
        if isCancelled {
            return
        }

        isExecuting = true

        // Override this method to do actual work

        completeOperation()
    }

    func completeOperation() {
        isFinished = true
        isExecuting = false
    }

    override func cancel() {
        super.cancel()
        if isExecuting {
            isFinished = true
            isExecuting = false
        }

        urlSessionTask?.cancel()
    }
}

class FullDownloader<T: Model>: APIClientOperation {
    // TODO: Fix a bug where finish notifications are sent out of order

    override func start() {
        if isCancelled {
            completeOperation()
        }

        isExecuting = true

        if dataStore.lastSyncTime(of: T.self, in: event) != nil {
            // full sync already happened, we don't need to do anything
            completeOperation()
        }

        urlSessionTask = apiClient.getTask(T.self, lastUpdated: nil) { result in
            switch result {
            case .success(let pagedList):
                let isLastPage = pagedList.next == nil
                let isFirstPage = pagedList.previous == nil

                // Notify Listeners
                NotificationCenter.default.post(name: SyncManager.syncStatusUpdateNotification, object: self, userInfo: [
                    SyncManager.NotificationKeys.model: T.self.humanReadableName,
                    SyncManager.NotificationKeys.loadedAmount: pagedList.results.count,
                    SyncManager.NotificationKeys.totalAmount: pagedList.count,
                    SyncManager.NotificationKeys.isLastPage: isLastPage])

                // Store Data
                self.dataStore.store(pagedList.results, for: self.event)

                if isFirstPage, let generatedAt = pagedList.generatedAt {
                    self.dataStore.setLastSyncTime(generatedAt, of: T.self, in: self.event)
                }

                if isLastPage {
                    // We are done
                    self.completeOperation()
                }
            case .failure(let error):
                self.error = error
                self.completeOperation()
            }

        }
        urlSessionTask?.resume()
    }
}

class PartialDownloader<T: Model>: APIClientOperation {
    override func start() {
        if isCancelled {
            completeOperation()
        }

        isExecuting = true

        // TODO: This seems to not be updated
        let lastUpdated = dataStore.lastSyncTime(of: T.self, in: event)

        urlSessionTask = apiClient.getTask(T.self, lastUpdated: lastUpdated) { result in
            switch result {
            case .success(let pagedList):
                let isLastPage = pagedList.next == nil

                // Notify Listeners
                NotificationCenter.default.post(name: SyncManager.syncStatusUpdateNotification, object: self, userInfo: [
                    SyncManager.NotificationKeys.model: T.self.humanReadableName,
                    SyncManager.NotificationKeys.loadedAmount: pagedList.results.count,
                    SyncManager.NotificationKeys.totalAmount: pagedList.count,
                    SyncManager.NotificationKeys.isLastPage: isLastPage])

                // Store Data
                self.dataStore.store(pagedList.results, for: self.event)

                if isLastPage {
                    // We are done
                    self.dataStore.setLastSyncTime(pagedList.generatedAt ?? "", of: T.self, in: self.event)
                    self.completeOperation()
                }
            case .failure(let error):
                self.error = error
                self.completeOperation()
            }

        }
        urlSessionTask?.resume()
    }
}

class ItemCategoriesDownloader: FullDownloader<ItemCategory> {
    let model = ItemCategory.self
}

class ItemsDownloader: FullDownloader<Item> {
    let model = Item.self
}

class FullOrderDownloader: FullDownloader<Order> {
    let model = Order.self
}

class PartialOrderDownloader: PartialDownloader<Order> {
    let model = Order.self
}

class SubEventsDownloader: FullDownloader<SubEvent> {
    let model = SubEvent.self
}

class QueuedRedemptionRequestsUploader: APIClientOperation {
    var errorReason: RedemptionResponse.ErrorReason?
    var shouldRepeat = true

    override func start() {
        if isCancelled {
            completeOperation()
        }

        isExecuting = true

        guard let nextRedemptionRequest = dataStore.getRedemptionRequest(in: event) else {
            // No more queued redemption requests, so we don't need to do anything, and not add more uploads to the queue
            self.shouldRepeat = false
            self.completeOperation()
            return
        }

        urlSessionTask = apiClient.redeemTask(
            secret: nextRedemptionRequest.secret,
            force: nextRedemptionRequest.redemptionRequest.force,
            ignoreUnpaid: nextRedemptionRequest.redemptionRequest.ignoreUnpaid) { result, error in
                // Handle HTTP errors
                // When HTTP errors occur, we do not want to remove the queued redemption request, since it probably didn't reach the server
                if let error = error {
                    self.error = error

                    if let apiError = error as? APIError {
                        switch apiError {
                        case .forbidden, .notFound:
                            // This is probably a malformed request and will never go through.
                            // Continue on and let the queued request be deleted.
                            break
                        default:
                            self.completeOperation()
                            return
                        }
                    } else {
                        self.completeOperation()
                        return
                    }
                }

                // Response Errors
                // Response errors mean the server has received our request correctly and has declined it for some reason
                // (e.g. already checked in). In that case, we can't do anything, because the check in happened in the past.
                self.errorReason = result?.errorReason

                // Done, delete the queued redemption request
                self.dataStore.delete(nextRedemptionRequest, in: self.event)

                // The instantiator of this class should queue more operations in the completion block.
                self.shouldRepeat = true
                self.completeOperation()
        }
        urlSessionTask?.resume()
    }
}
