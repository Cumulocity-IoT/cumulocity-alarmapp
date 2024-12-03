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

class AlarmSummaryViewController: UIViewController {
    @IBOutlet var systemIdItem: DetailsItem!
    @IBOutlet var lastOccurrenceItem: DetailsItem!
    @IBOutlet var createdAtItem: DetailsItem!
    @IBOutlet var typeItem: DetailsItem!
    @IBOutlet weak var changelogButtonView: UIView!
    @IBOutlet weak var modifySeverityButton: UIButton!
    @IBOutlet weak var modifyStatusButton: UIButton!

    private var cancellableSet = Set<AnyCancellable>()
    var delegate: AlarmUpdate?

    @Published
    var alarm: C8yAlarm?

    @Published
    private var auditRecords: [C8yAuditRecord] = []

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.modifyStatusButton.showsMenuAsPrimaryAction = true
        self.modifyStatusButton.changesSelectionAsPrimaryAction = true
        self.modifySeverityButton.showsMenuAsPrimaryAction = true
        self.modifySeverityButton.changesSelectionAsPrimaryAction = true

        self.$auditRecords.sink { value in
            self.changelogButtonView.isHidden = value.isEmpty
        }
        .store(in: &self.cancellableSet)

        self.$alarm.sink { value in
            self.fetchAuditRecords()
            if let a = value {
                self.systemIdItem.valueLabel.text = a.id
                if let lastOccurred = a.lastUpdated {
                    self.lastOccurrenceItem.valueLabel.text = CumulocityHelper.toReadableDate(lastOccurred)
                }
                if let triggeredAt = a.time {
                    self.createdAtItem.valueLabel.text = CumulocityHelper.toReadableDate(triggeredAt)
                }
                self.typeItem.valueLabel.text = a.type

                if let severity = a.severity {
                    self.modifySeverityButton.menu = UIMenu(children: [
                        self.buildAction(for: C8yAlarm.C8ySeverity.warning, current: severity),
                        self.buildAction(for: C8yAlarm.C8ySeverity.minor, current: severity),
                        self.buildAction(for: C8yAlarm.C8ySeverity.major, current: severity),
                        self.buildAction(for: C8yAlarm.C8ySeverity.critical, current: severity),
                    ])
                }
                if let status = a.status {
                    self.modifyStatusButton.menu = UIMenu(children: [
                        self.buildAction(for: C8yAlarm.C8yStatus.active, current: status),
                        self.buildAction(for: C8yAlarm.C8yStatus.acknowledged, current: status),
                        self.buildAction(for: C8yAlarm.C8yStatus.cleared, current: status),
                    ])
                }
            }
        }
        .store(in: &self.cancellableSet)
    }

    private func buildAction(for severity: C8yAlarm.C8ySeverity, current: C8yAlarm.C8ySeverity) -> UIAction {
        UIAction(
            title: severity.localised(),
            image: severity.icon(),
            state: current == severity ? .on : .off
        ) { _ in
            self.modifySeverityButton.configuration?.showsActivityIndicator = true
            self.updateAlarmSeverity(severity)
        }
    }

    private func buildAction(for status: C8yAlarm.C8yStatus, current: C8yAlarm.C8yStatus) -> UIAction {
        UIAction(
            title: status.localised(),
            image: status.icon(),
            state: current == status ? .on : .off
        ) { _ in
            self.modifyStatusButton.configuration?.showsActivityIndicator = true
            self.updateAlarmStatus(status)
        }
    }

    private func updateAlarmSeverity(_ severity: C8yAlarm.C8ySeverity) {
        if let a = self.alarm, let id = a.id {
            var alarm = C8yAlarm()
            alarm.severity = severity
            self.updateAlarm(alarm, id)
        }
    }

    private func updateAlarmStatus(_ status: C8yAlarm.C8yStatus) {
        if let a = self.alarm, let id = a.id {
            var alarm = C8yAlarm()
            alarm.status = status
            self.updateAlarm(alarm, id)
        }
    }

    private func updateAlarm(_ alarm: C8yAlarm, _ id: String) {
        let alarmsApi = Cumulocity.Core.shared.alarms.alarmsApi
        alarmsApi.updateAlarm(body: alarm, id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    self.modifySeverityButton.configuration?.showsActivityIndicator = false
                    self.modifyStatusButton.configuration?.showsActivityIndicator = false
                },
                receiveValue: { value in
                    self.alarm = value
                    self.delegate?.receivedUpdatedAlarm(alarm: self.alarm)
                }
            )
            .store(in: &self.cancellableSet)
    }

    private func fetchAuditRecords() {
        let auditsApi = Cumulocity.Core.shared.audits.auditsApi
        if let auditSource = alarm {
            auditsApi.getAuditRecords(pageSize: 150, source: auditSource.id)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in
                    },
                    receiveValue: { collection in
                        self.auditRecords =
                            (collection.auditRecords?.sorted {
                                ($0.creationTime ?? "") > ($1.creationTime ?? "")
                            }) ?? []
                    }
                )
                .store(in: &self.cancellableSet)
        }
    }

    @IBAction func onShowChangelogTapped(_ sender: UIButton) {
        let bottomSheetController = AuditRecordsViewController()
        bottomSheetController.data = self.auditRecords
        presentAs(bottomSheet: bottomSheetController, detents: [.medium(), .large()])
    }
}
