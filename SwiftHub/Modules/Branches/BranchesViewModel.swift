//
//  BranchesViewModel.swift
//  SwiftHub
//
//  Created by Sygnoos9 on 4/6/19.
//  Copyright © 2019 Khoren Markosyan. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift

class BranchesViewModel: ViewModel, ViewModelType {

    struct Input {
        let headerRefresh: Observable<Void>
        let footerRefresh: Observable<Void>
        /*
            为啥这个 property 不是 Observable<BranchCellViewModel> ?
            估计是为了告诉我们,这个 selection 的 subscriber 运算非常快,不会 block 吧 ?
            不管怎样, 我觉得还是 统一为 Observable 比较好
         */
        let selection: Driver<BranchCellViewModel>
    }

    struct Output {
        let navigationTitle: Driver<String>
        /*
            为啥不是  BehaviorRelay<[BranchCellViewModel]> . 而是让 ViewController 执行 asDriver ? 是因为不知道出错了如何处理 ,所以让 ViewControll而 自行解决吗?
         */
        let items: Driver<[BranchCellViewModel]>
    }

    /*
        看来 viewModel 还是有 状态的 , 我还以为他们可以做到 always stateless
     
        另外一点: 所有 viewModel 的 state 的修改, 必须统一在 UI thread  进行修改 ,这样才可以做到 同步 ,不会出现数据不一致的情况
     */
    let repository: BehaviorRelay<Repository>
    let branchSelected = PublishSubject<Branch>()

    init(repository: Repository, provider: SwiftHubAPI) {
        self.repository = BehaviorRelay(value: repository)
        super.init(provider: provider)
    }

    func transform(input: Input) -> Output {

        let elements = BehaviorRelay<[BranchCellViewModel]>(value: [])

        input.headerRefresh.flatMapLatest({ [weak self] () -> Observable<[BranchCellViewModel]> in
            guard let self = self else { return Observable.just([]) }
            self.page = 1
            return self.request()
                .trackActivity(self.headerLoading)
        })
            .subscribe(onNext: { (items) in
                elements.accept(items)
            }).disposed(by: rx.disposeBag)

        input.footerRefresh.flatMapLatest({ [weak self] () -> Observable<[BranchCellViewModel]> in
            guard let self = self else { return Observable.just([]) }
            /*
                在 flatMapLatest 里面 修改 self 的状态 ,不符合 rx 的使用原则吧 ? 应该在 do operator 里面操作才对
                比如: 修改 request 方法, 新增一个 page 参数 , 然后 return self.request(self.page + 1).trackActivity(self.footerLoading)
                    然后在 do operator 里面执行 self.page += 1
                
                怎么听起来一点都不轻松 ?
             */
            self.page += 1
            return self.request()
                .trackActivity(self.footerLoading)
        })
            .subscribe(onNext: { (items) in
                elements.accept(elements.value + items)
            }).disposed(by: rx.disposeBag)

        let navigationTitle = repository.map({ (repository) -> String in
            return repository.fullname ?? ""
        }).asDriver(onErrorJustReturn: "")

        /*
            将 view 的 input 绑定到 viewModel 的 state
         */
        input.selection.asObservable().map { $0.branch }.bind(to: branchSelected).disposed(by: rx.disposeBag)

        return Output(navigationTitle: navigationTitle,
                      items: elements)
    }

    func request() -> Observable<[BranchCellViewModel]> {
        let fullname = repository.value.fullname ?? ""
        return provider.branches(fullname: fullname, page: page)
            .trackActivity(loading)
            .trackError(error)
            .map { $0.map({ (branch) -> BranchCellViewModel in
                let viewModel = BranchCellViewModel(with: branch)
                return viewModel
            })}
    }
}
