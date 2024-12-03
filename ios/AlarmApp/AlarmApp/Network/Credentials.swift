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

import Foundation
import Strongbox

class Credentials {
    fileprivate enum Keys: String {
        case userName
        case userId
        case tenant
    }

    private static let serviceName = "AlarmingApp"

    var userName: String
    var userId: String = ""
    var password: String
    var tenant: String
    var otp: String?
    var authorization: String?
    var xsrfToken: String?

    init(forUser userName: String, password: String, tenant: String, otp: String? = nil) {
        self.userName = userName
        self.password = password
        self.tenant = tenant
        self.otp = otp
    }

    private init(forUser userName: String, userId: String, password: String, tenant: String, otp: String? = nil) {
        self.userName = userName
        self.userId = userId
        self.password = password
        self.tenant = tenant
        self.otp = otp
    }

    static func defaults() -> PartialCredentials {
        let userName = UserDefaults.standard.string(forKey: Keys.userName.rawValue)
        let tenant = UserDefaults.standard.string(forKey: Keys.tenant.rawValue)
        return PartialCredentials(userName: userName, tenant: tenant)
    }

    static func load() -> Credentials? {
        let userName = UserDefaults.standard.string(forKey: Keys.userName.rawValue)
        let userId = UserDefaults.standard.string(forKey: Keys.userId.rawValue)
        let tenant = UserDefaults.standard.string(forKey: Keys.tenant.rawValue)

        guard let u = userName, let t = tenant, let id = userId else {
            return nil
        }

        guard let properties = Strongbox().unarchive(objectForKey: Self.serviceName) as? [String: String] else {
            return nil
        }

        if let password = properties["password"] {
            return Credentials(forUser: u, userId: id, password: password, tenant: t)
        }
        return nil
    }

    func persist(for userId: String) {
        self.userId = userId
        UserDefaults.standard.set(self.userName, forKey: Keys.userName.rawValue)
        UserDefaults.standard.set(self.userId, forKey: Keys.userId.rawValue)
        UserDefaults.standard.set(self.tenant, forKey: Keys.tenant.rawValue)
        // userName, password are protected by isValid()

        let properties = [
            "password": password,
            "authorization": authorization,
            "xsrfToken": xsrfToken,
        ]
        _ = Strongbox().archive(properties, key: Self.serviceName)
    }

    func remove() {
        // we do not remove user name/id + tenant because we want to ease re-logins
        // UserDefaults.standard.removeObject(forKey: Keys.userName.rawValue)
        // UserDefaults.standard.removeObject(forKey: Keys.tenant.rawValue)
        // UserDefaults.standard.removeObject(forKey: Keys.userId.rawValue)
        _ = Strongbox().remove(key: Self.serviceName)
    }

    func isValid() -> Bool {
        let isValid = !(self.userName.isEmpty && self.tenant.isEmpty && self.password.isEmpty)
        return isValid
    }
}

class PartialCredentials {
    let userName: String
    let tenant: String

    init(userName: String?, tenant: String?) {
        let configuration = Bundle.main.cumulocityConfiguration()
        self.userName = userName ?? configuration?["Username"] as? String ?? ""
        self.tenant = tenant ?? configuration?["Tenant"] as? String ?? ""
    }
}
