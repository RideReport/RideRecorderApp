//
//  RandomForestManager
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#include "RandomForestManager.h"
#include<stdio.h>
#include <opencv2/opencv.hpp>
#include <opencv2/core.hpp>
#include <opencv2/ml.hpp>

// Private Functions
void fft(float * input, int inputSize, float *output, FFTSetup weightsSetup);
float max(cv::Mat mat);
double maxMean(cv::Mat mat, int windowSize);
double skewness(cv::Mat mat);
double kurtosis(cv::Mat mat);

struct RandomForestManager {
    int sampleSize;
    FFTSetup fftWeights;
    cv::Ptr<cv::ml::RTrees> model = cv::Ptr<cv::ml::RTrees>();
};

RandomForestManager *createRandomForestManager(int sampleSize, char* pathToModelFile)
{
    assert(fmod(log2(sampleSize), 1.0) == 0.0); // sampleSize must be a power of 2
    
    struct RandomForestManager *r;
    r = (struct RandomForestManager*) malloc(sizeof(struct RandomForestManager));
    r->sampleSize = sampleSize;
    r->fftWeights = vDSP_create_fftsetup(vDSP_Length(log2f(sampleSize)), FFT_RADIX2);
    r->model = cv::ml::RTrees::load<cv::ml::RTrees>(pathToModelFile);

    return r;
}

void deleteRandomForestManager(RandomForestManager *r)
{
    free(r);
}

int randomForesetClassifyMagnitudeVector(struct RandomForestManager *randomForestManager, float *magnitudeVector)
{
    cv::Mat mags = cv::Mat(randomForestManager->sampleSize, 1, CV_32F, &magnitudeVector);
    
    cv::Mat readings = cv::Mat::zeros(1, 6, CV_32F);

    cv::Scalar mean,stddev;
    meanStdDev(mags,mean,stddev);
    
    readings.at<float>(0,0) = max(mags);
    readings.at<float>(0,1) = (float)mean.val[0];
    readings.at<float>(0,2) = maxMean(mags, 5);
    readings.at<float>(0,3) = (float)stddev.val[0];
    readings.at<float>(0,4) = (float)skewness(mags);
    readings.at<float>(0,5) = (float)kurtosis(mags);
    
    return (int)randomForestManager->model->predict(readings, cv::noArray(), cv::ml::DTrees::PREDICT_MAX_VOTE);
}

void fft(float * input, int inputSize, float *output, FFTSetup weightsSetup)
{
    // apply a hamming window to the input
    float *hammingWindow = new float[inputSize];
    vDSP_hamm_window(hammingWindow, inputSize, 0);
    vDSP_vmul(input, 1, hammingWindow, 1, input, 1, inputSize);
    
    // pack the input samples in preparation for FFT
    DSPSplitComplex splitComplex;
    splitComplex.realp = new float[inputSize/2];
    splitComplex.imagp = new float[inputSize/2];
    vDSP_ctoz((DSPComplex*)input, 2, &splitComplex, 1, inputSize/2);

    // run the FFT and get the magnitude components (vDSP_zvmags returns squared components)
    vDSP_fft_zrip(weightsSetup, &splitComplex, 1, log2f(inputSize), FFT_FORWARD);
    vDSP_zvmags(&splitComplex, 1, output, 1, inputSize);
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