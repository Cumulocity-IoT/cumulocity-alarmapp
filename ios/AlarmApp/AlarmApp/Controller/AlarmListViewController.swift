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

class AlarmListViewController: UITableViewController, AlarmListReloadDelegate, EmptyAlarmsDelegate {
    private var data = C8yAlarmCollection()
    private var selectedAlarm: C8yAlarm?
    private var cancellableSet = Set<AnyCancellable>()
    let filter = AlarmFilter()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = %"alarms_title"
        UITableViewController.prepareForAlarms(with: self.tableView, delegate: self)
        AlarmFilterTableHeader.register(for: self.tableView)

        // Refresh control
        self.tableView.refreshControl = UIRefreshControl()
        self.tableView.refreshControl?.addTarget(self, action: #selector(onPullToRefresh), for: .valueChanged)
        self.fetchAlarms()
    }

    @objc
    private func onPullToRefresh() {
        self.fetchAlarms()
    }

    func fetchAlarms() {
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
                            self.data = C8yAlarmCollection()
                            self.tableView.reloadData()
                            self.tableView.endRefreshing()
                        }
                    },
                    receiveValue: { collection in
                        if collection.managedObjects?.count ?? 0 > 0 {
                            self.fetchAlarms(byFilter: self.filter, byDeviceId: collection.managedObjects?[0].id)
                        } else {
                            // could not find any device
                            self.data = C8yAlarmCollection()
                            self.tableView.reloadData()
                            self.tableView.endRefreshing()
                        }
                    }
                )
                .store(in: &self.cancellableSet)
        } else {
            self.fetchAlarms(byFilter: self.filter, byDeviceId: nil)
        }
    }

    private func fetchAlarms(byFilter filter: AlarmFilter, byDeviceId deviceId: String?) {
        let alarmsApi = Cumulocity.Core.shared.alarms.alarmsApi
        let publisher = alarmsApi.getAlarmsByFilter(filter: filter, source: deviceId)
        publisher.receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    self.tableView.reloadData()
                    self.tableView.endRefreshing()
                },
                receiveValue: { collection in
                    self.data = collection
                }
            )
            .store(in: &self.cancellableSet)
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
        let alarm = data.alarms?[indexPath.item]
        var actions: [UIContextualAction] = []
        let allAlarmStatus = [C8yAlarm.C8yStatus.active, C8yAlarm.C8yStatus.cleared, C8yAlarm.C8yStatus.acknowledged]

        for status in allAlarmStatus where status != alarm?.status {
            let action = UIContextualAction(
                style: .destructive,
                title: status.verb()
            ) { [weak self] _, _, completionHandler in
                self?.changeAlarmStatus(for: alarm, toStatus: status)
                completionHandler(true)
            }
            action.backgroundColor = status.tint()
            actions.append(action)
        }
        return UISwipeActionsConfiguration(actions: actions)
    }

    private func changeAlarmStatus(for alarm: C8yAlarm?, toStatus status: C8yAlarm.C8yStatus) {
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
                        self.fetchAlarms()
                    }
                )
                .store(in: &self.cancellableSet)
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let alarmCount = data.alarms?.count ?? 0
        tableView.backgroundView?.isHidden = alarmCount > 0
        return alarmCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(
            withIdentifier: AlarmListItem.identifier,
            for: indexPath
        ) as? AlarmListItem {
            cell.bind(with: data.alarms?[indexPath.item])
            return cell
        }
        fatalError("Could not create AlarmListItem")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        self.selectedAlarm = data.alarms?[indexPath.item]
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

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == UIStoryboardSegue.toAlarmDetails {
            if let destination = segue.destination as? AlarmDetailsViewController {
                destination.alarm = self.selectedAlarm
            }
        }
    }
}

protocol AlarmListReloadDelegate: AnyObject {
    func fetchAlarms()
}
