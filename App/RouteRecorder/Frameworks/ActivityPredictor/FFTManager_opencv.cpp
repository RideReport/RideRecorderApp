#include "FFTManager.h"
#include <stdlib.h>
#include <math.h>

#include <opencv2/core/core.hpp>
using namespace cv;

struct FFTManager {
    unsigned int N;
    float* multipliers;
};

void setupHammingWindow(float *values, int N) {
    for (int i = 0; i < N; ++i) {
        values[i] = 0.54 - 0.46 * cos(2*M_PI*i/N);
    }
}

FFTManager* createFFTManager(int sampleSize) {
    FFTManager* _fft = (struct FFTManager*) malloc(sizeof(struct FFTManager));
    _fft->N = sampleSize;
    _fft->multipliers = (float*) malloc(sizeof(float) * sampleSize);
    setupHammingWindow(_fft->multipliers, sampleSize);

    return _fft;
}

void fft(FFTManager *_fft, float * input, int inputSize, float *output) {
    if (inputSize != _fft->N) {
        // throw?
        return;
    }

    float *multipliedInput = (float*) malloc(sizeof(float) * _fft->N);
    for (int i = 0; i < _fft->N; ++i) {
        multipliedInput[i] = input[i] * _fft->multipliers[i];
    }

    Mat dftInput = Mat(inputSize, 1, CV_32F, multipliedInput);
    Mat dftOutput;
    Mat splitComplex[] = { Mat(inputSize, 1, CV_32F), Mat(inputSize, 1, CV_32F) };

    //Mat(inputSize, 1, CV_32F, output)
    dft(dftInput, dftOutput, DFT_COMPLEX_OUTPUT);

    // splitComplex[0] = Re(dftOutput), splitComplex[1] = Im(dftOutput)
    split(dftOutput, splitComplex);

    // Compute *squared* magnitudes == "power"
    for (int i = 0; i <= _fft->N/2; ++i) {
        output[i] = (splitComplex[0].at<float>(i) * splitComplex[0].at<float>(i)) + (splitComplex[1].at<float>(i) * splitComplex[1].at<float>(i));
    }

	  free(multipliedInput);
}

void deleteFFTManager(FFTManager *_fft) {
    free(_fft->multipliers);
    free(_fft);
}

float dominantPower(float *output, int inputSize) {
    float max = 0.0;
    for (int i = 1; i <= inputSize/2; ++i) {
        if (output[i] > max) {
            max = output[i];
        }
    }

    return max;
}
