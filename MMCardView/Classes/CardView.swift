//
//  CardView.swift
//  Pods
//
//  Created by MILLMAN on 2016/9/20.
//
//

import UIKit

public protocol CardCollectionViewDataSource:class {
    func cardView(collectionView:UICollectionView,item:AnyObject,indexPath:IndexPath) -> UICollectionViewCell
}

public class CardView: UIView {
    public weak var cardDataSource:CardCollectionViewDataSource?
    
    fileprivate var isFilterMode = false

    fileprivate var filterSet = [Int]()
    fileprivate var filterArr = [AnyObject]()
    fileprivate var cardArr = [AnyObject]() {
        didSet {
            self.collectionView.reloadData()
            if cardArr.count > 0 {
                filterSet = Array(0...cardArr.count-1)
            }
            filterArr.removeAll()
            filterArr += cardArr
        }
    }
    fileprivate var transition = CustomFlipTransition(duration: 0.3)
    fileprivate lazy var collectionView:UICollectionView = {
        let layout = CustomCardLayout()
        let c = UICollectionView.init(frame: self.frame, collectionViewLayout: layout)
        c.translatesAutoresizingMaskIntoConstraints = false
        c.delegate = self
        c.dataSource = self
        c.backgroundColor = UIColor.clear
        return c
    }()
    
    fileprivate func setUp() {
        self.addSubview(collectionView)
        self.translatesAutoresizingMaskIntoConstraints = false
        let left = NSLayoutConstraint.init(item: collectionView, attribute: .left, relatedBy: .equal, toItem: collectionView.superview!, attribute: .left, multiplier: 1.0, constant: 0.0)
        let right = NSLayoutConstraint.init(item: collectionView, attribute: .right, relatedBy: .equal, toItem: collectionView.superview!, attribute: .right, multiplier: 1.0, constant: 0.0)
        let top = NSLayoutConstraint.init(item: collectionView, attribute: .top, relatedBy: .equal, toItem: collectionView.superview!, attribute: .top, multiplier: 1.0, constant: 0.0)
        let bottom = NSLayoutConstraint.init(item: collectionView, attribute: .bottom, relatedBy: .equal, toItem: collectionView.superview!, attribute: .bottom, multiplier: 1.0, constant: 0.0)
        self.addConstraints([left,right,top,bottom])
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setUp()
    }

    public func set(cards:[AnyObject]) {
        cardArr.removeAll()
        cardArr += cards
    }
    
    public func filterAllDataWith(isInclued:@escaping (Int,AnyObject) -> Bool) {
        
        DispatchQueue.main.async {
         
            var removeIdx = [Int]()
            var insertIdx = [Int]()
            for (idx,value) in self.cardArr.enumerated() {
                let rc = isInclued(idx,value)
                
                if !rc && self.filterSet.contains(idx) {
                    let i = self.filterSet.index(of: idx)!
                    removeIdx.append(i)
                } else if rc && !self.filterSet.contains(idx){
                    insertIdx.append(idx)
                }
            }
            self.filterArr = self.filterArr.enumerated().filter { !removeIdx.contains($0.offset)}.map {$0.element}
            self.filterSet = self.filterSet.enumerated().filter { !removeIdx.contains($0.offset)}.map {$0.element}
            let removePaths = removeIdx.map { IndexPath.init(row: $0, section: 0) }
            self.collectionView.performBatchUpdates({
                self.collectionView.deleteItems(at: removePaths)
            }) { (finish) in
                var add = self.filterSet + insertIdx
                var insertPath = [IndexPath]()
                if insertIdx.count > 0 {
                    insertPath += Array(self.filterSet.count...add.count-1).map {IndexPath.init(row: $0, section: 0)}
                }
                self.filterArr = add.map {self.cardArr[$0]}
                self.filterSet = add
                
                
                self.collectionView.performBatchUpdates({
                    self.collectionView.insertItems(at: insertPath)
                    }, completion: { (finish) in
                        if insertIdx.count == 0 {
                            return
                        }
                        add = add.enumerated().sorted(by: {$0.0.element < $0.1.element}).map {$0.element}
                        let value:[(IndexPath,IndexPath)] = self.filterSet.enumerated().map {
                            let from = IndexPath.init(row: $0.offset, section: 0)
                            let to = IndexPath.init(row: add.index(of: $0.element)!, section: 0)
                            return (from , to)
                        }
                        self.filterSet = add
                        self.filterArr = add.map {self.cardArr[$0]}
                        
                        self.collectionView.performBatchUpdates({
                            for (from,to) in value {
                                self.collectionView.moveItem(at: from, to: to)
                                print ("To :\(to)")
                            }

                            }, completion: { (finish) in
                         
                                if finish {
                                    self.collectionView.reloadData()
                                }
                        })
                })
            }
        }
    }
    
    public func showAllData() {
        self.filterAllDataWith { _,_ in true}
    }
    
    public func showStyle(style:SequenceStyle) {
        DispatchQueue.main.async { 
            if let custom = self.collectionView.collectionViewLayout as? CustomCardLayout {
                custom.showStyle = style
            }            
        }
    }
    
    public func presentViewController(to vc:UIViewController) {
        if let custom = collectionView.collectionViewLayout as? CustomCardLayout ,custom.selectIdx == -1{
            print ("You nees Select a cell")
            return
        }

        let current = UIViewController.currentViewController()
        vc.transitioningDelegate = self
        vc.modalPresentationStyle = .custom
        current.present(vc, animated: true, completion: nil)
    }

    public func registerCardCell(c:AnyClass,nib:UINib) {
        if (c.alloc().isKind(of: CardCell.classForCoder())) {
            let identifier = c.value(forKey: "cellIdentifier") as! String
            collectionView.register(nib, forCellWithReuseIdentifier: identifier)
        } else {
            NSException(name: NSExceptionName(rawValue: "Cell type error!!"), reason: "Need to inherit CardCell", userInfo: nil).raise()
        }
    }
    
    public func expandBottomCount(count:Int) {
        if let layout = self.collectionView.collectionViewLayout as? CustomCardLayout {
            layout.bottomShowCount = count
        }
    }

}

extension CardView:UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let custom = collectionView.collectionViewLayout as? CustomCardLayout {
            custom.selectIdx = indexPath.row
        }
    }
}

extension CardView:UICollectionViewDataSource {
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filterArr.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print (indexPath.row)
        guard let source = cardDataSource?.cardView(collectionView: collectionView,item: filterArr[indexPath.row], indexPath: indexPath) as? CardCell else {
            return UICollectionViewCell()
        }
//        source.transform = .identity
        source.collectionV = collectionView
        source.reloadBlock = {
            if let custom = collectionView.collectionViewLayout as? CustomCardLayout {
                custom.selectIdx = indexPath.row
            }
        }
        source.isHidden = false
        return source
    }
}

extension CardView:UIViewControllerTransitioningDelegate{

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.transitionMode = .Present
        if let custom = collectionView.collectionViewLayout as? CustomCardLayout {
            transition.cardView = self.collectionView.cellForItem(at: IndexPath.init(row: custom.selectIdx, section: 0))
            custom.isFullScreen = true
        }
        return transition
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.transitionMode = .Dismiss
        if let custom = collectionView.collectionViewLayout as? CustomCardLayout {
            custom.isFullScreen = false
        }
        return transition
    }
}
