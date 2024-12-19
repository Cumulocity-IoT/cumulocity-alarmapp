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

class AlarmFilterTableHeader: UITableViewHeaderFooterView {
    static var identifier = String(describing: AlarmFilterTableHeader.self)

    static var nib: UINib {
        UINib(nibName: identifier, bundle: nil)
    }

    static func register(for tableView: UITableView) {
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: identifier)
    }

    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            self.collectionView.dataSource = self
            FilterChip.register(for: self.collectionView)
            let layout = UICollectionViewCompositionalLayout {
                (_: Int, _: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
                let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(1), heightDimension: .estimated(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.edgeSpacing = NSCollectionLayoutEdgeSpacing(
                    leading: .fixed(8),
                    top: .fixed(8),
                    trailing: nil,
                    bottom: nil
                )
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(1)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 8, leading: 8, bottom: 16, trailing: 16)
                return section
            }
            self.collectionView.collectionViewLayout = layout
        }
    }

    private var filterModel: [AlarmFilterEntry] = []

    var alarmFilter: AlarmFilter? {
        didSet {
            filterModel.removeAll()
            if let filter = self.alarmFilter {
                if filter.filtersAllSeverity() {
                    filterModel.append(AlarmFilterEntry(using: %"alarm_severity_filter_all"))
                } else {
                    for s in filter.severity {
                        filterModel.append(AlarmFilterEntry(using: s.localised()))
                    }
                }
                if filter.filtersAllStatus() {
                    filterModel.append(AlarmFilterEntry(using: %"alarm_status_filter_all"))
                } else {
                    for s in filter.status {
                        filterModel.append(AlarmFilterEntry(using: s.localised()))
                    }
                }
                if let alarmType = filter.alarmType {
                    for singleAlarmType in alarmType.components(separatedBy: ",") {
                        filterModel.append(AlarmFilterEntry(using: singleAlarmType))
                    }
                }
                if let deviceName = filter.deviceName {
                    filterModel.append(AlarmFilterEntry(using: deviceName))
                }
            }
            self.collectionView.reloadData()
        }
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = collectionView.collectionViewLayout.collectionViewContentSize.height
        self.heightConstraint?.constant = height
        self.collectionView.layoutIfNeeded()
    }
}

extension AlarmFilterTableHeader: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        filterModel.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        if let chip = collectionView.dequeueReusableCell(withReuseIdentifier: FilterChip.identifier, for: indexPath)
            as? FilterChip
        {
            chip.label.setTitle(filterModel[indexPath.item].title, for: [])
            return chip
        }
        fatalError("Could not create ")
    }
}

private class AlarmFilterEntry {
    var title: String

    init(using title: String) {
        self.title = title
    }
}
