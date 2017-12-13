//
//  TrophyCategoryViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/18/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

class TrophyCategoryViewController: UICollectionViewController {
    public var trophyCategory: TrophyCategory? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = trophyCategory?.name ?? "Trophies"
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let trophyCategory = trophyCategory else {
            return 0
        }
        
        return trophyCategory.trophyProgresses.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseID = "trophyContainerView"
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath)
        
        guard let trophyCategory = trophyCategory else {
            return cell
        }
        
        guard let trophyProgressButton = cell.viewWithTag(1) as? TrophyProgressButton,
            let trophyDescript = cell.viewWithTag(2) as? UILabel,
            indexPath.row < trophyCategory.trophyProgresses.count else {
                return cell
        }
        
        let trophyProgress = trophyCategory.trophyProgresses[indexPath.row]
        
        trophyProgressButton.trophyProgress = trophyProgress
    
        trophyDescript.text = trophyProgress.body
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let trophyCategory = trophyCategory else {
            return
        }
        
        guard indexPath.row < trophyCategory.trophyProgresses.count else {
            return
        }
        
        let trophyProgress = trophyCategory.trophyProgresses[indexPath.row]

        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        guard let trophyVC = storyBoard.instantiateViewController(withIdentifier: "trophyViewController") as? TrophyViewController else {
            return
        }
        
        trophyVC.trophyProgress = trophyProgress
        
        customPresentViewController(TrophyViewController.presenter(), viewController: trophyVC, animated: true, completion: nil)
    }
}
