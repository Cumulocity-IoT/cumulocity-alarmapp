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

class DashboardViewController: UIViewController, AlarmListReloadDelegate, EmptyAlarmsDelegate {
    private var cancellableSet = Set<AnyCancellable>()
    private var filteredAlarmSeverity: C8yAlarm.C8ySeverity?
    private var welcomeListDelegate: SubscribedAlarmListReloadDelegate?
    private var deviceSource: C8yAlarm.C8ySource = C8yAlarm.C8ySource()

    @IBOutlet var criticalCountItem: AlarmCountItem!
    @IBOutlet var majorCountItem: AlarmCountItem!
    @IBOutlet var minorCountItem: AlarmCountItem!
    @IBOutlet var warningCountItem: AlarmCountItem!
    @IBOutlet var moreItem: UIBarButtonItem!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = %"dashboard_title"
        fetchAlarmCount()

        // register for Push Notifications
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.registerForPushNotifications()
        // forward to alarm details when notification was received and user not logged in
        if PushNotificationCenter.shared().receivedAlarm != nil {
            self.performSegue(withIdentifier: UIStoryboardSegue.toAlarmDetails, sender: nil)
        }
        self.moreItem.menu = UIMenu(
            title: "",
            children: [
                UIAction(title: %"dashboard_action_logout", image: nil) { _ in
                    self.onLogoutTapped()
                }
            ]
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // forward to whatever value has been passed using URL types
        if let deviceId = PushNotificationCenter.shared().receivedDeviceId,
            let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate
        {
            sceneDelegate.resolveDeepLink(withDevicelId: deviceId)
        } else if let externalId = PushNotificationCenter.shared().receivedExternalId,
            let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate
        {
            sceneDelegate.resolveDeepLink(withExternalId: externalId)
        }
    }

    private func fetchAlarmCount() {
        let alarmsApi = Cumulocity.Core.shared.alarms.alarmsApi
        let arguments = [
            C8yAlarm.C8ySeverity.critical, C8yAlarm.C8ySeverity.major, C8yAlarm.C8ySeverity.minor,
            C8yAlarm.C8ySeverity.warning,
        ]
        let textfields = [self.criticalCountItem, self.majorCountItem, self.minorCountItem, self.warningCountItem]
        arguments.enumerated().publisher
            .flatMap { index, arg in
                alarmsApi.getAlarms(
                    pageSize: 1,
                    severity: [arg.rawValue],
                    status: [C8yAlarm.C8yStatus.active.rawValue],
                    withTotalElements: true
                )
                .map { $0.statistics?.totalElements ?? 0 }
                .receive(on: DispatchQueue.main)
                .catch { _ in Just(0) }
                .map { (index, $0) }
                .eraseToAnyPublisher()
            }
            .sink { index, result in
                textfields[index]?.countLabel.text = String(result ?? 0)
            }
            .store(in: &self.cancellableSet)
    }

    ///  update tag list for receiving push notifications
    func reload() {
        SubscribedAlarmFilter.shared.resolvedDeviceId = nil
        if let deviceName = SubscribedAlarmFilter.shared.deviceName {
            let managedObjectsApi = Cumulocity.Core.shared.inventory.managedObjectsApi
            let query = CumulocityHelper.queryBy(deviceName: deviceName)
            managedObjectsApi.getManagedObjects(query: query)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [self] completion in
                        if (try? completion.error()) != nil {
                            self.reloadAndSaveFilter()
                        }
                    },
                    receiveValue: { collection in
                        if collection.managedObjects?.count ?? 0 > 0 {
                            SubscribedAlarmFilter.shared.resolvedDeviceId = collection.managedObjects?[0].id
                        }
                        self.reloadAndSaveFilter()
                    }
                )
                .store(in: &self.cancellableSet)
        } else {
            reloadAndSaveFilter()
        }
    }

    private func reloadAndSaveFilter() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.subscribeOnTenant()
        SubscribedAlarmFilter.shared.persist()
        self.welcomeListDelegate?.reload()
    }

    // MARK: - Actions

    private func onLogoutTapped() {
        let alert = UIAlertController(title: nil, message: %"dashboard_action_logout.message", preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: %"dashboard_action_logout.confirm", style: .default) { _ in
                self.doLogout()
            }
        )
        alert.addAction(
            UIAlertAction(title: %"dashboard_action_logout.cancel", style: .cancel) { _ in
            }
        )
        self.present(alert, animated: true, completion: nil)
        alert.view.tintColor = .primary
    }

    private func doLogout() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.unsubscribeOnTenant()
        Credentials.load()?.remove()
        SubscribedAlarmFilter.shared.setToDefault()
        UIApplication.shared.keyWindow?.rootViewController = UIStoryboard.createSplashViewController()
    }

    @IBAction func onCriticalAlarmsItemTapped(sender: UITapGestureRecognizer) {
        self.filteredAlarmSeverity = C8yAlarm.C8ySeverity.critical
        self.performSegue(withIdentifier: UIStoryboardSegue.toAlarmsView, sender: nil)
    }

    @IBAction func onMajorAlarmsItemTapped(sender: UITapGestureRecognizer) {
        self.filteredAlarmSeverity = C8yAlarm.C8ySeverity.major
        self.performSegue(withIdentifier: UIStoryboardSegue.toAlarmsView, sender: nil)
    }

    @IBAction func onMinorAlarmsItemTapped(sender: UITapGestureRecognizer) {
        self.filteredAlarmSeverity = C8yAlarm.C8ySeverity.minor
        self.performSegue(withIdentifier: UIStoryboardSegue.toAlarmsView, sender: nil)
    }

    @IBAction func onWarningAlarmsItemTapped(sender: UITapGestureRecognizer) {
        self.filteredAlarmSeverity = C8yAlarm.C8ySeverity.warning
        self.performSegue(withIdentifier: UIStoryboardSegue.toAlarmsView, sender: nil)
    }

    @IBAction func onSeeAllTapped(_ sender: UIButton) {
        self.filteredAlarmSeverity = nil
        self.performSegue(withIdentifier: UIStoryboardSegue.toAlarmsView, sender: nil)
    }

    // MARK: - Navigation

    @IBAction func onFilterIconTapped(_ sender: Any) {
        let detailViewController = UIStoryboard.createSubscribedAlarmFilterViewController()
        if let controller = detailViewController {
            controller.filter = SubscribedAlarmFilter.shared
            controller.delegate = self
            presentAs(bottomSheet: controller)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == UIStoryboardSegue.toAlarmsView {
            if let destination = segue.destination as? AlarmListViewController,
                let severity = self.filteredAlarmSeverity
            {
                destination.filter.severity = [severity]
            }
        } else if segue.identifier == UIStoryboardSegue.toAlarmDetails {
            if let destination = segue.destination as? AlarmDetailsViewController {
                destination.alarm = PushNotificationCenter.shared().receivedAlarm
            }
            PushNotificationCenter.shared().receivedAlarm = nil
        } else if segue.identifier == UIStoryboardSegue.embedWelcomeList {
            if let destination = segue.destination as? SubscribedAlarmsViewController {
                self.welcomeListDelegate = destination
                destination.openFilterDelegate = self
            }
        } else if segue.identifier == UIStoryboardSegue.toDeviceDetails {
            let destination = segue.destination as? DeviceDetailsViewController
            destination?.source = self.deviceSource
        }
    }

    func onOpenFilterTapped(_ sender: UIButton) {
        self.onFilterIconTapped(sender)
    }
}
