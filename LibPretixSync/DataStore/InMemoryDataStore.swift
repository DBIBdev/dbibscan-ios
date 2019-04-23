//
//  InMemoryDataStore.swift
//  PretixScan
//
//  Created by Daniel Jilg on 15.04.19.
//  Copyright © 2019 rami.io. All rights reserved.
//

import Foundation

/// DataStore that stores data in memory for debugging and testing.
///
/// - Note: See `DataStore` for function level documentation.
public class InMemoryDataStore: DataStore {
    private var lastSynced = [String: String]()
    public func storeLastSynced(_ data: [String: String]) {
        lastSynced = data
    }

    public func retrieveLastSynced() -> [String: String] {
        return lastSynced
    }

    public func store<T: Model>(_ resources: [T], for event: Event) {
        if let orders = resources as? [Order] {
            for order in orders {
                self.orders.insert(order)
            }
        } else if let itemCategories = resources as? [ItemCategory] {
            for itemCategory in itemCategories {
                self.itemCategories.insert(itemCategory)
            }
        } else if let items = resources as? [Item] {
            for item in items {
                self.items.insert(item)
            }
        }
    }

    // MARK: - Internal
    private var orders = Set<Order>()
    private var itemCategories = Set<ItemCategory>()
    private var items = Set<Item>()
}
