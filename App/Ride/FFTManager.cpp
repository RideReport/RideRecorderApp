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

FFTManager *createFFTManager(int sampleSize)
{
//    assert(fmod(log2(sampleSize), 1.0) == 0.0); // sampleSize must be a power of 2
    
    struct FFTManager *f;
    f = (struct FFTManager*) malloc(sizeof(struct FFTManager));
    f->fftWeights = vDSP_create_fftsetup(vDSP_Length(log2f(sampleSize)), FFT_RADIX2);
    
    return f;
}

void fft(float * input, int inputSize, float *output, FFTManager *manager)
{
    // apply a hamming window to the input
    float *hammingWindow = new float[inputSize];
    vDSP_hamm_window(hammingWindow, inputSize, 0);
    vDSP_vmul(input, 1, hammingWindow, 1, input, 1, inputSize);
    
    // pack the input samples in preparation for FFT
    float *zeroArray = new float[inputSize/2];
    DSPSplitComplex splitComplex = {.realp = input, .imagp =  zeroArray};
    
    // run the FFT and get the magnitude components (vDSP_zvmags returns squared components)
    vDSP_fft_zrip(manager->fftWeights, &splitComplex, 1, log2f(inputSize), FFT_FORWARD);
    vDSP_zvmags(&splitComplex, 1, output, 1, inputSize);
}

float dominantPower(float *input, int inputSize)
{
    return 0.0f;
    
    float dominantFrequency = 0;
    for (int i=0; i<inputSize/2; i+=2) {
        float value = input[i];
        if (value > dominantFrequency) {
            dominantFrequency = value;
        }
    }
    
    return dominantFrequency;
}