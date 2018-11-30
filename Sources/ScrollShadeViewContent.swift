import UIKit

/// It is compatible with
/// - UIScrollView with UIScrollViewDelegate
/// - UITableView with UITableViewDelegate
/// - UICollectionView with UICollectionViewDelegate and UICollectionViewDelegateFlowLayout
/// Do not use scrollView.delegate. It would be overwritten.
open class ScrollShadeViewContent: NSObject {
    
    public let scrollView: UIScrollView
    
    public weak var delegate: UIScrollViewDelegate?
    
    public init(scrollView: UIScrollView, delegate: UIScrollViewDelegate) {
        self.scrollView = scrollView
        self.delegate = delegate
        self.forwardingSelectors = ScrollShadeViewContent.forwardingSelectors(for: delegate)
        
        super.init()
        
        scrollView.delegate = self
        
        scrollViewObservations = [
            scrollView.observe(\.contentSize, options: .new) { [weak self] _, value in
                guard let slf = self, let newValue = value.newValue else { return }
                self?.notifier.forEach { $0.shadeViewContent(slf, didChangeContentSize: newValue) }
            },
            scrollView.observe(\.contentInset, options: .new) { [weak self] _, value in
                guard let slf = self, let newValue = value.newValue else { return }
                self?.notifier.forEach { $0.shadeViewContent(slf, didChangeContentInset: newValue) }
            }
        ]
    }
    
    deinit {
        // https://bugs.swift.org/browse/SR-5816
        scrollViewObservations = []
    }
    
    // MARK: - NSObject
    
    open override func responds(to aSelector: Selector) -> Bool {
        if super.responds(to: aSelector) {
            return true
        }
        
        if let delegate = delegate, forwardingSelectors.contains(aSelector) {
            return delegate.responds(to: aSelector)
        }
        
        return false
    }
    
    open override func forwardingTarget(for aSelector: Selector) -> Any? {
        if super.responds(to: aSelector) {
            return self
        }
    
        if let delegate = delegate, forwardingSelectors.contains(aSelector) {
            return delegate
        }
        
        return nil
    }
    
    // MARK: - Private
    
    private let notifier = Notifier<ShadeViewContentListener>()
    
    private let forwardingSelectors: Set<Selector>
    
    private var scrollViewObservations: [NSKeyValueObservation] = []
    
    private static func forwardingSelectors(for delegate: UIScrollViewDelegate) -> Set<Selector> {
        var result = (UIScrollViewDelegate.self as Protocol).getInstanceMethods()
        
        if delegate is UITableViewDelegate {
            result.formUnion((UITableViewDelegate.self as Protocol).getInstanceMethods())
        }
        
        if delegate is UICollectionViewDelegate {
            result.formUnion((UICollectionViewDelegate.self as Protocol).getInstanceMethods())
        }
        
        if delegate is UICollectionViewDelegateFlowLayout {
            result.formUnion((UICollectionViewDelegateFlowLayout.self as Protocol).getInstanceMethods())
        }
        
        return result
    }
    
}

extension ScrollShadeViewContent: ShadeViewContent {

    public var view: UIView {
        return scrollView
    }
    
    public var contentOffset: CGPoint {
        get {
            return scrollView.contentOffset
        }
        set {
            scrollView.contentOffset = newValue
        }
    }
    
    public var contentSize: CGSize {
        return scrollView.contentSize
    }
    
    public var contentInset: UIEdgeInsets {
        return scrollView.contentInset
    }
    
    public func addListener(_ listener: ShadeViewContentListener) {
        notifier.subscribe(listener)
    }
    
    public func removeListener(_ listener: ShadeViewContentListener) {
        notifier.unsubscribe(listener)
    }
    
}

extension ScrollShadeViewContent: UIScrollViewDelegate {

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        notifier.forEach { $0.shadeViewContentDidScroll(self) }
        delegate?.scrollViewDidScroll?(scrollView)
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        notifier.forEach { $0.shadeViewContentWillBeginDragging(self) }
        delegate?.scrollViewWillBeginDragging?(scrollView)
    }
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>)
    {
        notifier.forEach {
            $0.shadeViewContentWillEndDragging(self, withVelocity: velocity, targetContentOffset: targetContentOffset)
        }
        delegate?.scrollViewWillEndDragging?(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
    }

}
