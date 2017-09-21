//
//  RandomForestManager.h
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#define RANDOM_FOREST_VECTOR_SIZE (14*3)
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif
    typedef struct RandomForestManager RandomForestManager;

    struct AccelerometerReadingStruct {
        float x;
        float y;
        float z;
        double t; // seconds
    };
    typedef struct AccelerometerReadingStruct AccelerometerReadingStruct;

    RandomForestManager *createRandomForestManagerFromJsonString(const char* jsonString);
    RandomForestManager *createRandomForestManagerFromFile(const char* pathToJson);
    bool randomForestLoadModel(RandomForestManager *r, const char* pathToModelFile);

    float randomForestGetDesiredSessionDuration(RandomForestManager *r);
    float randomForestGetDesiredSamplingInterval(RandomForestManager *r);
    const char* randomForestGetModelUniqueIdentifier(RandomForestManager *r);

    bool randomForestManagerCanPredict(RandomForestManager *r);
    void deleteRandomForestManager(RandomForestManager *r);
    void randomForestClassifyFeatures(RandomForestManager *randomForestManager, float* features, float* confidences, int n_classes);
    bool randomForestClassifyAccelerometerSignal(RandomForestManager *randomForestManager, AccelerometerReadingStruct* signal, int readingCount, float* confidences, int n_classes);
    bool randomForestPrepareFeaturesFromAccelerometerSignal(RandomForestManager *randomForestManager, AccelerometerReadingStruct* readings, int readingCount, float* features, int feature_count, float offsetSeconds);
    int randomForestGetClassCount(RandomForestManager *randomForestManager);
    int randomForestGetClassLabels(RandomForestManager *randomForestManager, int *labels, int classCount);
#ifdef __cplusplus
}
#endif
