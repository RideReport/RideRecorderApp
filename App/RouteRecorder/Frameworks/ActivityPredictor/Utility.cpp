#include <stdio.h>
#include <math.h>
#include "Utility.h"
#include <opencv2/core/core.hpp>

#include <iostream>

using namespace std;
using namespace cv;

// spline interpolator from:
// http://blog.ivank.net/interpolation-with-cubic-splines.html
// (MIT license, translated from JS)

void swapRows(cv::Mat M, int k, int l) {
    float temp;
    for (int i = 0; i < M.cols; ++i) {
        temp = M.at<float>(k, i);
        M.at<float>(k, i) = M.at<float>(l, i);
        M.at<float>(l, i) = temp;
    }
}

void printMatrix(cv::Mat A) {
    cerr << "Matrix " << A.rows << "x" << A.cols << endl;
    for (int i = 0; i < A.rows; ++i) {
        for (int j = 0; j < A.cols; ++j) {
            cerr << A.at<float>(i, j) << " ";
        }
        cerr << endl;
    }
}

void printVector(float* x, int len) {
    cerr << "Vector " << len << endl;
    for (int i = 0; i < len; ++i) {
        cerr << x[i] << " ";
    }
    cerr << endl;
}

void solveTDMatrixThomas(cv::Mat A, float* x) {
    // Solve for x in the matrix equation Ax = b.
    //
    // The first `A.rows` columns of parameter A are the matrix A; the last
    // column is the result vector b.

    cv::Mat d = A.col(A.rows);

    int n = A.rows;

    for (int i = 0; i < n; ++i) {
        assert(A.at<float>(i, i) != 0.f);
    }

    float m;
    for (int k = 1; k < n; k++) {
        // m = a_k / b_(k-1)
        m = A.at<float>(k, k-1) / A.at<float>(k-1, k-1);
        // b_k = b_k - m*c_(k-1)
        A.at<float>(k, k) -= m * A.at<float>(k-1, k);
        // d_k = d_k - m*d_(k-1)
        d.at<float>(k) -= m * d.at<float>(k-1);
    }

    x[n-1] = d.at<float>(n-1) / A.at<float>(n-1, n-1);
    for (int k = n-2; k >= 0; k--) {
        x[k] = (d.at<float>(k) - A.at<float>(k, k+1) * x[k+1]) / A.at<float>(k, k);
    }
}

void solveMatrixGaussJordan(cv::Mat A, float* x) {
    int rows = A.rows;
    for(int k=0; k<rows; k++)	// column
    {
        // pivot for column
        int i_max = 0;
        double vali = -1;
        for (int i=k; i<rows; i++)
        {
            if (abs(A.at<float>(i, k))>vali)
            {
                i_max = i;
                vali = abs(A.at<float>(i, k));
            }
        }
        swapRows(A, k, i_max);

        // for all rows below pivot
        for(int i=k+1; i<rows; i++)
        {
            double cf = (A.at<float>(i, k) / A.at<float>(k, k));
            for (int j=k; j<rows+1; j++) {
                A.at<float>(i, j) -= A.at<float>(k, j) * cf;
            }
        }
    }

	for(int i=rows-1; i>=0; i--)	// rows = columns
	{
		double v = A.at<float>(i, rows) / A.at<float>(i, i);
		x[i] = v;
		for(int j=i-1; j>=0; j--)	// rows
		{
			A.at<float>(j, rows) -= A.at<float>(j, i) * v;
			A.at<float>(j, i) = 0;
		}
	}
}


void getNaturalKs(float* xs, int xCount, float* ys, float* ks)
{
   cv::Mat A(xCount, xCount+1, CV_32F);
   for(int x = 0; x < xCount; x++) {
       for(int y = 0; y < xCount + 1; y ++) {
           A.at<float>(x, y) = 0;
       }
   }

   for(int i=1; i<xCount-1; i++) {
       A.at<float>(i, i-1) = 1/(xs[i] - xs[i-1]);

       A.at<float>(i, i) = 2 * (1/(xs[i] - xs[i-1]) + 1/(xs[i+1] - xs[i])) ;

       A.at<float>(i, i+1) = 1/(xs[i+1] - xs[i]);

       A.at<float>(i, xCount) = 3*( (ys[i]-ys[i-1])/((xs[i] - xs[i-1])*(xs[i] - xs[i-1]))  +  (ys[i+1]-ys[i])/ ((xs[i+1] - xs[i])*(xs[i+1] - xs[i])) );
   }

   A.at<float>(0, 0) = 2/(xs[1] - xs[0]);
   A.at<float>(0, 1) = 1/(xs[1] - xs[0]);
   A.at<float>(0, xCount) = 3 * (ys[1] - ys[0]) / ((xs[1]-xs[0])*(xs[1]-xs[0]));

   A.at<float>(xCount-1, xCount-2) = 1/(xs[xCount-1] - xs[xCount-2]);
   A.at<float>(xCount-1, xCount-1) = 2/(xs[xCount-1] - xs[xCount-2]);
   A.at<float>(xCount-1, xCount) = 3 * (ys[xCount-1] - ys[xCount-2]) / ((xs[xCount-1]-xs[xCount-2])*(xs[xCount-1]-xs[xCount-2]));

   solveTDMatrixThomas(A, ks);
}

