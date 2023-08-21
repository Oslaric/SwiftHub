## 总结 
### ViewModel 是对 View 的抽象建模 
ViewModel 相当于对 View 的 接口进行编程 ,而不是对具体的实现进行编程 . 
这样的好处是 ,我们可以换一个 UI 框架 ,而 ViewModel , Model 都可以复用 .
比如 ,我们在 iOS 端就用 UIKit ,但是在 macos 端我们可以用 AppKit 或者其他的 .  
而  ViewModel , Model 等 模块均可以不用改动就直接 reuse  .  

这就是 对接口进行编程(控制反转) 的原则 带来的威力 .





#### ViewModel 与 Model/Service  之间 ,以 protocol 的方式进行联系 . 通过 ViewModel 的 init 函数进行依赖注入 .
例子1

```swift
    # IssuesViewModel 
    # 通过 protocol ,就是边界 思维的体现 
    init(repository: Repository, provider: SwiftHubAPI) {
        self.repository = BehaviorRelay(value: repository)
        super.init(provider: provider)
        if let fullname = repository.fullname {
            analytics.log(.issues(fullname: fullname))
        }
    }
```

例子2
```swift
    # ViewModel 这个 基类 的 构造器 , 依赖的 service(叫做 api 或者 model 都行) 都是通过 init 函数注入 , 最简单的依赖注意方案 
    init(provider: SwiftHubAPI) {
    }
```

#### Cell 与 CellViewModel

Cell 只被动接收 CellViewModel 的  case
```
//  BranchCellViewModel 只是负责接收 信息 ,这些信息后面会被  Cell 消费掉 , 信息从 BranchCellViewModel 单向流向 Cell 
BranchCellViewModel
```
为什么 CellViewModel 的属性都是 behaviorRelay  ?


Cell 发送消息给 CellViewModel 的例子:
```
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
        
        /*
            发送消息给 CellViewModel 
        */
        leftImageView.rx.tap().map { _ in viewModel.commit.committer }.filterNil()
            .bind(to: viewModel.userSelected).disposed(by: cellDisposeBag)
    }
}
```


#### ViewModel 之间存在相互依赖的关系 
记住最重要的 : ViewModel 是对 View 的建模 ,对 View 的接口进行编程 , 这样做是为了屏蔽 View 的具体实现.

基于上面说的 ,ViewMode 最重要的职责就是为了 屏蔽 对 View 的具体实现 , 这样我们就可以更换  View 的实现 而 不影响 ViewModel 

基于上面的目的 , 我们的 ViewModel 直接存在依赖并不会影响到 这个 目的 . 所以 ViewModel  之间存在依赖也没有什么问题 .

如果我们基于现实的考虑 , 觉得 ViewModel 之间也必须屏蔽具体的实现 ,那么 ViewModel 之间只能通过 protocol 进行联系.
但是目前的现实情况往往是 : 我们需要屏蔽 View 的实现 ,以达到以下目的 : 
- 可以在不同的端进行实现 ,比如 iOS , Macos 使用不同的 View 实现 . ViewModel 和 Model 可以直接复用
    - 这样在工作效率上 , UI 组 和 后端就可以 并行开发 , 而不是彼此纠缠在一起 .


```swift
        // 摘自 CommitsViewModel  
        let userDetails = userSelected.asDriver(onErrorJustReturn: User())
            .map({ (user) -> UserViewModel in // 这个写法挺好的 , 增强了 给 compiler 的 提示 ,让 compiler 轻松知道返回的类型
                /*
                    ViewModel 之间看样子不可避免的存在依赖了
                    在 ViewModelA 构造并返回 viewModelB 
                 */
                let viewModel = UserViewModel(user: user, provider: self.provider)
                return viewModel
            })
```


#### 函数调用
函数调用基本上就是 : 输入 -> 函数计算  -> caller 得到输出 
但是 基于 RxSwift , View 与 ViewModel 之间 几乎 不存在函数调用风格的代码 .
而是 : 通过 publisher 进行输入  , 然后在 另一个 publisher 接收到 output . 都是单向的信息流动 ,不会像函数一样 是一个双向信息流动的操作.

这样的好处是: 形成2条独立的单向路径 :
-  一条是 Views(多个 View) 修改 state 的路径 (通过 pub/sub ) 
-  一条是 Views 响应 state 的路径 (通过 pub/sub ) 

这样就可以达到 : 针对 state 进行编程 , 也就是 react 编程 .  state 一旦变动 , 那么 View 层就会自动对 state 进行 响应 ,调整 UI 的展示 . 在 SwiftHub 中 , state 就是 ViewModel 中的 output .

SwiftUI 基本就是这样的逻辑实现 , 但是比这个更加简单. 因为在 UIKit + RxSwift 中 ,我们需要维护 2 条 code path .  但在 SwiftUI 中 , 只需要维护一条 code path . 因为 SwiftUI 的 Views  会自动响应 state 的变动 .





