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

class AlarmFilterViewController: UIViewController {
    @IBOutlet var criticalButton: UIButton!
    @IBOutlet var majorButton: UIButton!
    @IBOutlet var minorButton: UIButton!
    @IBOutlet var warningButton: UIButton!
    @IBOutlet var activeButton: UIButton!
    @IBOutlet var acknowledgedButton: UIButton!
    @IBOutlet var clearedButton: UIButton!
    @IBOutlet var deviceNameTextfield: UITextField!
    @IBOutlet var alarmTypeTextfield: UITextField!

    private var cancellableSet = Set<AnyCancellable>()
    var filter = AlarmFilter()
    var delegate: AlarmListReloadDelegate?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.reload()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.deviceNameTextfield.text = self.filter.deviceName
        self.alarmTypeTextfield.text = self.filter.alarmType
        configure(self.criticalButton, isSelected: filter.isSelected(severity: C8yAlarm.C8ySeverity.critical))
        configure(self.majorButton, isSelected: filter.isSelected(severity: C8yAlarm.C8ySeverity.major))
        configure(self.minorButton, isSelected: filter.isSelected(severity: C8yAlarm.C8ySeverity.minor))
        configure(self.warningButton, isSelected: filter.isSelected(severity: C8yAlarm.C8ySeverity.warning))
        configure(self.activeButton, isSelected: filter.isSelected(status: C8yAlarm.C8yStatus.active))
        configure(self.acknowledgedButton, isSelected: filter.isSelected(status: C8yAlarm.C8yStatus.acknowledged))
        configure(self.clearedButton, isSelected: filter.isSelected(status: C8yAlarm.C8yStatus.cleared))

        self.filter.$severity.sink { values in
            self.criticalButton.isSelected = values.contains(C8yAlarm.C8ySeverity.critical)
            self.majorButton.isSelected = values.contains(C8yAlarm.C8ySeverity.major)
            self.minorButton.isSelected = values.contains(C8yAlarm.C8ySeverity.minor)
            self.warningButton.isSelected = values.contains(C8yAlarm.C8ySeverity.warning)
        }
        .store(in: &self.cancellableSet)
        self.filter.$status.sink { values in
            self.activeButton.isSelected = values.contains(C8yAlarm.C8yStatus.active)
            self.acknowledgedButton.isSelected = values.contains(C8yAlarm.C8yStatus.acknowledged)
            self.clearedButton.isSelected = values.contains(C8yAlarm.C8yStatus.cleared)
        }
        .store(in: &self.cancellableSet)
    }

    private func configure(_ button: UIButton, isSelected: Bool = false) {
        button.changesSelectionAsPrimaryAction = true
        button.configuration?.background.backgroundColorTransformer = UIConfigurationColorTransformer { _ in
            .primaryContainer
        }
        button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var container = incoming
            container.foregroundColor = button.isSelected ? .primary : .onBackground
            return container
        }
        button.configuration?.buttonSize = .mini
        button.isSelected = isSelected
    }

    @IBAction func onCriticalTapped(_ sender: UIButton) {
        self.filter.invert(severity: C8yAlarm.C8ySeverity.critical)
    }

    @IBAction func onMajorTapped(_ sender: UIButton) {
        self.filter.invert(severity: C8yAlarm.C8ySeverity.major)
    }

    @IBAction func onMinorTapped(_ sender: UIButton) {
        self.filter.invert(severity: C8yAlarm.C8ySeverity.minor)
    }

    @IBAction func onWarningTapped(_ sender: UIButton) {
        self.filter.invert(severity: C8yAlarm.C8ySeverity.warning)
    }

    @IBAction func onActiveTapped(_ sender: UIButton) {
        self.filter.invert(status: C8yAlarm.C8yStatus.active)
    }

    @IBAction func onAcknowledgedTapped(_ sender: UIButton) {
        self.filter.invert(status: C8yAlarm.C8yStatus.acknowledged)
    }

    @IBAction func onClearedTapped(_ sender: UIButton) {
        self.filter.invert(status: C8yAlarm.C8yStatus.cleared)
    }

    @IBAction func onDeviceNameChanged(_ sender: UITextField) {
        self.filter.deviceName = sender.text
    }

    @IBAction func onAlarmTypeChanged(_ sender: UITextField) {
        self.filter.alarmType = sender.text
    }
}
