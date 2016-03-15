//
//  FFTManager
//  Ride
//
//  Created by William Henderson on 3/7/16.
//  Copyright © 2016 Knock Softwae, Inc. All rights reserved.
//

#ifdef __cplusplus
extern "C" {
#endif
    typedef struct FFTManager FFTManager;
    FFTManager *createFFTManager(int sampleSize);
    void fft(float * input, int inputSize, float *output, FFTManager *manager);
    float dominantPower(float *input, int inputSize);
    void deleteFFTManager(FFTManager *fftManager);
#ifdef __cplusplus
}
#endif