float evaluateSpline(float x, float* xs, float *ys, float *ks)
{
   int i = 1;
   while(xs[i]<x) {
       i++;
   }

   float t = (x - xs[i-1]) / (xs[i] - xs[i-1]);

   float a =  ks[i-1]*(xs[i]-xs[i-1]) - (ys[i]-ys[i-1]);
   float b = -ks[i  ]*(xs[i]-xs[i-1]) + (ys[i]-ys[i-1]);

   float q = (1-t)*ys[i-1] + t*ys[i] + t*(1-t)*(a*(1-t)+b*t);

   return q;
}

bool interpolateSplineRegular(float* inputX, float* inputY, int inputLength, float* outputY, int outputLength, float newSpacing, float initialOffset) {
    LOCAL_TIMING_START();

    if (inputLength < 4) {
        // getNaturalKs may fail without inputLength of at least 4

        return false;
    }

    float ks[inputLength];
    float maxX = inputX[inputLength-1];

    getNaturalKs(inputX, inputLength, inputY, ks);
    int outputIndex;
    for (outputIndex = 0; outputIndex < outputLength; ++outputIndex) {
        float newX = inputX[0] + initialOffset + outputIndex * newSpacing;
        if (newX > maxX) {
           break;
        }
        outputY[outputIndex] = evaluateSpline(newX, inputX, inputY, ks);
    }

    LOCAL_TIMING_FINISH("interpolateSplineRegular");
    return outputIndex == outputLength;
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

/**
 * Compute area under the curve for an evenly spaced vector `y` of length `length`
 *
 * We assume unit steps on the X-axis. Multiply the return value by a scaling
 * factor to convert to real-world measurements.
 */
float trapezoidArea(vector<float>::iterator start, vector<float>::iterator end)
{
    float area = 0.0;
    if (start != end) {
        for (auto it = start + 1; it != end; it++) {
            area += (*it + *(it - 1)) / 2.;
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

/**
 * https://en.wikipedia.org/wiki/Euler%E2%80%93Rodrigues_formula
 *
 def rotation_matrix(axis, theta):
    """
    Return the rotation matrix associated with counterclockwise rotation about
    the given axis by theta radians.
    """
    axis = np.asarray(axis)
    axis = axis/math.sqrt(np.dot(axis, axis))
    a = math.cos(theta/2.0)
    b, c, d = -axis*math.sin(theta/2.0)
    aa, bb, cc, dd = a*a, b*b, c*c, d*d
    bc, ad, ac, ab, bd, cd = b*c, a*d, a*c, a*b, b*d, c*d
    return np.array([[aa+bb-cc-dd, 2*(bc+ad), 2*(bd-ac)],
                     [2*(bc-ad), aa+cc-bb-dd, 2*(cd+ab)],
                     [2*(bd+ac), 2*(cd-ab), aa+dd-bb-cc]])

 */
Mat getRotationMatrixFromAxisAndAngle(Mat axis, float theta)
{
    assert(axis.cols == 3);
    assert(axis.rows == 1);
    Mat normalized_axis = axis / sqrtf(axis.dot(axis));
    float a = cosf(theta/2.0f);
    float sintheta2 = sinf(theta/2.0f);

    float b = -(normalized_axis.at<float>(0)) * sintheta2;
    float c = -(normalized_axis.at<float>(1)) * sintheta2;
    float d = -(normalized_axis.at<float>(2)) * sintheta2;

    float aa = a*a;
    float bb = b*b;
    float cc = c*c;
    float dd = d*d;

    float bc = b*c;
    float ad = a*d;
    float ac = a*c;
    float ab = a*b;
    float bd = b*d;
    float cd = c*d;

    return (Mat_<float>(3, 3) <<
        aa+bb-cc-dd, 2*(bc+ad), 2*(bd-ac),
        2*(bc-ad), aa+cc-bb-dd, 2*(cd+ab),
        2*(bd+ac), 2*(cd-ab), aa+dd-bb-cc)
    ;
}

Mat getRotationMatrixFromTwoVectors(Mat from, Mat to)
{
    assert(from.cols == to.cols && from.cols == 3);
    assert(from.rows == to.rows && from.rows == 1);

    // Cross product gives a vector normal to the plane defined
    // by the two vectors
    Mat axis = from.cross(to);

    // Angle between the two vectors
    // Recall: a <dot> b = |a| * |b| * cos(theta)
    float theta = acosf(from.dot(to) / (norm(from) * norm(to)));

    // Rotation matrix representing the rotation `theta` about the axis `axis`
    return getRotationMatrixFromAxisAndAngle(axis, theta);
}
