//
//  CommitCell.swift
//  SwiftHub
//
//  Created by Sygnoos9 on 11/30/18.
//  Copyright © 2018 Khoren Markosyan. All rights reserved.
//

import UIKit
import RxSwift

class CommitCell: DefaultTableViewCell {

    override func makeUI() {
        super.makeUI()
    }

    override func bind(to viewModel: TableViewCellViewModel) {
        super.bind(to: viewModel)
        guard let viewModel = viewModel as? CommitCellViewModel else { return }
        /*
            为什么这里新建了一个 DisposeBag ? EventCell 也是这样的操作  , [ThemeCell,UserCell] 没有 新建  DisposeBag
         
            
         */
        cellDisposeBag = DisposeBag()

        leftImageView.rx.tap().map { _ in viewModel.commit.committer }.filterNil()
            .bind(to: viewModel.userSelected).disposed(by: cellDisposeBag)
    }
}
