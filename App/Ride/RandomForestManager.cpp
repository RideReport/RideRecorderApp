//
//  RandomForestManager
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#include "RandomForestManager.h"
#include "FFTManager.h"
#include<stdio.h>
#include <opencv2/opencv.hpp>
#include <opencv2/core.hpp>
#include <opencv2/ml.hpp>

// Private Functions
float max(cv::Mat mat);
double maxMean(cv::Mat mat, int windowSize);
double skewness(cv::Mat mat);
double kurtosis(cv::Mat mat);

struct RandomForestManager {
    int sampleSize;
    FFTManager *fftManager;
    cv::Ptr<cv::ml::RTrees> model;
};

RandomForestManager *createRandomForestManager(int sampleSize, const char* pathToModelFile)
{
    assert(fmod(log2(sampleSize), 1.0) == 0.0); // sampleSize must be a power of 2
    
    RandomForestManager *r = new RandomForestManager;
    r->sampleSize = sampleSize;
    r->fftManager = createFFTManager(sampleSize);
    r->model = cv::ml::RTrees::load<cv::ml::RTrees>(pathToModelFile);

    return r;
}

void deleteRandomForestManager(RandomForestManager *r)
{
    free(r->fftManager);
    delete(r->model);
    free(r);
}

void prepFeatureVector(RandomForestManager *randomForestManager, float* features, float* magnitudeVector, float *speedVector, int speedVectorCount) {
    cv::Mat mags = cv::Mat(randomForestManager->sampleSize, 1, CV_32F, magnitudeVector);
    cv::Mat speeds = cv::Mat(speedVectorCount, 1, CV_32F, speedVector);

    cv::Scalar meanMag,stddevMag;
    meanStdDev(mags,meanMag,stddevMag);

    cv::Scalar meanSpeed,stddevSpeed;
    meanStdDev(mags,meanSpeed,stddevSpeed);
    
    float *fftOutput = new float[randomForestManager->sampleSize];
    fft(magnitudeVector, randomForestManager->sampleSize, fftOutput, randomForestManager->fftManager);
    float maxPower = dominantPower(fftOutput, randomForestManager->sampleSize);
    
    features[0] = max(mags);
    features[1] = (float)meanMag.val[0];
    features[2] = maxMean(mags, 5);
    features[3] = (float)stddevMag.val[0];
    features[4] = (float)skewness(mags);
    features[5] = (float)kurtosis(mags);
    features[6] = maxPower;
//    features[7] = (float)meanSpeed.val[0];
}

int randomForesetClassifyMagnitudeVector(RandomForestManager *randomForestManager, float *magnitudeVector, float *speedVector, int speedVectorCount)
{
    cv::Mat features = cv::Mat::zeros(1, RANDOM_FOREST_VECTOR_SIZE, CV_32F);
    prepFeatureVector(randomForestManager, features.ptr<float>(), magnitudeVector, speedVector, speedVectorCount);
    
    return (int)randomForestManager->model->predict(features, cv::noArray(), cv::ml::DTrees::PREDICT_MAX_VOTE);
}

float max(cv::Mat mat)
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

double maxMean(cv::Mat mat, int windowSize)
{
    if (windowSize>mat.rows) {
        return 0;
    }
    
    cv::Mat rollingMeans = cv::Mat::zeros(mat.rows - windowSize, 1, CV_32F);
    
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

double skewness(cv::Mat mat)
{
    cv::Scalar skewness,mean,stddev;
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

double kurtosis(cv::Mat mat)
{
    cv::Scalar kurt,mean,stddev;
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