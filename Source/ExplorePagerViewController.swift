//
//  ExplorePagerViewController.swift
//
//  Created by daixijia on 2023/1/14.
//

import Foundation
import SnapKit
import RxSwift
import RxRelay

struct ExplorePagerButtonConfig {
    var titleColor: UIColor = UIColor.init(white: 1.0, alpha: 0.3)
    var selectTitleColor: UIColor = UIColor.init(white: 1.0, alpha: 0.9)
    var titleFont: UIFont = .systemFont(ofSize: 16.0)
}

internal class ExplorePagerView: UIView {
    var selectedIndex: Int = 0
    var changeCurrentIndexProgressive: ((_ oldIndex: Int, _ newIndex: Int, _ button: UIButton) -> Void)?
    var buttonConfig = ExplorePagerButtonConfig()
    
    var maxDisplayWidth = ScreenWidth
    
    private let disposeBag = DisposeBag()
    private var tabItem = [String]()
    
    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        return view
    }()
    lazy var containerView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        stackView.spacing = 0.0
        return stackView
    }()
    private lazy var bottomView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    private var redDots = [UILabel]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        scrollView.addSubview(containerView)
        scrollView.addSubview(bottomView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(titles: [String], tabWidth: CGFloat, tabHeight: CGFloat) {
        tabItem.removeAll()
        redDots.removeAll()
        for view in containerView.arrangedSubviews {
            view.removeFromSuperview()
        }
        var tabWidth = tabWidth
        var contentWidth = tabWidth * CGFloat(titles.count)
        if contentWidth < maxDisplayWidth {
            contentWidth = maxDisplayWidth
            tabWidth = maxDisplayWidth / CGFloat(titles.count)
        }
        containerView.snp.remakeConstraints { make in
            make.top.bottom.equalTo(self)
            make.width.equalTo(contentWidth)
            make.edges.equalToSuperview()
        }
        for title in titles.reversed() {
            let dot = makeRedDot()
            redDots.insert(dot, at: 0)
            let button = makeButton(title: title, dot: dot, size: CGSizeMake(tabWidth, tabHeight))
            containerView.insertArrangedSubview(button, at: 0)
        }
        guard let firstButton = containerView.arrangedSubviews.first as? UIButton else {
            return
        }
        firstButton.isSelected = true
        bottomView.snp.remakeConstraints { make in
            make.centerX.equalTo(firstButton)
            make.width.equalTo(20.0).priority(.high)
            make.width.lessThanOrEqualTo(firstButton)
            make.bottom.equalToSuperview()
            make.height.equalTo(3.0)
        }
    }
    
    func updateTitle(_ title: String, index: Int) {
        guard let button = containerView.arrangedSubviews[index] as? UIButton else { return }
        button.setTitle(title, for: .normal)
    }
    
    func updateImage(_ image: UIImage, index: Int) {
        guard let button = containerView.arrangedSubviews[index] as? UIButton else { return }
        button.setImage(image, for: .selected)
    }
    
    func updateRedDot(withCount count: Int, index: Int) {
        let label = redDots[index]
        label.isHidden = count <= 0
        label.text = count > 99 ? "···" : String(count)
    }
    
    func changeSelected(button: UIButton) {
        let index = containerView.arrangedSubviews.firstIndex(of: button)
        guard let index = index, index != selectedIndex else {
            changeCurrentIndexProgressive?(selectedIndex, selectedIndex, button)
            return
        }
        // 当按钮的位置超过了中点，尽可能滑动到中点
        if button.frame.origin.x > maxDisplayWidth / 2.0 {
            let offsetX = button.frame.origin.x + button.frame.size.width / 2.0 - maxDisplayWidth / 2.0
            let maxOffsetX = scrollView.contentSize.width - maxDisplayWidth
            scrollView.setContentOffset(CGPoint(x: min(offsetX, maxOffsetX), y: 0), animated: true)
        }
        // 当按钮的位置少于中点，尽可能滑动到中点
        else if button.frame.origin.x + button.frame.size.width < maxDisplayWidth / 2.0 {
            let offsetX = button.frame.origin.x + button.frame.size.width / 2.0 - maxDisplayWidth / 2.0
            scrollView.setContentOffset(CGPoint(x: max(offsetX, 0), y: 0), animated: true)
        }
        let prevButton = containerView.arrangedSubviews[selectedIndex] as? UIButton
        prevButton?.isSelected = false
        button.isSelected = true
        let oldIndex = selectedIndex
        selectedIndex = index
        changeCurrentIndexProgressive?(oldIndex, index, button)
        bottomView.snp.remakeConstraints { make in
            make.centerX.equalTo(button)
            make.width.equalTo(20.0).priority(.high)
            make.width.lessThanOrEqualTo(button)
            make.bottom.equalToSuperview()
            make.height.equalTo(3.0)
        }
    }
    
    func makeButton(title: String, dot: UILabel, size: CGSize) -> UIButton {
        let button = ImageRightButton()
        button.midSpace = 10.0
        button.intrinsicContentSize = size
        button.setImage(nil, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = buttonConfig.titleFont
        button.setTitleColor(buttonConfig.titleColor, for: .normal)
        button.setTitleColor(buttonConfig.selectTitleColor, for: .selected)
        button.titleLabel?.textAlignment = .center
        button.contentHorizontalAlignment = .center
        button.addSubview(dot)
        dot.snp.remakeConstraints { make in
            make.top.equalTo(button).offset(1.0)
            if let label = button.titleLabel {
                make.left.equalTo(label.snp.right)
            }
            make.height.width.equalTo(14.0)
        }
        button.rx.tap.subscribe(onNext: { [weak self, button] _ in
            guard let self = self else { return }
            self.changeSelected(button: button)
        }).disposed(by: disposeBag)
        return button
    }
    
    func makeRedDot() -> UILabel {
        let label = UILabel()
        label.isHidden = true
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 7.0
        label.backgroundColor = UIColor.red
        label.textColor = .white
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.font = .systemFont(ofSize: 10.0)
        return label
    }
}

// MARK: -

struct ExploreSubPageInfo {
    var title: String?
    var image: UIImage?
}

protocol ExploreSubPageInfoProvider {
    func subPageInfo() -> ExploreSubPageInfo
}

typealias ExplorePagerSubViewController = UIViewController & ExploreSubPageInfoProvider

internal class ExplorePagerViewController: UIViewController {
    var willShowViewController: UIViewController?
    var changeCurrentIndexProgressive: ((_ oldIndex: Int, _ newIndex: Int, _ button: UIButton) -> Void)?

    var tabHeight: CGFloat { return 44.0 }
    
    var viewControllers = [UIViewController]()
    var tabView = ExplorePagerView()
    let containerCellReuseIdentifier = "containerCellReuseIdentifier"
    
    var currentIndex: Int { return tabView.selectedIndex }
    
    func setup(viewControllers: [ExplorePagerSubViewController], tabWidth: CGFloat) {
        self.viewControllers = viewControllers
        let titles = viewControllers.map { vc in
            return vc.subPageInfo().title ?? ""
        }        
        tabView.setup(titles: titles, tabWidth: tabWidth, tabHeight: tabHeight)
        for (index, item) in viewControllers.enumerated() {
            if let image = item.subPageInfo().image {
                tabView.updateImage(image, index: index)
            }
        }
        collectionView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tabView)
        tabView.snp.makeConstraints { make in
            make.left.top.right.equalToSuperview()
            make.height.equalTo(tabHeight)
        }
        tabView.changeCurrentIndexProgressive = { [weak self] oldIndex, newIndex, button in
            guard let self = self else { return }
            if oldIndex != newIndex {
                self.switchTab(index: newIndex)
            }
            self.changeCurrentIndexProgressive?(oldIndex, newIndex, button)
        }
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(tabView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
    }
    
    func updateScrollEnable(_ scrollEnable: Bool) {
        collectionView.isScrollEnabled = scrollEnable
    }
    
    func switchTab(index: Int) {
        guard index < viewControllers.count else {
            return
        }
        let indexPath = IndexPath(row: index, section: 0)
        willShowViewController = viewControllers[index]
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
    func switchTab(controller: UIViewController?) {
        guard let controller = controller else { return }
        guard let index = viewControllers.firstIndex(of: controller) else { return }
        if let button = tabView.containerView.arrangedSubviews[index] as? UIButton {
            tabView.changeSelected(button: button)
        }
    }
    
    func updateTab(_ title: String?, viewController: UIViewController) {
        let index = viewControllers.firstIndex(of: viewController)
        if let index = index, let title = title {
            tabView.updateTitle(title, index: index)
        }
    }
    
    func updateRedDot(withCount count: Int, viewController: UIViewController) {
        let index = viewControllers.firstIndex(of: viewController)
        if let index = index {
            tabView.updateRedDot(withCount: index == tabView.selectedIndex ? 0 : count, index: index)
        }
    }
    
    func replace(viewController: UIViewController?, originViewController: UIViewController) {
        let index = viewControllers.firstIndex(of: originViewController)
        guard let index = index else { return }
        if let viewController = viewController {
            viewControllers[index] = viewController
        }
        else {
            viewControllers.remove(at: index)
        }
    }
    
    func replace(viewController: UIViewController?, atIndex: Int) {
        if atIndex >= viewControllers.count || atIndex < 0 { return }
        if let viewController = viewController {
            viewControllers[atIndex] = viewController
        }
        else {
            viewControllers.remove(at: atIndex)
        }
        collectionView.reloadData()
    }

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0.0
        layout.minimumInteritemSpacing = 0.0
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.bounces = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: containerCellReuseIdentifier)
        collectionView.isPagingEnabled = true
        collectionView.delegate = self
        collectionView.dataSource = self
        return collectionView
    }()
}

// MARK: -

extension ExplorePagerViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewControllers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: containerCellReuseIdentifier, for: indexPath)
        let viewController = viewControllers[indexPath.row]
        if viewController.view.superview != cell.contentView {
            removeController(viewController)
            addController(viewController, cell.contentView)
            viewController.view.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        return cell
    }
    
    func removeController(_ viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
    
    func addController(_ viewController: UIViewController, _ superView: UIView) {
        addChild(viewController)
        superView.addSubview(viewController.view)
        viewController.didMove(toParent: self)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let viewController = viewControllers[indexPath.row]
        if viewController.view.superview != cell.contentView {
            removeController(viewController)
            addController(viewController, cell.contentView)
            viewController.view.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let viewController = viewControllers[indexPath.row]
        removeController(viewController)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating {
            scrollViewDidEndScroll()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating {
            scrollViewDidEndScroll()
        }
    }
    
    func scrollViewDidEndScroll() {
        guard let indexPath = collectionView.indexPathForItem(at: collectionView.contentOffset) else { return }
        let contoller = viewControllers[indexPath.row]
        switchTab(controller: contoller)
    }
}
