//
//  RandomForestManager.cpp
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#include "RandomForestManager.h"
#include <opencv2/opencv.hpp>
#include <opencv2/core.hpp>
#include <opencv2/ml.hpp>

@protocol DeviceMotionsSample
@property (nonatomic, strong) NSOrderedSet * _Null_unspecified deviceMotions;
@end

@protocol DeviceMotion
@property (nonatomic, strong) id <DeviceMotionsSample> _Nullable deviceMotionsSample;
@property (nonatomic, strong) NSDate * _Nonnull date;
@property (nonatomic, strong) NSNumber * _Nonnull gravityX;
@property (nonatomic, strong) NSNumber * _Nonnull gravityY;
@property (nonatomic, strong) NSNumber * _Nonnull gravityZ;
@property (nonatomic, strong) NSNumber * _Nonnull userAccelerationX;
@property (nonatomic, strong) NSNumber * _Nonnull userAccelerationY;
@property (nonatomic, strong) NSNumber * _Nonnull userAccelerationZ;
@end

using namespace cv;
using namespace std;

static RandomForestManager *instance = nil;

@interface RandomForestManager ()

@property (nonatomic, copy) void(^foundFeatureBlock)();

@end

@implementation RandomForestManager

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
    
    NSString *path = [[NSBundle bundleForClass:[RandomForestManager class]] pathForResource:@"forest.cv" ofType:nil];
    const char * cpath = [path cStringUsingEncoding:NSUTF8StringEncoding];
    model = cv::ml::RTrees::load<cv::ml::RTrees>(cpath);
    
    return self;
}


- (int)classifyDeviceMotionSample:(id <DeviceMotionsSample>)sample;
{
    cv::Mat mags = Mat::zeros((int)sample.deviceMotions.count, 1, CV_32F);

    int i = 0;
    for (id<DeviceMotion> reading in sample.deviceMotions) {
        float sum = reading.userAccelerationX.floatValue*reading.userAccelerationX.floatValue* + reading.userAccelerationY.floatValue*reading.userAccelerationY.floatValue + reading.userAccelerationZ.floatValue*reading.userAccelerationZ.floatValue;
        mags.at<float>(i,0) = sqrtf(sum);
        i++;
    }
 
    
    cv::Mat readings = Mat::zeros(1, 6, CV_32F);

    cv::Scalar mean,stddev;
    meanStdDev(mags,mean,stddev);
    
    readings.at<float>(0,0) = [self max:mags];
    readings.at<float>(0,1) = (float)mean.val[0];
    readings.at<float>(0,2) = (float)[self maxMean:mags windowSize:5];
    readings.at<float>(0,3) = (float)stddev.val[0];
    readings.at<float>(0,4) = (float)[self skewness:mags];
    readings.at<float>(0,5) = (float)[self kurtosis:mags];
    
    return (int)model->predict(readings, noArray(), cv::ml::DTrees::PREDICT_MAX_VOTE);
}

- (float)max:(cv::Mat)mat;
{
    float max = 0;
    for (int i=0;i<mat.rows;i++)
    {
        float elem = mat.at<float>(i,0);
        if (elem > max) {
            max = elem;
        }
    }
    
    return max;
}

- (double)maxMean:(cv::Mat)mat windowSize:(int)windowSize;
{
    if (windowSize>mat.rows) {
        return 0;
    }
    
    cv::Mat rollingMeans = Mat::zeros(mat.rows - windowSize, 1, CV_32F);
    
    for (int i=0;i<=(mat.rows - windowSize);i++)
    {
        float sum = 0;
        for (int j=0;j<windowSize;j++) {
            sum += mat.at<float>(i+j,0);
        }
        rollingMeans.at<float>(i,0) = sum/windowSize;
    }
    
    double min, max;
    cv::minMaxLoc(rollingMeans, &min, &max);
    
    return max;
}

- (double)skewness:(cv::Mat)mat;
{
    cv:Scalar skewness,mean,stddev;
    skewness.val[0]=0;
    skewness.val[1]=0;
    skewness.val[2]=0;
    meanStdDev(mat,mean,stddev,cv::Mat());
    int sum0, sum1, sum2;
    float den0=0,den1=0,den2=0;
    int N=mat.rows*mat.cols;
    
    for (int i=0;i<mat.rows;i++)
    {
        for (int j=0;j<mat.cols;j++)
        {
            sum0=mat.ptr<uchar>(i)[3*j]-mean.val[0];
            sum1=mat.ptr<uchar>(i)[3*j+1]-mean.val[1];
            sum2=mat.ptr<uchar>(i)[3*j+2]-mean.val[2];
            
            skewness.val[0]+=sum0*sum0*sum0;
            skewness.val[1]+=sum1*sum1*sum1;
            skewness.val[2]+=sum2*sum2*sum2;
            den0+=sum0*sum0;
            den1+=sum1*sum1;
            den2+=sum2*sum2;
        }
    }
    
    skewness.val[0]=skewness.val[0]*sqrt(N)/(den0*sqrt(den0));
    skewness.val[1]=skewness.val[1]*sqrt(N)/(den1*sqrt(den1));
    skewness.val[2]=skewness.val[2]*sqrt(N)/(den2*sqrt(den2));
    
    return skewness.val[0];
}

- (double)kurtosis:(cv::Mat)mat;
{
    cv:Scalar kurt,mean,stddev;
    kurt.val[0]=0;
    kurt.val[1]=0;
    kurt.val[2]=0;
    meanStdDev(mat,mean,stddev,cv::Mat());
    int sum0, sum1, sum2;
    int N=mat.rows*mat.cols;
    float den0=0,den1=0,den2=0;
    
    for (int i=0;i<mat.rows;i++)
    {
        for (int j=0;j<mat.cols;j++)
        {
            sum0=mat.ptr<uchar>(i)[3*j]-mean.val[0];
            sum1=mat.ptr<uchar>(i)[3*j+1]-mean.val[1];
            sum2=mat.ptr<uchar>(i)[3*j+2]-mean.val[2];
            
            kurt.val[0]+=sum0*sum0*sum0*sum0;
            kurt.val[1]+=sum1*sum1*sum1*sum1;
            kurt.val[2]+=sum2*sum2*sum2*sum2;
            den0+=sum0*sum0;
            den1+=sum1*sum1;
            den2+=sum2*sum2;
        }
    }
    
    kurt.val[0]= (kurt.val[0]*N*(N+1)*(N-1)/(den0*den0*(N-2)*(N-3)))-(3*(N-1)*(N-1)/((N-2)*(N-3)));
    kurt.val[1]= (kurt.val[1]*N/(den1*den1))-3;
    kurt.val[2]= (kurt.val[2]*N/(den2*den2))-3;
    
    return kurt.val[0];
}

@end
