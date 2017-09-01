//
//  FFTManager.c
//  Ride
//
//  Created by William Henderson on 3/7/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

#include "FFTManager.h"
#include<stdio.h>
#include <Accelerate/Accelerate.h>

struct FFTManager {
    FFTSetup fftWeights;
};

FFTManager *createFFTManager(int sampleCount)
{
//    assert(fmod(log2(sampleCount), 1.0) == 0.0); // sampleCount must be a power of 2

    struct FFTManager *f;
    f = (struct FFTManager*) malloc(sizeof(struct FFTManager));
    f->fftWeights = vDSP_create_fftsetup(vDSP_Length(log2f(sampleCount)), FFT_RADIX2);

    return f;
}

void deleteFFTManager(FFTManager *fftManager)
{
    vDSP_destroy_fftsetup(fftManager->fftWeights);
    free(fftManager);
}

void fft(FFTManager *manager, float * input, int inputSize, float *output)
{
    // apply a hamming window to the input
    float *hammingWindow = new float[inputSize];
    vDSP_hamm_window(hammingWindow, inputSize, 0);
    float *hammedInput = new float[inputSize]();
    vDSP_vmul(input, 1, hammingWindow, 1, hammedInput, 1, inputSize);
    // pack the input samples in preparation for FFT
    float *zeroArray = new float[inputSize]();
    DSPSplitComplex splitComplex = {.realp = hammedInput, .imagp =  zeroArray};

    // run the FFT and get the magnitude components (vDSP_zvmags returns squared components)
    vDSP_fft_zip(manager->fftWeights, &splitComplex, 1, log2f(inputSize), FFT_FORWARD);
    vDSP_zvmags(&splitComplex, 1, output, 1, inputSize);

    delete[](zeroArray);
    delete[](hammingWindow);
}

void autocorrelation(float *input, int inputSize, float *output)
{
    int lenSignal = 2 * inputSize - 1;
    float *signal = new float[lenSignal];

    for (int i = 0; i < inputSize; i++) {
        if (i < inputSize) {
            signal[i] = input[i];
        } else {
            signal[i] = 0;
        }
    }

//    float *result = new float[inputSize];
//    vDSP_conv(signal, 1, &input[inputSize - 1], -1, result, 1, inputSize, inputSize);
    vDSP_conv(signal, 1, &input[inputSize - 1], -1, output, 1, inputSize, inputSize);

    delete[](signal);
//    free(result);

//    return 0.0;
}

float dominantPower(float *input, int inputSize)
{
    float dominantPower = 0;
    for (int i=1; i<=inputSize/2; i+=1) {
        float value = input[i];
        if (value > dominantPower) {
            dominantPower = value;
        }
    }

    return dominantPower;
}
