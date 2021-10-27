//
//  ItemCategoriesDownloader.swift
//  pretixSCAN
//
//  Created by Konstantin Kostov on 27/10/2021.
//  Copyright © 2021 rami.io. All rights reserved.
//

import Foundation

class ItemCategoriesDownloader: ConditionalDownloader<ItemCategory> {
    let model = ItemCategory.self
}
