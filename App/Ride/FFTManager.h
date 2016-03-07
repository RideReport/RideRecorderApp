//
//  FFTManager
//  Ride
//
//  Created by William Henderson on 3/7/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

#ifndef FFTManager_h
#define FFTManager_h

#include <stdio.h>
#ifdef __cplusplus
extern "C" {
#endif
    typedef struct FFTManager FFTManager;
    FFTManager *createFFTManager(int sampleSize);
    void fft(float * input, int inputSize, float *output);
#ifdef __cplusplus
}
#endif
#endif /* FFTManager_h */
