//
//  BranchesViewController.swift
//  SwiftHub
//
//  Created by Sygnoos9 on 4/6/19.
//  Copyright © 2019 Khoren Markosyan. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources

private let reuseIdentifier = R.reuseIdentifier.branchCell.identifier

class BranchesViewController: TableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func makeUI() {
        super.makeUI()

        tableView.register(R.nib.branchCell)
    }

    override func bindViewModel() {
        super.bindViewModel()
        guard let viewModel = viewModel as? BranchesViewModel else { return }

        let refresh = Observable.of(Observable.just(()), headerRefreshTrigger).merge()
        let input = BranchesViewModel.Input(headerRefresh: refresh,
                                            footerRefresh: footerRefreshTrigger,
                                            /*
                                                为什么要转为 driver ?
                                             */
                                            selection: tableView.rx.modelSelected(BranchCellViewModel.self).asDriver())
        let output = viewModel.transform(input: input)

        /*
            为什么有的是 drive(onNext: ) 而有的仅仅是 drive() ,比如  output.items
         */
        output.navigationTitle.drive(onNext: { [weak self] (title) in
            self?.navigationTitle = title
        }).disposed(by: rx.disposeBag)

        /*
           为什么不在 viewModel 里面就转好 ? output 的所有参数不应该 driver 类型的 吗
         */
        output.items.asDriver(onErrorJustReturn: [])
            .drive(tableView.rx.items(cellIdentifier: reuseIdentifier, cellType: BranchCell.self)) { tableView, viewModel, cell in
                cell.bind(to: viewModel)
            }.disposed(by: rx.disposeBag)

        viewModel.branchSelected.subscribe(onNext: { [weak self] (branch) in
            self?.navigator.pop(sender: self)
        }).disposed(by: rx.disposeBag)
    }
}
