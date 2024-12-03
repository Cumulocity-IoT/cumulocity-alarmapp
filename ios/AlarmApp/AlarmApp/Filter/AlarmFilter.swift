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

public class AlarmFilter {
    @Published var severity: [C8yAlarm.C8ySeverity] = C8yAlarm.C8ySeverity.allValues
    @Published var status: [C8yAlarm.C8yStatus] = [C8yAlarm.C8yStatus.active]
    var deviceName: String? {
        didSet {
            if let value = self.deviceName {
                if value.isEmpty {
                    self.deviceName = nil
                }
            }
        }
    }
    var alarmType: String? {
        didSet {
            if let value = self.alarmType {
                if value.isEmpty {
                    self.alarmType = nil
                }
            }
        }
    }

    func isSelected(severity: C8yAlarm.C8ySeverity) -> Bool {
        self.severity.contains(severity)
    }

    func isSelected(status: C8yAlarm.C8yStatus) -> Bool {
        self.status.contains(status)
    }

    /// Removes the *severity* if it's selected, otherwise it will be added.
    ///
    /// We'll ensure that there is at least one element in the selection. Having *0* elements is equal to a full selection and thus all elements will be added.
    func invert(severity: C8yAlarm.C8ySeverity) {
        if self.isSelected(severity: severity) {
            let restoreAllValues = self.severity.count == 1
            if restoreAllValues {
                self.severity = C8yAlarm.C8ySeverity.allValues
            } else {
                self.severity.removeAll { $0 == severity }
            }
        } else {
            self.severity.append(severity)
        }
    }

    /// Removes the *status* if it's selected, otherwise it will be added.
    ///
    /// We'll ensure that there is at least one element in the selection. Having *0* elements is equal to a full selection and thus all elements will be added.
    func invert(status: C8yAlarm.C8yStatus) {
        if self.isSelected(status: status) {
            let restoreAllValues = self.status.count == 1
            if restoreAllValues {
                self.status = C8yAlarm.C8yStatus.allValues
            } else {
                self.status.removeAll { $0 == status }
            }
        } else {
            self.status.append(status)
        }
    }

    func filtersAllSeverity() -> Bool {
        isSelected(severity: C8yAlarm.C8ySeverity.critical) && isSelected(severity: C8yAlarm.C8ySeverity.major)
            && isSelected(severity: C8yAlarm.C8ySeverity.minor) && isSelected(severity: C8yAlarm.C8ySeverity.warning)
    }

    func filtersAllStatus() -> Bool {
        isSelected(status: C8yAlarm.C8yStatus.active) && isSelected(status: C8yAlarm.C8yStatus.acknowledged)
            && isSelected(status: C8yAlarm.C8yStatus.cleared)
    }
}
