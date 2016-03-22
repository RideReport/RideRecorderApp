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
    void deleteFFTManager(FFTManager *fftManager);
    
    void fft(FFTManager *manager, float * input, int inputSize, float *output);
    float dominantPower(float *input, int inputSize);
    float autocorrelation(float *input, int inputSize);
#ifdef __cplusplus
}
#endif