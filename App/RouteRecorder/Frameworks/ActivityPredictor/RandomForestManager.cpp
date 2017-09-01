//
//  RandomForestManager
//  Ride
//
//  Created by William Henderson on 12/4/15.
//  Copyright © 2015 Knock Softwae, Inc. All rights reserved.
//

#include "RandomForestManager.h"
#include "FFTManager.h"

#ifdef __ANDROID__
#include <android/log.h>
#define DEBUG(str) __android_log_print(ANDROID_LOG_VERBOSE, "RandomForestManager", (str))
#else
#include <iostream>
#define DEBUG(str) (cerr << "RandomForestManager DEBUG: " << str << endl)
#endif

#include <algorithm>
#include <numeric>
#include <opencv2/core/core.hpp>
#include <opencv2/ml/ml.hpp>
#include <vector>
#include <cmath>
#include <fstream>
#include "json/json.h"

#include "Utility.h"

#ifdef __APPLE__
#define FFT_TYPE_NUMBER 0
#else
#define FFT_TYPE_NUMBER 1
#endif

using namespace cv;
using namespace std;


struct RandomForestConfiguration {
    int sampleCount;
    float samplingRateHz;

    string modelUID;
};

struct RandomForestManager {
    string modelPath;
    string modelUID;

    int sampleCount;
    float samplingRateHz;

    int fftIndex_below2_5hz;
    int fftIndex_above2hz;
    int fftIndex_above3_5hz;

    FFTManager *fftManager;


    vector<float> differences;

    cv::Ptr<cv::ml::RTrees> model;
};

const float log_of_2 = log(2);

bool loadConfigurationFromString(RandomForestConfiguration* config, const char* jsonString);
bool loadConfigurationFromJsonFile(RandomForestConfiguration* config, const char* pathToJson);
void loadJson(char* pathToJson);

RandomForestManager *createRandomForestManagerFromConfiguration(RandomForestConfiguration* config) {
    RandomForestManager *r = new RandomForestManager;
    r->sampleCount = config->sampleCount;
    r->samplingRateHz = config->samplingRateHz;
    r->modelUID = config->modelUID;

    r->fftManager = createFFTManager(r->sampleCount);

    float sampleSpacing = 1. / r->samplingRateHz;
    r->fftIndex_below2_5hz = floorf(sampleSpacing * r->sampleCount * 2.5);
    r->fftIndex_above2hz = ceilf(sampleSpacing * r->sampleCount * 2.0);
    r->fftIndex_above3_5hz = ceilf(sampleSpacing * r->sampleCount * 3.5);

    r->differences = vector<float>(r->sampleCount);

    return r;
}

RandomForestManager *createRandomForestManagerFromJsonString(const char* jsonString) {
    RandomForestConfiguration config;
    if (loadConfigurationFromString(&config, jsonString)) {
        return createRandomForestManagerFromConfiguration(&config);
    }
    else {
        return NULL;
    }
}

RandomForestManager *createRandomForestManagerFromFile(const char* pathToJson)
{
    RandomForestConfiguration config;
    if (loadConfigurationFromJsonFile(&config, pathToJson)) {
        return createRandomForestManagerFromConfiguration(&config);
    }
    else {
        return NULL;
    }
}

bool randomForestLoadModel(RandomForestManager *r, const char* pathToModelFile) {
    if (pathToModelFile == NULL) {
        return false;
    }
    r->modelPath = string(pathToModelFile);

    r->model = cv::ml::RTrees::load<cv::ml::RTrees>(r->modelPath);
    return true;
}

/**
 * Maximum spacing between accelerometer readings, in seconds
 */
float randomForestGetDesiredSamplingInterval(RandomForestManager *r) {
    return 1. / r->samplingRateHz;
}

/**
 * Minimum length of continuous readings, in seconds
 */
float randomForestGetDesiredSessionDuration(RandomForestManager *r) {
    // Desired duration is the difference between the time of the first
    // and the time of the last
    return (r->sampleCount - 1) / r->samplingRateHz;
}

const char* randomForestGetModelUniqueIdentifier(RandomForestManager *r) {
    return r->modelUID.c_str();
}

