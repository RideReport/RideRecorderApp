//
//  RandomForestManager
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#include "RandomForestManager.h"
#ifdef __APPLE__
#include "FFTManager.h"
#else
#include "FFTManager_fftw.h"
#endif
#include<stdio.h>
#include <algorithm>
#include <opencv2/core/core.hpp>
#include <opencv2/ml/ml.hpp>

#ifdef __APPLE__
#define FFT_TYPE_NUMBER 0
#else
#define FFT_TYPE_NUMBER 1
#endif

using namespace cv;

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
    deleteFFTManager(r->fftManager);

    delete(r->model);
    free(r);
}

/**
 * Compute area under the curve for an evenly spaced vector `y` of length `length`
 *
 * We assume unit steps on the X-axis. Multiply the return value by a scaling
 * factor to convert to real-world measurements.
 */
float trapezoidArea(float *y, int length)
{
    float area = 0.0;
    if (length >= 1) {
        for (int i = 1; i < length; ++i) {
            area += y[i] - y[i-1] / 2.;
        }
    }
    return area;
}

float percentile(float *input, int length, float percentile)
{
    std::vector<float> sortedInput(length);
    
    // using default comparison (operator <):
    std::partial_sort_copy (input, input+length, sortedInput.begin(), sortedInput.end());

    return sortedInput[cvFloor(length*percentile)-1];
}

void prepFeatureVector(RandomForestManager *randomForestManager, float* features, float* magnitudeVector) {
    cv::Mat mags = cv::Mat(randomForestManager->sampleSize, 1, CV_32F, magnitudeVector);

    cv::Scalar meanMag,stddevMag;
    meanStdDev(mags,meanMag,stddevMag);

    float *fftOutput = new float[randomForestManager->sampleSize];

    fft(randomForestManager->fftManager, magnitudeVector, randomForestManager->sampleSize, fftOutput);
    float maxPower = dominantPower(fftOutput, randomForestManager->sampleSize);
    float fftAutocorrelation = autocorrelation(fftOutput, randomForestManager->sampleSize);

    float *spectrum = fftOutput + 1; // skip DC (zero frequency) component
    int spectrumLength = randomForestManager->sampleSize / 2;
    float fftIntegral = trapezoidArea(spectrum, spectrumLength);
    // These numbers are hard-coded for a 64-element input array
    float fftIntegralAbove8hz = trapezoidArea(spectrum + 26, spectrumLength - 26);
    float fftIntegralBelow2_5hz = trapezoidArea(spectrum, 8);

    features[0] = max(mags);
    features[1] = (float)meanMag.val[0];
    features[2] = maxMean(mags, 5);
    features[3] = (float)stddevMag.val[0];
    features[4] = (float)skewness(mags);
    features[5] = (float)kurtosis(mags);
    features[6] = maxPower;
    features[7] = fftIntegral;
    features[8] = fftIntegralAbove8hz;
    features[8] = fftIntegralBelow2_5hz;
    features[8] = fftAutocorrelation;
    features[9] = percentile(magnitudeVector, randomForestManager->sampleSize, 0.25);
    features[10] = percentile(magnitudeVector, randomForestManager->sampleSize, 0.5);
    features[11] = percentile(magnitudeVector, randomForestManager->sampleSize, 0.75);
    features[12] = percentile(magnitudeVector, randomForestManager->sampleSize, 0.9);
}

int randomForesetClassifyMagnitudeVector(RandomForestManager *randomForestManager, float *magnitudeVector)
{
    cv::Mat features = cv::Mat::zeros(1, RANDOM_FOREST_VECTOR_SIZE, CV_32F);
    prepFeatureVector(randomForestManager, features.ptr<float>(), magnitudeVector);

    return (int)randomForestManager->model->predict(features, cv::noArray(), cv::ml::DTrees::PREDICT_MAX_VOTE);
}

void randomForestClassificationConfidences(RandomForestManager *randomForestManager, float *magnitudeVector, float *confidences, int n_classes) {
    cv::Mat features = cv::Mat::zeros(1, RANDOM_FOREST_VECTOR_SIZE, CV_32F);

    prepFeatureVector(randomForestManager, features.ptr<float>(), magnitudeVector);

    cv::Mat results;

    randomForestManager->model->predictProb(features, results, cv::ml::DTrees::PREDICT_CONFIDENCE);

    for (int i = 0; i < n_classes; ++i) {
        confidences[i] = results.at<float>(i);
    }
}

int randomForestGetClassLabels(RandomForestManager *randomForestManager, int *labels, int n_classes) {
    Mat labelsMat = randomForestManager->model->getClassLabels();
    for (int i = 0; i < n_classes && i < labelsMat.rows; ++i) {
        labels[i] = labelsMat.at<int>(i);
    }
    return labelsMat.rows;
}

int randomForestGetClassCount(RandomForestManager *randomForestManager) {
    Mat labelsMat = randomForestManager->model->getClassLabels();
    return labelsMat.rows;
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
