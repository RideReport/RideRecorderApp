//
//  RandomForestManager.cpp
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#include "RandomForestManager.h"
#import "NSObject+HBAdditions.h"
#import <CoreMotion/CoreMotion.h>
#import <UIKit/UIKit.h>
#include <opencv2/opencv.hpp>
#include <opencv2/ml.hpp>

#import <CocoaLumberjack/CocoaLumberjack.h>
#if DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

using namespace cv;
using namespace std;

static RandomForestManager *instance = nil;
static const NSTimeInterval updateInterval = 0.005;
static const NSUInteger windowSize = 40;

@interface RandomForestManager ()

@property (nonatomic, retain) CMMotionManager *motionManager;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundScanTaskID;
@property (nonatomic, retain) NSOperationQueue *motionQueue;
@property (nonatomic, copy) void(^foundFeatureBlock)();
@property (nonatomic, assign) BOOL isTraining;
@property (nonatomic, assign) BOOL isPredicting;

@end

@implementation RandomForestManager

int currentTrainingIndex = 0;
int currentPredictionIndex = 0;
int classCount = 1;
cv::Mat trainingReadings;
cv::Mat predictionReadings;
cv::Mat trainingLabels;
Ptr<cv::ml::RTrees> model;

+(RandomForestManager *)sharedInstance;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

- (id)init;
{
    if (!(self = [super init])) {
        return nil;
    }
    
    predictionReadings = Mat::zeros(windowSize, 3, CV_32F);
    trainingReadings = Mat::zeros(windowSize*3, 3, CV_32F); // support up to three classes
    cv::Mat trainingLabels  = Mat::zeros(windowSize*3, 1, CV_32F);

    _motionQueue = [[NSOperationQueue alloc] init];
    _motionManager = [[CMMotionManager alloc] init];
    self.backgroundScanTaskID = UIBackgroundTaskInvalid;
    
    return self;
}

- (void)train;
{
    self.isTraining = true;
    [self startMonitoringWithSuccessBlock:nil];
}

- (void)predict;
{
    self.isPredicting = true;
    [self startMonitoringWithSuccessBlock:nil];
}

- (void)startMonitoringWithSuccessBlock:(void (^)())block;
{
    if ([self.motionManager isDeviceMotionActive] == YES) {
        [self stopMonitoringTask];
        DDLogInfo(@"Restarted Motion tracking.");
    } else {
        DDLogInfo(@"Start Motion tracking.");
    }
    
    self.backgroundScanTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                                 dispatch_async(dispatch_get_main_queue(), ^{
        DDLogInfo(@"Motion tracking task expired.");
        [self stopMonitoring];
    });
                                 }];
    // Check whether the accelerometer is available
    if ([self.motionManager isDeviceMotionAvailable] == YES) {
        // Assign the update interval to the motion manager
        [self.motionManager setDeviceMotionUpdateInterval:updateInterval];
        [self.motionManager startDeviceMotionUpdatesToQueue:self.motionQueue withHandler:^(CMDeviceMotion *motion, NSError *error) {
         [self processMotion:motion];
         }];
        self.foundFeatureBlock = block;
    }
}

- (BOOL)isMonitoring;
{
    return [self.motionManager isDeviceMotionActive];
}

- (void)stopMonitoringTask;
{
    DDLogInfo(@"FOOOO.");
    
    if ([self.motionManager isDeviceMotionActive] == YES) {
        DDLogInfo(@"Stop Motion tracking.");
        
        if (self.backgroundScanTaskID != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundScanTaskID];
            self.backgroundScanTaskID = UIBackgroundTaskInvalid;
        }
        
        [self.motionManager stopDeviceMotionUpdates];
    }
}

- (void)stopMonitoring;
{
    [self stopMonitoringTask];
    
    // make this asynchronous to avoid a deadlock with processMotion:
    [self performBlock:^{
     @synchronized(self) {
     self.foundFeatureBlock = nil;
     }
     } afterDelay:0.0];
}

- (void)dealloc;
{
    [self stopMonitoring];
    self.motionManager = nil;
    self.motionQueue = nil;
}

- (void)processMotion:(CMDeviceMotion *)motion;
{
    CMAcceleration acceleration = [motion userAcceleration];
    
    if (self.isTraining) {
        trainingReadings.at<double>(currentTrainingIndex,0) = acceleration.x;
        trainingReadings.at<double>(currentTrainingIndex,1) = acceleration.y;
        trainingReadings.at<double>(currentTrainingIndex,2) = acceleration.z;
        
        currentTrainingIndex++;
        
        if (currentTrainingIndex < classCount*windowSize) {
            return;
        }
        
        self.isTraining = false;
        [self stopMonitoring];

        trainingLabels.rowRange(classCount*windowSize, (classCount + 1)*windowSize).setTo(Scalar::all(classCount));
        
        cv::Mat sampleIdx = Mat::zeros(1, windowSize, CV_8U);
        Mat trainSamples = sampleIdx.colRange(0, (classCount + 1)*windowSize);
        trainSamples.setTo(Scalar::all(1));

        Ptr<cv::ml::TrainData> trainingData = cv::ml::TrainData::create(trainingReadings, cv::ml::SampleTypes::ROW_SAMPLE, trainingLabels, noArray(), sampleIdx, noArray(), noArray());
        
        model = cv::ml::RTrees::create();
        model->setMaxDepth(10);
        model->setMinSampleCount(10);
        model->setRegressionAccuracy(0);
        model->setUseSurrogates(false);
        model->setMaxCategories(3);
        model->setCalculateVarImportance(true);
        model->setActiveVarCount(3);
        model->setTermCriteria(cv::TermCriteria(cv::TermCriteria::MAX_ITER + cv::TermCriteria::EPS, 100, 0.00f));
        
        model->train(trainingData);
        classCount++;
    } else if (self.isPredicting) {
        predictionReadings.at<double>(currentPredictionIndex,0) = acceleration.x;
        predictionReadings.at<double>(currentPredictionIndex,1) = acceleration.y;
        predictionReadings.at<double>(currentPredictionIndex,2) = acceleration.z;
        
        currentPredictionIndex++;
        
        if (currentPredictionIndex < windowSize) {
            return;
        }
        
        model->predict(predictionReadings);
    }
}

@end