bool randomForestManagerCanPredict(RandomForestManager *r) {
    if (r->model.empty()) {
        DEBUG("model is not loaded");
        return false;
    }

    if (r->model->getVarCount() != RANDOM_FOREST_VECTOR_SIZE) {
        DEBUG("var count does not match");
        return false;
    }
    return true;
}

void deleteRandomForestManager(RandomForestManager *r)
{
    if (r != NULL) {
        deleteFFTManager(r->fftManager);

        if (!r->model.empty()) {
            r->model.release();
        }
        free(r);
    }
}

float shannonEntropy(vector<float>::iterator begin, vector<float>::iterator end) {
    // c.f. https://en.wikipedia.org/wiki/Entropy_(information_theory)
    // c.f. https://pdfs.semanticscholar.org/c2d0/8896042a9eeab750894d0a94b580b86ceb8f.pdf
    // c.f. https://github.com/tyiannak/pyAudioAnalysis/blob/master/audioFeatureExtraction.py

    float sum = 0.0;
    for (auto it = begin; it != end; ++it) {
        sum += *it;
    }

    // Normalize vector, then compute entropy
    float entropy = 0.0;
    float value;
    for (auto it = begin; it != end; ++it) {
        value = *it / sum;
        entropy += ( value * log(value) / log_of_2 );
    }

    return entropy;
}

// number of features that are computed by this function
static const int BASIC_FEATURE_COUNT = 14;

void calculateFeaturesFromRegularVector(RandomForestManager *randomForestManager, float* features, float* vec) {
    LOCAL_TIMING_START();

    cv::Mat mags = cv::Mat(randomForestManager->sampleCount, 1, CV_32F, vec);

    cv::Scalar meanMag,stddevMag;
    meanStdDev(mags,meanMag,stddevMag);

    float *fftOutput = new float[randomForestManager->sampleCount];

    fft(randomForestManager->fftManager, vec, randomForestManager->sampleCount, fftOutput);
    float maxPower = dominantPower(fftOutput, randomForestManager->sampleCount);

    int spectrumLength = randomForestManager->sampleCount / 2; // exclude nyquist frequency
    vector<float> spectrum (fftOutput, fftOutput + spectrumLength);
    float fftIntegral = trapezoidArea(spectrum.begin() + 1, spectrum.end()); // exclude DC / 0Hz power

    float fftIntegralBelow2_5hz = trapezoidArea(
        spectrum.begin() + 1, // exclude DC
        spectrum.begin() + randomForestManager->fftIndex_below2_5hz + 1); // include 2.5Hz component

    features[0] = max(mags);
    features[1] = (float)meanMag.val[0];
    features[2] = maxMean(mags, 5);
    features[3] = (float)stddevMag.val[0];
    features[4] = (float)skewness(mags);
    features[5] = (float)kurtosis(mags);
    features[6] = maxPower;
    features[7] = fftIntegral;
    features[8] = fftIntegralBelow2_5hz;
    features[9] = percentile(vec, randomForestManager->sampleCount, 0.25);
    features[10] = percentile(vec, randomForestManager->sampleCount, 0.5);
    features[11] = percentile(vec, randomForestManager->sampleCount, 0.75);
    features[12] = percentile(vec, randomForestManager->sampleCount, 0.9);
    features[13] = shannonEntropy(spectrum.begin() + 1, spectrum.end()); // exclude DC

    LOCAL_TIMING_FINISH("calculateFeaturesFromRegularVector");
}

void randomForestClassifyFeatures(RandomForestManager *randomForestManager, float* features, float* confidences, int n_classes) {
    cv::Mat featuresMat = cv::Mat(1, RANDOM_FOREST_VECTOR_SIZE, CV_32F, (void*) features);
    if (randomForestManager->model.empty()) {
        return;
    }

    cv::Mat results;

    LOCAL_TIMING_START();
    randomForestManager->model->predictProb(featuresMat, results, cv::ml::DTrees::PREDICT_CONFIDENCE);
    LOCAL_TIMING_FINISH("predictProb");

    for (int i = 0; i < n_classes; ++i) {
        confidences[i] = results.at<float>(i);
    }
}

