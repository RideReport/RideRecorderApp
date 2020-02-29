//
//  NYCBikeManager.swift
//  Ride Report
//
//  Created by Brad Leege on 2/21/19.
//  Copyright © 2019 Knock Softwae, Inc. All rights reserved.
//

import CocoaLumberjack
import Foundation
import Alamofire

class NYCBikeManager {
    
    func getNYCBikeStations(completion: @escaping ([NYCBikeStation]?, Error?) -> Void) {

        Alamofire.request("https://gbfs.citibikenyc.com/gbfs/en/station_information.json").validate().responseData { dataResponse in
            
            switch dataResponse.result {
            case .success:
                let decoder = JSONDecoder()
                guard let data = dataResponse.data else {
                    completion(nil, DataError())
                    return
                }
                let stationsInfo = try? decoder.decode(NYCStationInformation.self, from: data)
                completion(stationsInfo?.data["stations"], nil)
            case .failure(let error):
                DDLogError("Error Loading NYC Bike Stations: \(error)")
                completion(nil, error)
            }
        }
    }
    
    func getNYCBikeStationStatus(for stationId: String, completion: @escaping (NYCStationStatus?, Error?) -> Void) {

        Alamofire.request("https://gbfs.citibikenyc.com/gbfs/en/station_status.json").validate().responseData { dataResponse in
            
            switch dataResponse.result {
            case .success:
                let decoder = JSONDecoder()
                guard let data = dataResponse.data else {
                    completion(nil, DataError())
                    return
                }
                let stationsInfo = try? decoder.decode(NYCStationStatuses.self, from: data)
                if let stations = stationsInfo?.data["stations"] {
                    let station = stations.filter({ $0.station_id == stationId })
                    completion(station[0], nil)
                } else {
                    completion(nil, DataError())
                }
            case .failure(let error):
                DDLogError("Error Loading NYC Bike Station Statuses: \(error)")
                completion(nil, error)
            }
        }
    }
    
}

struct DataError: Error {
    
}
