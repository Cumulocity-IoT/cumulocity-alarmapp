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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var cancellableSet = Set<AnyCancellable>()
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }
        window = UIWindow(windowScene: windowScene)
        window?.makeKeyAndVisible()

        if let credentials = Credentials.load() {
            CumulocityApi.shared().initRequestBuilder(forCredentials: credentials)
            CumulocityApi.shared().userId = credentials.userId
            window?.rootViewController = UIStoryboard.createRootViewController()
        } else {
            window?.rootViewController = UIStoryboard.createSplashViewController()
        }
        if let urlContext = connectionOptions.urlContexts.first {
            handleDeepLink(openingUrl: urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        handleDeepLink(openingUrl: url)
    }

    private func handleDeepLink(openingUrl url: URL) {
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
            let params = components.queryItems
        else {
            return
        }
        if let externalId = params.first(where: { $0.name == "externalId" })?.value {
            resolveDeepLink(withExternalId: externalId)
        } else if let deviceId = params.first(where: { $0.name == "id" })?.value {
            resolveDeepLink(withDevicelId: deviceId)
        }
    }

    func resolveDeepLink(withExternalId externalId: String) {
        if let controller = self.window?.rootViewController as? UINavigationController {
            let externalIdsApi = Cumulocity.Core.shared.identity.externalIDsApi
            externalIdsApi.getExternalId(
                type: "c8y_Serial",
                externalId: externalId
            )
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                },
                receiveValue: { value in
                    if let location = UIStoryboard.createDeviceDetailsViewController() {
                        PushNotificationCenter.shared().receivedExternalId = nil
                        var source = C8yAlarm.C8ySource()
                        source.id = value.managedObject?.id
                        location.source = source
                        controller.pushViewController(location, animated: false)
                    }
                }
            )
            .store(in: &self.cancellableSet)
        } else {
            // We're not logged in!
            PushNotificationCenter.shared().receivedExternalId = externalId
        }
    }

    func resolveDeepLink(withDevicelId deviceId: String) {
        if let controller = self.window?.rootViewController as? UINavigationController {
            let managedObjectsApi = Cumulocity.Core.shared.inventory.managedObjectsApi
            managedObjectsApi.getManagedObject(id: deviceId)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in
                    },
                    receiveValue: { value in
                        if let location = UIStoryboard.createDeviceDetailsViewController() {
                            PushNotificationCenter.shared().receivedDeviceId = nil
                            var source = C8yAlarm.C8ySource()
                            source.id = value.id
                            location.source = source
                            controller.pushViewController(location, animated: false)
                        }
                    }
                )
                .store(in: &self.cancellableSet)
        } else {
            // We're not logged in!
            PushNotificationCenter.shared().receivedDeviceId = deviceId
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
