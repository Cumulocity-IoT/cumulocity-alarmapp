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

class AlarmListViewController: UITableViewController, AlarmListReloadDelegate, EmptyAlarmsDelegate,
    UITableViewDataSourcePrefetching
{
    private var viewModel = PaginatedViewModel()
    private var selectedAlarm: C8yAlarm?
    private var cancellableSet = Set<AnyCancellable>()
    private var resolvedDeviceId: String?
    let filter = AlarmFilter()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = %"alarms_title"
        self.tableView.prefetchDataSource = self
        UITableViewController.prepareForAlarms(with: self.tableView, delegate: self)
        AlarmFilterTableHeader.register(for: self.tableView)

        // Refresh control
        self.tableView.refreshControl = UIRefreshControl()
        self.tableView.refreshControl?.addTarget(self, action: #selector(onPullToRefresh), for: .valueChanged)
        self.reload()
    }

    @objc
    private func onPullToRefresh() {
        self.reload()
    }

    func reload() {
        // filter is modified so we remove everything cached and load again
        self.resolvedDeviceId = nil
        self.viewModel = PaginatedViewModel()
        fetchDeviceNameAndAlarms()
    }

    private func fetchDeviceNameAndAlarms() {
        // we want the table view header to resize correctly
        self.tableView.reloadData()
        if let deviceName = filter.deviceName {
            let managedObjectsApi = Cumulocity.Core.shared.inventory.managedObjectsApi
            let query = CumulocityHelper.queryBy(deviceName: deviceName)
            managedObjectsApi.getManagedObjects(query: query)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        let error = try? completion.error()
                        if error != nil {
                            self.tableView.reloadData()
                            self.tableView.endRefreshing()
                        }
                    },
                    receiveValue: { collection in
                        if collection.managedObjects?.count ?? 0 > 0 {
                            self.resolvedDeviceId = collection.managedObjects?[0].id
                            self.fetchNextAlarms()
                        } else {
                            self.tableView.reloadData()
                            self.tableView.endRefreshing()
                        }
                    }
                )
                .store(in: &self.cancellableSet)
        } else {
            self.fetchNextAlarms()
        }
    }

    private func fetchNextAlarms() {
        fetchAlarms(byFilter: self.filter, byDeviceId: self.resolvedDeviceId)
    }

    private func fetchAlarms(byFilter filter: AlarmFilter, byDeviceId deviceId: String?) {
        guard viewModel.shouldLoadMorePages() else {
            return
        }
        let alarmsApi = Cumulocity.Core.shared.alarms.alarmsApi
        let publisher = alarmsApi.getAlarmsByFilter(filter: filter, page: self.viewModel.nextPage(), source: deviceId)
        publisher.receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    self.tableView.endRefreshing()
                },
                receiveValue: { collection in
                    let currentPage = collection.statistics?.currentPage ?? 1
                    self.viewModel.pageStatistics = collection.statistics
                    self.viewModel.appendAlarms(toPage: currentPage, newAlarms: collection.alarms ?? [])
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

    // MARK: - Actions

    @IBAction func onFilterTapped(_ sender: Any) {
        let detailViewController = UIStoryboard.createAlarmFilterViewController()
        if let controller = detailViewController {
            controller.filter = self.filter
            controller.delegate = self
            presentAs(bottomSheet: controller)
        }
    }

    func onOpenFilterTapped(_ sender: UIButton) {
        onFilterTapped(sender)
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let alarm = self.viewModel.alarm(at: indexPath.item)
        var actions: [UIContextualAction] = []
        let allAlarmStatus = [C8yAlarm.C8yStatus.active, C8yAlarm.C8yStatus.cleared, C8yAlarm.C8yStatus.acknowledged]

        for status in allAlarmStatus where status != alarm?.status {
            let action = UIContextualAction(
                style: .destructive,
                title: status.verb()
            ) { [weak self] _, _, completionHandler in
                self?.changeAlarmStatus(for: alarm, toStatus: status, indexPath: indexPath)
                completionHandler(true)
            }
            action.backgroundColor = status.tint()
            actions.append(action)
        }
        return UISwipeActionsConfiguration(actions: actions)
    }

    private func changeAlarmStatus(for alarm: C8yAlarm?, toStatus status: C8yAlarm.C8yStatus, indexPath: IndexPath) {
        if let id = alarm?.id {
            var alarm = C8yAlarm()
            alarm.status = status
            let alarmsApi = Cumulocity.Core.shared.alarms.alarmsApi
            alarmsApi.updateAlarm(body: alarm, id: id)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in
                    },
                    receiveValue: { _ in
                        // updating a specific alarm could lead to issues with the overall number of elements
                        // e.g. Filter shows only active => you set one alarm from active to clear, list has les elements!
                        self.reload()
                    }
                )
                .store(in: &self.cancellableSet)
        }
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
            if self.viewModel.isLoadingCell(for: indexPath) {
                cell.bind(with: .none)
            } else {
                cell.bind(with: self.viewModel.alarm(at: indexPath.item))
            }
            return cell
        }
        fatalError("Could not create AlarmListItem")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        self.selectedAlarm = self.viewModel.alarm(at: indexPath.item)
        performSegue(withIdentifier: UIStoryboardSegue.toAlarmDetails, sender: self)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard
            let headerView = tableView.dequeueReusableHeaderFooterView(
                withIdentifier: AlarmFilterTableHeader.identifier
            ) as? AlarmFilterTableHeader
        else {
            fatalError("Could not create AlarmFilterTableHeader")
        }
        headerView.alarmFilter = filter
        headerView.setBackgroundConfiguration(with: .background)
        return headerView
    }

    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        if indexPaths.contains(where: self.viewModel.isLoadingCell) {
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

extension AlarmListViewController {
    /// alculates the cells of the table view that need to reload when a new page is received
    fileprivate func visibleIndexPathsToReload(intersecting indexPaths: [IndexPath]) -> [IndexPath] {
        let indexPathsForVisibleRows = tableView.indexPathsForVisibleRows ?? []
        let indexPathsIntersection = Set(indexPathsForVisibleRows).intersection(indexPaths)
        return Array(indexPathsIntersection)
    }
}

protocol AlarmListReloadDelegate: AnyObject {
    func reload()
}