ViewModel 和 ApiProvider 之间 ,会存在函数调用风格的代码 ,ViewModel 调用函数  得到一个  Single
```Swift
    // RestApi
    private func requestObject<T: BaseMappable>(_ target: GithubAPI, type: T.Type) -> Single<T> {
        return githubProvider.request(target)
            .mapObject(T.self)
            .observe(on: MainScheduler.instance)
            .asSingle() // 转为 single 
    }
    
    // SwiftHubAPI 
```

#### view 如何与 ViewModel 进行交互 ?
都是通过 pub/sub 的管道进行交互的  .
例子1 : 
```
//ContactsViewController.bindViewModel
        let input = ContactsViewModel.Input(cancelTrigger: closeBarButton.rx.tap.asDriver(), // 这里为什么要 asDriver ?
                                            cancelSearchTrigger: searchBar.rx.cancelButtonClicked.asDriver(),
                                            trigger: pullToRefresh,
                                            keywordTrigger: searchBar.rx.text.orEmpty.asDriver(),
                                            selection: tableView.rx.modelSelected(ContactCellViewModel.self).asDriver())
        let output = viewModel.transform(input: input)
```



#### viewController 的作用
将 view  和 viewmodel connect 起来  , 同时处理 viewModel 或者 view  传递出来的信息 . 
ViewController 不再担任的职责: 各个 View 之间的 navigation .


例子 :

``` 
        // ContactsViewController.bindViewModel
        
        // 处理 viewModel 发布的信息
        output.contactSelected.drive(onNext: { [weak self] (contact) in
            if let strongSelf = self {
                let phone = contact.phones.first ?? ""
                let vc = strongSelf.navigator.toInviteContact(withPhone: phone)
                vc.messageComposeDelegate = self
                if MFMessageComposeViewController.canSendText() {
                    strongSelf.present(vc, animated: true, completion: nil)
                }
            }
        }).disposed(by: rx.disposeBag)

        // 处理 view 发布的信息 , 根据发布的信息,决定 UI的变动  
        emptyDataSetButtonTap.subscribe(onNext: { () in
            let app = UIApplication.shared
            if let settingsUrl = UIApplication.openSettingsURLString.url, app.canOpenURL(settingsUrl) {
                app.open(settingsUrl, completionHandler: nil)
            }
        }).disposed(by: rx.disposeBag)
```



### CellViewModel . bind

```Swift
        let output = viewModel.transform(input: input)

        output.items
            .drive(tableView.rx.items(cellIdentifier: reuseIdentifier, cellType: ContactCell.self)) { tableView, viewModel, cell in
                cell.bind(to: viewModel)
            }.disposed(by: rx.disposeBag)
```



### CellViewModel 的 pub/sub 属性 如何与外界进行沟通 ?   
CellViewModel 基本都是由 ViewModel 创建的  ,
CellViewModel 的  pub/sub 属性 可以传递到 ViewModel , 也可以传递到 Cell 去驱动 Cell 的变化

```Swift
    //  CommitsViewModel 构建 CommitsCellViewModel , CommitsCellViewModel 的 userSelected 属性和 CommitsViewModel 进行沟通
    func request() -> Observable<[CommitCellViewModel]> {
        let fullname = repository.value.fullname ?? ""
        return provider.commits(fullname: fullname, page: page)
            .trackActivity(loading)
            .trackError(error)
            .map { $0.map({ (commit) -> CommitCellViewModel in
                let viewModel = CommitCellViewModel(with: commit)
                /*
                    创建 CellViewModel , 处理与 CellViewModel 的通信 
                    
                */
                viewModel.userSelected.bind(to: self.userSelected).disposed(by: self.rx.disposeBag)
                return viewModel
            })}
    }
```



### CellViewModel 为什么可以存放非 pub/sub 的属性 ?
```Swift
class BranchCellViewModel: DefaultTableViewCellViewModel {

    let branch: Branch // 直接存储 非 pub/sub 的属性 , 我觉得应该是因为这些是 常量 ,不会被修改 , 所以

    init(with branch: Branch) {
        self.branch = branch
        super.init()
        title.accept(branch.name)
        image.accept(R.image.icon_cell_git_branch()?.template)
    }
}
```

### ViewModel 与 CellViewModel 的分工
ViewModel 负责和 Model 等业务逻辑进行沟通 , CellViewModel 不和 Model 有直接沟通. 也就是 ViewModel 会统一连接 业务逻辑 ,而 CellViewModel 仅仅负责 UI 相关的 建模 . 

ViewModel 负责构建 CellViewModel .  

CellViewModel 只能够和 View 和 ViewModel 进行沟通 


例子:  
```

```
