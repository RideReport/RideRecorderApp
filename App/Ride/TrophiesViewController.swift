//
//  TrophiesViewController.swift
//  Ride Report
//
//  Created by William Henderson on 10/18/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import Foundation
import SwiftyJSON

class TrophiesViewController: UICollectionViewController {
    public var trophyProgresses: [JSON] = []
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return trophyProgresses.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseID = "trophyContainerView"
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath)
        
        guard let trophyProgressButton = cell.viewWithTag(1) as? TrophyProgressButton,
            let trophyDescript = cell.viewWithTag(2) as? UILabel,
            indexPath.row < trophyProgresses.count else {
                return cell
        }
        
        let trophyProgress = trophyProgresses[indexPath.row]
        
        guard let emoji = trophyProgress["emoji"].string,
            let body = trophyProgress["description"].string,
            let count = trophyProgress["count"].int else {
                return cell
        }
        
        trophyProgressButton.emoji = emoji
        trophyProgressButton.body = body
        trophyProgressButton.count = count
        
        if let progress = trophyProgress["progress"].double {
            trophyProgressButton.progress = progress
        } else {
            trophyProgressButton.progress = 1.0
        }
        
        trophyDescript.text = body
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.row < trophyProgresses.count else {
                return
        }
        
        let trophyProgress = trophyProgresses[indexPath.row]

        guard let emoji = trophyProgress["emoji"].string,
            let body = trophyProgress["description"].string,
            let count = trophyProgress["count"].int else {
                return
        }
        
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        guard let trophyVC = storyBoard.instantiateViewController(withIdentifier: "trophyViewController") as? TrophyViewController else {
            return
        }
        
        trophyVC.emoji = emoji
        trophyVC.body = body
        trophyVC.count = count
        
        if let progress = trophyProgress["progress"].double {
            trophyVC.progress = progress
        } else {
            trophyVC.progress = 1.0
        }
        
        customPresentViewController(TrophyViewController.presenter(), viewController: trophyVC, animated: true, completion: nil)
    }
}
