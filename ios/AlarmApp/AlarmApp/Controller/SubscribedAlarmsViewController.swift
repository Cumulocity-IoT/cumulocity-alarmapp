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

import Combine
import CumulocityCoreLibrary
import UIKit

class SubscribedAlarmsViewController: UITableViewController, SubscribedAlarmListReloadDelegate,
    UITableViewDataSourcePrefetching
{
    private var viewModel = SubscribedAlarmsViewModel()
    private var selectedAlarm: C8yAlarm?
    private var cancellableSet = Set<AnyCancellable>()

    public var openFilterDelegate: EmptyAlarmsDelegate?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UITableViewController.prepareForAlarms(with: self.tableView, delegate: openFilterDelegate)
        self.tableView.prefetchDataSource = self
        self.view.backgroundColor = .clear
        reload()
    }

    func reload() {
        self.viewModel = SubscribedAlarmsViewModel()
        fetchNextAlarms()
    }

    private func fetchNextAlarms() {
        let filter = SubscribedAlarmFilter.shared
        fetchAlarms(byFilter: filter, byDeviceId: filter.resolvedDeviceId)
    }

    private func fetchAlarms(byFilter filter: AlarmFilter, byDeviceId deviceId: String?) {
        let alarmsApi = Cumulocity.Core.shared.alarms.alarmsApi
        let publisher = alarmsApi.getAlarmsByFilter(filter: filter, page: self.viewModel.nextPage(), source: deviceId)
        publisher.receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                },
                receiveValue: { collection in
                    let currentPage = collection.statistics?.currentPage ?? 1
                    self.viewModel.pageStatistics = collection.statistics
                    self.viewModel.alarms.append(contentsOf: collection.alarms ?? [])
                    if currentPage > 1 {
                        let indexPathsToReload = self.viewModel.calculateIndexPathsToReload(
                            from: collection.alarms ?? []
                        )
                        self.onFetchAlarmsCompleted(with: indexPathsToReload)
                    } else {
                        self.onFetchAlarmsCompleted(with: .none)
                    }
                }
            )
            .store(in: &self.cancellableSet)
    }

    private func onFetchAlarmsCompleted(with newIndexPathsToReload: [IndexPath]?) {
        guard let newIndexPathsToReload = newIndexPathsToReload else {
            self.tableView.reloadData()
            return
        }
        let indexPathsToReload = visibleIndexPathsToReload(intersecting: newIndexPathsToReload)
        tableView.reloadRows(at: indexPathsToReload, with: .automatic)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        let hasAlarms = viewModel.currentCount > 0
        tableView.backgroundView?.isHidden = hasAlarms
        return hasAlarms ? 1 : 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.viewModel.totalCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(
            withIdentifier: AlarmListItem.identifier,
            for: indexPath
        ) as? AlarmListItem {
            if isLoadingCell(for: indexPath) {
                cell.bind(with: .none)
            } else {
                cell.bind(with: self.viewModel.alarm(at: indexPath.item))
            }
            return cell
        }
        fatalError("Cannot create AlarmListItem")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        self.selectedAlarm = self.viewModel.alarm(at: indexPath.item)
        performSegue(withIdentifier: UIStoryboardSegue.toAlarmDetails, sender: self)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let view = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: ListViewHeaderItem.identifier
        ) as? ListViewHeaderItem {
            view.separator.titleText = %"dashboard_subscribed_alarms_title"
            view.setBackgroundConfiguration()
            return view
        }
        fatalError("Cannot create ListViewHeaderItem")
    }

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        if indexPaths.contains(where: isLoadingCell) {
            fetchNextAlarms()
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == UIStoryboardSegue.toAlarmDetails {
            if let destination = segue.destination as? AlarmDetailsViewController {
                destination.alarm = self.selectedAlarm
            }
        }
    }
}

extension SubscribedAlarmsViewController {
    /// cell at that index path is beyond the visible alarm count
    fileprivate func isLoadingCell(for indexPath: IndexPath) -> Bool {
        indexPath.row >= viewModel.currentCount
    }

    /// alculates the cells of the table view that need to reload when a new page is received
    fileprivate func visibleIndexPathsToReload(intersecting indexPaths: [IndexPath]) -> [IndexPath] {
        let indexPathsForVisibleRows = tableView.indexPathsForVisibleRows ?? []
        let indexPathsIntersection = Set(indexPathsForVisibleRows).intersection(indexPaths)
        return Array(indexPathsIntersection)
    }
}

final class SubscribedAlarmsViewModel {
    var alarms: [C8yAlarm] = []
    var pageStatistics: C8yPageStatistics? = C8yPageStatistics()

    init() {
    }

    var totalCount: Int {
        pageStatistics?.totalElements ?? 0
    }

    var currentCount: Int {
        alarms.count
    }

    func alarm(at index: Int) -> C8yAlarm? {
        alarms[index]
    }

    func nextPage() -> Int {
        if let currentPage = pageStatistics?.currentPage {
            return currentPage + 1
        } else {
            return 1
        }
    }

    func calculateIndexPathsToReload(from newAlarms: [C8yAlarm]) -> [IndexPath] {
        let startIndex = currentCount - newAlarms.count
        let endIndex = startIndex + newAlarms.count
        return (startIndex..<endIndex).map { IndexPath(row: $0, section: 0) }
    }
}

protocol SubscribedAlarmListReloadDelegate: AnyObject {
    func reload()
}
