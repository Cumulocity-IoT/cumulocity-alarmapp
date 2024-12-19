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

import Combine
import CumulocityCoreLibrary
import JVFloatLabeledTextField
import UIKit

class NewCommentViewController: UIViewController, UITextViewDelegate {
    @IBOutlet var commentTextView: JVFloatLabeledTextView!
    @IBOutlet var shareButton: UIButton!

    private var cancellableSet = Set<AnyCancellable>()
    var delegate: AlarmUpdate?
    var alarm: C8yAlarm?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = %"new_comment_title"
        self.commentTextView.delegate = self
        self.commentTextView.placeholder = %"new_comment_placeholder"
        self.shareButton.isEnabled = false
    }

    func textViewDidChange(_ textView: UITextView) {
        self.shareButton.isEnabled = !textView.text.isEmpty
    }

    @IBAction func onShareCommentTapped(_ sender: Any) {
        if let a = self.alarm, let id = a.id {
            var alarm = C8yAlarm()
            var newComment = C8yComment()
            newComment.text = self.commentTextView.text
            newComment.user = CumulocityApi.shared().userId

            var comments = a[C8yComment.identifier] as? [C8yComment] ?? []
            comments.append(newComment)
            alarm.customFragments = [C8yComment.identifier: comments]
            self.updateAlarm(alarm, id)
        }
    }

    private func updateAlarm(_ alarm: C8yAlarm, _ id: String) {
        self.shareButton.configuration?.showsActivityIndicator = true
        let alarmsApi = Cumulocity.Core.shared.alarms.alarmsApi
        alarmsApi.updateAlarm(body: alarm, id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in
                    self.shareButton.configuration?.showsActivityIndicator = false
                },
                receiveValue: { value in
                    self.alarm = value
                    self.delegate?.receivedUpdatedAlarm(alarm: self.alarm)
                    self.navigationController?.popViewController(animated: true)
                }
            )
            .store(in: &self.cancellableSet)
    }
}
