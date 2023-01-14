//
//  ExploreNestScrollView.swift
//
//  Created by daixijia on 2022/11/23.
//

import Foundation
import SnapKit
import UIKit

class ExploreTableView: UITableView, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer.isKind(of: UIPanGestureRecognizer.self) && otherGestureRecognizer.isKind(of: UIPanGestureRecognizer.self)
    }
}

protocol ExploreNestScrollViewDelegate: AnyObject {
    // 子视图滑动回调
    var listViewDidScroll: ((_ scrollView: UIScrollView) -> Void)? { get set }
    // 子视图，可以为滑动视图
    func listContainerViewInNestView() -> UIView
    // 子视图中的当前滑动视图
    func currentScrollListView() -> UIScrollView
    // 需要添加到 nestScrollView 的头部，一般为已知高度的部分，支持动态计算，但是需要先约束确定的宽度
    func tableViewHeaderInNestView() -> UIView
    // nestScrollView 滑动的顶部偏移，一般用作悬浮 section，悬浮 section 在子视图内部实现，可以为 navigationBar 等
    func headerSectionHeightInNestView() -> CGFloat
}

class ExploreNestScrollView: UIView {
    
    // 当前主滑动视图的滑动回调
    var mainScrollViewDidScroll: ((_ scrollView: UIScrollView) -> Void)?

    private weak var delegate: ExploreNestScrollViewDelegate?
    private weak var currentScrollingListView: UIScrollView?
    lazy var mainTableView: ExploreTableView = {
        let tableView = ExploreTableView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.scrollsToTop = false
        tableView.register(withClass: TableViewCell.self)
        tableView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = .clear
        return tableView
    }()
    
    init(with delegate: ExploreNestScrollViewDelegate?) {
        super.init(frame: .zero)
        self.delegate = delegate
        self.delegate?.listViewDidScroll = { [weak self] scrollView in
            guard let self = self else { return }
            self.listViewDidScroll(scrollView)
        }
        makeUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refreshTableHeaderView() {
        guard let delegate = delegate else { return }
        let tableHeaderView = delegate.tableViewHeaderInNestView()
        if tableHeaderView.superview != mainTableView {
            tableHeaderView.removeFromSuperview()
        }
        mainTableView.tableHeaderView = tableHeaderView
        tableHeaderView.snp.remakeConstraints { make in
            make.left.right.top.equalToSuperview()
        }
        mainTableView.setNeedsLayout()
        mainTableView.layoutIfNeeded()
    }
    
    func reloadData() {
        refreshTableHeaderView()
        mainTableView.reloadData()
    }
}

private extension ExploreNestScrollView {
    
    func makeUI() {
        addSubview(mainTableView)
        mainTableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        refreshTableHeaderView()
    }
    
    func setMainTableViewToMaxContentOffsetY() {
        mainTableView.contentOffset = .init(x: 0.0, y: mainTableViewMaxContentOffsetY())
    }
    
    func mainTableViewMaxContentOffsetY() -> CGFloat {
        guard let delegate = delegate else { return 0.0 }
        let headerHeight = mainTableView.tableHeaderView?.bounds.height ?? 0.0
        let headerSectionHeight = delegate.headerSectionHeightInNestView()
        var result = headerHeight - headerSectionHeight
        let scale = UIScreen.main.scale
        result = floor((result * scale) / scale)
        return result
    }
    
    func minContentOffsetYInListScrollView(_ scrollView: UIScrollView) -> CGFloat {
        return -(scrollView.adjustedContentInset.top)
    }
    
    func setListScrollViewToMinContentOffsetY(_ scrollView: UIScrollView) {
        scrollView.contentOffset = .init(x: scrollView.contentOffset.x, y: minContentOffsetYInListScrollView(scrollView))
    }
    
    func listViewDidScroll(_ scrollView: UIScrollView) {
        currentScrollingListView = scrollView
        if mainTableView.contentOffset.y < mainTableViewMaxContentOffsetY() {
            setListScrollViewToMinContentOffsetY(scrollView)
        }
        else {
            mainTableView.contentOffset = .init(x: 0.0, y: mainTableViewMaxContentOffsetY())
        }
    }
    
    func tableViewDidScroll(_ scrollView: UIScrollView) {
        if let listView = currentScrollingListView,
           listView.contentOffset.y > minContentOffsetYInListScrollView(listView) {
            setMainTableViewToMaxContentOffsetY()
        }
        if scrollView.contentOffset.y < mainTableViewMaxContentOffsetY() {
            if let scrollView = delegate?.currentScrollListView() {
                setListScrollViewToMinContentOffsetY(scrollView)
            }
        }
        if let listView = currentScrollingListView, scrollView.contentOffset.y > mainTableViewMaxContentOffsetY(), listView.contentOffset.y == minContentOffsetYInListScrollView(listView) {
            setMainTableViewToMaxContentOffsetY()
        }
        mainScrollViewDidScroll?(scrollView)
    }
}

extension ExploreNestScrollView: UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let headerSectionHeight = delegate?.headerSectionHeightInNestView() ?? 0.0
        return max(tableView.bounds.height - headerSectionHeight, 0.0)
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withClass: TableViewCell.self, for: indexPath)
        cell.contentView.backgroundColor = UIColor.color17
        if let listContainerView = delegate?.listContainerViewInNestView() {
            if listContainerView.superview != cell {
                cell.contentView.addSubview(listContainerView)
            }
            listContainerView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == mainTableView {
            tableViewDidScroll(scrollView)
        }
    }
}
