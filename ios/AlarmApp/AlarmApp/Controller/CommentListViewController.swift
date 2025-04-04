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

import UIKit

class CommentListViewController: UITableViewController {
    var data: [C8yComment] = []

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UITableViewController.prepareForComments(with: self.tableView)
        // Empty state
        let emptyItem = EmptyCommentsItem()
        tableView.backgroundView = emptyItem
        tableView.backgroundView?.isHidden = true
        self.data = data.sorted {
            $0.time?.localizedCaseInsensitiveCompare($1.time ?? "") == ComparisonResult.orderedDescending
        }
        self.tableView.reloadData()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = data.count
        tableView.backgroundView?.isHidden = count >= 1
        return count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(
            withIdentifier: CommentItem.identifier,
            for: indexPath
        ) as? CommentItem {
            cell.bind(with: data[indexPath.item])
            return cell
        }
        fatalError("Could not create AuditRecordItem")
    }
}
