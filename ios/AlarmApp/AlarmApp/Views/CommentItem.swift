//  Copyright (c) 2022 Software AG, Darmstadt, Germany and/or its licensors
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

import UIKit

class CommentItem: UIView {
    @IBOutlet var textLabel: MaterialLabel!
    @IBOutlet var timeLabel: MaterialLabel!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }

    private func commonInit() {
        self.loadFromNib()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.textLabel.alpha = UIFont.TextEmphasis.full.rawValue
        self.timeLabel.alpha = UIFont.TextEmphasis.medium.rawValue
    }

    func bind(with comment: C8yComment) {
        let text = NSMutableAttributedString()

        let authorText = NSMutableAttributedString(
            string: "@\(comment.user ?? "") ",
            attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body).bold()]
        )
        text.append(authorText)
        let titleText = NSMutableAttributedString(
            string: comment.text ?? "",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.onSurface]
        )
        text.append(titleText)

        self.textLabel.attributedText = text
        self.timeLabel.text = comment.time
    }
}