bool readingIsLess(AccelerometerReadingStruct a, AccelerometerReadingStruct b) {
    return ((a.t) < (b.t));
}

bool prepareNormsAndSeconds(AccelerometerReadingStruct* readings, Mat vecsMat, float* norms, float* seconds, int readingCount) {
    LOCAL_TIMING_START();

    auto readingVector = std::vector<AccelerometerReadingStruct>(readings, readings + readingCount);
    std::sort(readings, readings + readingCount, readingIsLess);

    if (readingCount < 1) {
        return false;
    }

    float* norm;
    float* second;
    AccelerometerReadingStruct* reading;
    int i;
    double firstReadingT = readings[0].t;
    for (second = seconds, norm = norms, reading = readings, i = 0;
        i < readingCount;
        ++i, ++reading, ++norm, ++second) {

        vecsMat.at<float>(i, 0) = reading->x;
        vecsMat.at<float>(i, 1) = reading->y;
        vecsMat.at<float>(i, 2) = reading->z;

        *norm = sqrt(
            (reading->x * reading->x) +
            (reading->y * reading->y) +
            (reading->z * reading->z));
        *second = (float)(reading->t - firstReadingT);
    }

    LOCAL_TIMING_FINISH("prepareNormsAndSeconds");
    return true;
}

bool randomForestClassifyAccelerometerSignal(RandomForestManager *randomForestManager, AccelerometerReadingStruct* readings, int readingCount, float* confidences, int n_classes) {
    float* features = new float[RANDOM_FOREST_VECTOR_SIZE];
    bool successful = randomForestPrepareFeaturesFromAccelerometerSignal(randomForestManager, readings, readingCount, features, RANDOM_FOREST_VECTOR_SIZE, 0.f);
    if (successful) {
        randomForestClassifyFeatures(randomForestManager, features, confidences, n_classes);
    }

    delete[] features;
    return successful;
}

bool prepareRotatedSignal(float* seconds, Mat vecsMat, float* zs, float* xyNorms, int readingCount)
{
    assert(readingCount == vecsMat.rows);
    assert(3 == vecsMat.cols);

    if (readingCount < 1) {
        return false;
    }

    Mat meanVec;
    reduce(vecsMat, meanVec, 0, CV_REDUCE_AVG);
    Mat zAxis = (Mat_<float>(1, 3) << 0.f, 0.f, 1.f);
    Mat rotationMatrix = getRotationMatrixFromTwoVectors(meanVec, zAxis);
    Mat row;
    for (int i = 0; i < vecsMat.rows; ++i) {
        row = (rotationMatrix * vecsMat.row(i).t()).t();
        zs[i] = row.at<float>(2);
        xyNorms[i] = sqrtf(row.at<float>(0) * row.at<float>(0) + row.at<float>(1) * row.at<float>(1));
    }

    return true;
}

bool randomForestPrepareFeaturesFromAccelerometerSignal(RandomForestManager *randomForestManager,
        AccelerometerReadingStruct* readings, int readingCount,
        float* features, int feature_count, float offsetSeconds) {
    if (feature_count < RANDOM_FOREST_VECTOR_SIZE) {
        return false;
    }

    LOCAL_TIMING_START();

    float* norms = new float[readingCount];
    Mat vecsMat = Mat(readingCount, 3, CV_32F);
    float* seconds = new float[readingCount];
    bool successful = false;
    if (prepareNormsAndSeconds(readings, vecsMat, norms, seconds, readingCount)) {
        float* resampledNorms = new float[randomForestManager->sampleCount];
        float* zs = new float[readingCount];
        float* xyNorms = new float[readingCount];
        float newSpacing = 1.f / ((float)randomForestManager->samplingRateHz);

        successful = interpolateSplineRegular(seconds, norms, readingCount, resampledNorms, randomForestManager->sampleCount, newSpacing, offsetSeconds);
        if (successful) {
            calculateFeaturesFromRegularVector(randomForestManager, features, resampledNorms);
        }

        if (successful && prepareRotatedSignal(seconds, vecsMat, zs, xyNorms, readingCount)) {
            float* resampledZs = new float[randomForestManager->sampleCount];
            float* resampledXYNorms = new float[randomForestManager->sampleCount];
            successful = successful && interpolateSplineRegular(seconds, zs, readingCount, resampledZs, randomForestManager->sampleCount, newSpacing, offsetSeconds);
            if (successful) {
                calculateFeaturesFromRegularVector(randomForestManager, features + BASIC_FEATURE_COUNT, resampledZs);
            }
            successful = successful && interpolateSplineRegular(seconds, xyNorms, readingCount, resampledXYNorms, randomForestManager->sampleCount, newSpacing, offsetSeconds);
            if (successful) {
                calculateFeaturesFromRegularVector(randomForestManager, features + BASIC_FEATURE_COUNT * 2, resampledXYNorms);
            }

            delete[] resampledXYNorms;
            delete[] resampledZs;
        }

        delete[] zs;
        delete[] xyNorms;
        delete[] resampledNorms;
    }
    delete[] norms;
    delete[] seconds;

    LOCAL_TIMING_FINISH("randomForestPrepareFeaturesFromAccelerometerSignal");
    return successful;
}

