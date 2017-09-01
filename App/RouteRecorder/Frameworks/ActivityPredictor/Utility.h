//
//  Utility.h
//  Ride
//
//  Created by William Henderson on 3/1/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

#ifndef Utility_h
#define Utility_h
#include <opencv2/core/core.hpp>
#include <vector>

#ifndef RANDOM_FOREST_PRINT_TIMING
#define RANDOM_FOREST_PRINT_TIMING (0)
#endif

#if RANDOM_FOREST_PRINT_TIMING
#include <iostream>
#include <chrono>
#include <sys/time.h>
#define LOCAL_TIMING_START() std::chrono::high_resolution_clock::time_point _t1 = std::chrono::high_resolution_clock::now()
#define LOCAL_TIMING_FINISH(name) do { \
    std::chrono::high_resolution_clock::time_point _t2 = std::chrono::high_resolution_clock::now(); \
    std::cerr << name << ": " << std::chrono::duration_cast<std::chrono::nanoseconds>( _t2 - _t1 ).count() << " nanoseconds" << std::endl; } while (0)
#else
#define LOCAL_TIMING_START() do {} while (0)
#define LOCAL_TIMING_FINISH(name) do {} while (0)
#endif

using namespace std;

bool interpolateSplineRegular(float* inputX, float* inputY, int inputLength, float* outputY, int outputLength, float newSpacing, float initialOffset);
float max(cv::Mat mat);
double maxMean(cv::Mat mat, int windowSize);
double skewness(cv::Mat mat);
double kurtosis(cv::Mat mat);
float trapezoidArea(vector<float>::iterator start, vector<float>::iterator end);
float percentile(float *input, int length, float percentile);

cv::Mat getRotationMatrixFromTwoVectors(cv::Mat from, cv::Mat to);


#endif /* Utility_h */
