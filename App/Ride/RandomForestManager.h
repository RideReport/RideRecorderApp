//
//  RandomForestManager.h
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#define RANDOM_FOREST_VECTOR_SIZE (7)
#ifdef __cplusplus
extern "C" {
#endif
    typedef struct RandomForestManager RandomForestManager;
    RandomForestManager *createRandomForestManager(int sampleSize, const char* pathToModelFile);
    void deleteRandomForestManager(RandomForestManager *r);
    void prepFeatureVector(RandomForestManager *randomForestManager, float *features, float *magnitudes, float *speedVector, int speedVectorCount);
    int randomForesetClassifyMagnitudeVector(RandomForestManager *randomForestManager, float *magnitudeVector, float *speedVector, int speedVectorCount);
#ifdef __cplusplus
}
#endif