int randomForestGetClassLabels(RandomForestManager *randomForestManager, int *labels, int n_classes) {
    if (randomForestManager->model.empty()) {
        return 0;
    }

    Mat labelsMat = randomForestManager->model->getClassLabels();
    for (int i = 0; i < n_classes && i < labelsMat.rows; ++i) {
        labels[i] = labelsMat.at<int>(i);
    }
    return labelsMat.rows;
}

int randomForestGetClassCount(RandomForestManager *randomForestManager) {
    if (randomForestManager->model.empty()) {
        return 0;
    }

    Mat labelsMat = randomForestManager->model->getClassLabels();
    return labelsMat.rows;
}

void loadConfigurationFromJsonValue(RandomForestConfiguration* config, Json::Value root) {
    if (root["model_metadata_version"].asInt() > 1) {
        throw std::runtime_error("Unsupported value for model_metadata_version");
    }

    Json::Value sampleCount = root["sampling"]["sample_count"];
    if (sampleCount.isNull() || !sampleCount.isInt()) {
        throw std::runtime_error("Unacceptable sample_count");
    }

    config->sampleCount = sampleCount.asInt();
    if (fmod(log(config->sampleCount)/log(2), 1.0) != 0.0) {
        throw std::runtime_error("sampleCount must be a power of 2");
    }

    Json::Value samplingRateHz = root["sampling"]["sampling_rate_hz"];
    if (samplingRateHz.isNull() || !samplingRateHz.isNumeric()) {
        throw std::runtime_error("Unsupported sampling_rate_hz");
    }
    config->samplingRateHz = samplingRateHz.asFloat();

    // This field is optional in the case where we are training a new model; returns empty string if not present
    config->modelUID = root["cv_sha256"].asString();
}

bool loadConfigurationFromString(RandomForestConfiguration* config, const char* jsonString) {
    stringstream ss(jsonString);
    Json::Value root;
    ss >> root;
    try {
        loadConfigurationFromJsonValue(config, root);
    }
    catch (std::runtime_error& e) {
        cerr << "ActivityPredictor/Utility.cpp:" << __LINE__ << ": Failed to load configuration: " << e.what() << endl;
        return false;
    }
    catch (std::exception& e) {
        cerr << "ActivityPredictor/Utility.cpp:" << __LINE__ << ": Failed to load configuration: " << e.what() << endl;
        return false;
    }
    return true;
}

bool loadConfigurationFromJsonFile(RandomForestConfiguration* config, const char* pathToJson) {
    try {
        ifstream doc(pathToJson, ifstream::binary);
        Json::Value root;
        doc >> root;
        loadConfigurationFromJsonValue(config, root);
    }
    catch (std::runtime_error& e) {
        cerr << "ActivityPredictor/Utility.cpp:" << __LINE__ << ": Failed to load configuration: " << e.what() << endl;
        return false;
    }
    catch (std::exception& e) {
        cerr << "ActivityPredictor/Utility.cpp:" << __LINE__ << ": Failed to load configuration: " << e.what() << endl;
        return false;
    }
    return true;
}
