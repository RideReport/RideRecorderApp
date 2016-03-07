//
//  RandomForestManager.h
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#include <Accelerate/Accelerate.h>
#ifdef __cplusplus
extern "C" {
#endif
    typedef struct RandomForestManager RandomForestManager;
RandomForestManager *createRandomForestManager(int sampleSize, char* pathToModelFile);
void deleteRandomForestManager(RandomForestManager *r);
int randomForesetClassifyMagnitudeVector(struct RandomForestManager *randomForestManager, float *magnitudeVector);
#ifdef __cplusplus
}
#endif