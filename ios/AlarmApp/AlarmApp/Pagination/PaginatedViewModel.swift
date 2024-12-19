//  Copyright (c) 2023 Software AG, Darmstadt, Germany and/or its licensors
//
//  SPDX-License-Identifier: Apache-2.0
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import CumulocityCoreLibrary
import Foundation

struct Page {
    var elements: [C8yAlarm]  // Use a generic type if needed
}

final class PaginatedViewModel {
    private(set) var pages: [Int: Page] = [:]
    var pageStatistics: C8yPageStatistics? = C8yPageStatistics()

    init() {
    }

    var totalCount: Int {
        pageStatistics?.totalElements ?? 0
    }

    var currentCount: Int {
        pages.values.flatMap { $0.elements }.count
    }

    func appendAlarms(toPage pageIndex: Int, newAlarms: [C8yAlarm]) {
        if pages[pageIndex] == nil {
            pages[pageIndex] = Page(elements: [])
        }
        pages[pageIndex]?.elements = newAlarms
    }

    func replaceAlarm(alarm: C8yAlarm, at index: Int) -> Bool {
        var accumulatedIndex = 0
        for (pageNumber, page) in pages {
            let pageSize = page.elements.count
            if index < accumulatedIndex + pageSize {
                let localIndex = index - accumulatedIndex
                print(localIndex)
                pages[pageNumber]?.elements[localIndex] = alarm
                return true
            }
            accumulatedIndex += pageSize
        }
        return false
    }

    func alarm(at index: Int) -> C8yAlarm? {
        guard index >= 0 && index < currentCount else {
            return nil
        }
        // Flatten pages while preserving page order
        let allElements = pages.keys.sorted()
            .compactMap { pages[$0]?.elements }
            .flatMap { $0 }
        return allElements[index]
    }

    func nextPage() -> Int {
        if let currentPage = pageStatistics?.currentPage {
            return currentPage + 1
        } else {
            return 1
        }
    }

    func shouldLoadMorePages() -> Bool {
        if let currentPage = pageStatistics?.currentPage, let totalPages = pageStatistics?.totalPages {
            return currentPage <= totalPages
        } else {
            return true
        }
    }

    func calculateIndexPathsToReload(from newAlarms: [C8yAlarm]) -> [IndexPath] {
        let startIndex = currentCount - newAlarms.count
        let endIndex = startIndex + newAlarms.count
        return (startIndex..<endIndex).map { IndexPath(row: $0, section: 0) }
    }

    /// cell at that index path is beyond the visible alarm count
    func isLoadingCell(for indexPath: IndexPath) -> Bool {
        indexPath.row >= currentCount
    }
}
