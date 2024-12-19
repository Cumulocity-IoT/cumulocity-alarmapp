//
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
import UIKit

extension C8yAlarm.C8yStatus {
    static let allValues = [active, acknowledged, cleared]

    func localised() -> String {
        switch self {
        case .acknowledged:
            return %"alarm_status_acknowledged"

        case .cleared:
            return %"alarm_status_cleared"

        default:
            return %"alarm_status_active"
        }
    }

    func verb() -> String? {
        switch self {
        case .acknowledged:
            return %"alarm_status_acknowledged_verb"

        case .cleared:
            return %"alarm_status_cleared_verb"

        default:
            return %"alarm_status_active_verb"
        }
    }

    func icon() -> UIImage? {
        switch self {
        case .acknowledged:
            return UIImage(named: "ic_alarm_acknowledged")

        case .cleared:
            return UIImage(named: "ic_alarm_cleared")

        default:
            return UIImage(named: "ic_alarm_active")
        }
    }

    func tint() -> UIColor? {
        switch self {
        case .acknowledged:
            return .alarmActionAcknowledge

        case .cleared:
            return .alarmActionClear

        default:
            return .primary
        }
    }
}

extension C8yAlarm.C8ySeverity {
    static let allValues = [critical, major, minor, warning]

    func localised() -> String {
        switch self {
        case .critical:
            return %"alarm_severity_critical"
        case .major:
            return %"alarm_severity_major"
        case .minor:
            return %"alarm_severity_minor"
        default:
            return %"alarm_severity_warning"
        }
    }

    func icon() -> UIImage? {
        switch self {
        case .major:
            return UIImage(named: "ic_alarm_major")

        case .minor:
            return UIImage(named: "ic_alarm_minor")

        case .warning:
            return UIImage(named: "ic_alarm_warning")

        default:
            return UIImage(named: "ic_alarm_critical")
        }
    }

    func tint() -> UIColor? {
        switch self {
        case .major:
            return UIColor(named: "color_major") ?? .black

        case .minor:
            return UIColor(named: "color_minor") ?? .black

        case .warning:
            return UIColor(named: "color_warning") ?? .black

        default:
            return UIColor(named: "color_critical") ?? .black
        }
    }
}
