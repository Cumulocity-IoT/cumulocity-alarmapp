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

import UIKit

extension UILabel: Localizeable {
    override open func didMoveToSuperview() {
        _ = observe(\.text, options: [.initial, .new]) { _, _ in
            self.text = self.resolveTranslationKey(for: self.text)
        }
    }
}

@IBDesignable
class MaterialLabel: UILabel {
    @IBInspectable var uppercased: Bool = false {
        didSet {
            self.text = text
        }
    }

    override var text: String? {
        didSet {
            if let text = text {
                if text.isTranslationKey() {
                    self.text = resolveTranslationKey(for: text)
                }
                if self.uppercased && !text.elementsEqual(text.uppercased()) {
                    self.text = text.uppercased()
                }
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
    }

    private func commonInit() {
        self.alpha = UIFont.TextEmphasis.full.rawValue
    }
}
