// DMAS-CF CPU implementation.
//
// Arguments: Signals [(samples * channels), type double]
//            Delay matrix [(directions * channels), type double]
//            DMAS order [type int32, 0/1=DAS | 2=DMAS | 3=DMAS3 | 4=DMAS4 | 5=DMAS5]
//            Toggle CF [type int32, 0=disabled | 1=enabled]
//
// Compile with clait.compileClaitMexFunctions() or 'mex calculateDMASCFMex.cpp' in this folder.
// Works with any compiler supported by MEX (e.g. the free MinGW-w64 add-on on Windows).
// Select one with 'mex -setup c++' and click the link of the version you want if asked.
// The DMAS formulas are shared with the CUDA kernel in calculateDMASCFCore.h.
//
// By Cosys-Lab, University of Antwerp
// Contributors: Wouter Jansen, Jan Steckel, Edwin Walsh
#include "mex.h"
#include "calculateDMASCFCore.h"
#include <cmath>
#include <vector>

// Signed n-th root sgn(x)*|x|^(1/n) (paper Eq. 4).
static double signedRoot(double x, int order)
{
    double a = std::fabs(x);
    double root;
    switch (order) {
        case 2:  root = std::sqrt(a); break;
        case 3:  root = std::cbrt(a); break;
        case 4:  root = std::sqrt(std::sqrt(a)); break;
        default: root = std::pow(a, 1.0 / order); break;
    }
    return std::copysign(root, x);
}

// Beamform all directions with a loop specialized for one DMAS order and CF setting.
template <int ORDER, bool CF>
static void beamform(const double *dataSignals, const double *rootSignals, const double *delayMatrix,
                     int nSamples, int nChannels, int nDirections, int sampleSize, int outputSize,
                     double *dataBeamform)
{
    std::vector<const double *> xColumns(nChannels);
    std::vector<const double *> sColumns(nChannels);

    for (int direction = 0; direction < nDirections; direction++) {
        // Look up the delays of this direction once, as pointers to the delayed channel starts.
        for (int channel = 0; channel < nChannels; channel++) {
            int offset = channel * nSamples + (int) delayMatrix[direction + channel * nDirections];
            xColumns[channel] = dataSignals + offset;
            sColumns[channel] = rootSignals + offset;
        }

        double *output = dataBeamform + (size_t) direction * outputSize;
        for (int sample = 0; sample < sampleSize; sample++) {
            DmasSums<double> sums;
            dmasResetSums(sums);
            for (int channel = 0; channel < nChannels; channel++) {
                double x = xColumns[channel][sample];
                double s = (ORDER >= 2) ? sColumns[channel][sample] : x;
                dmasAccumulate<ORDER, CF>(sums, x, s);
            }
            output[sample] = dmasOutput<ORDER, CF>(sums, nChannels);
        }
    }
}

template <bool CF>
static void beamformOrder(int order, const double *dataSignals, const double *rootSignals, const double *delayMatrix,
                          int nSamples, int nChannels, int nDirections, int sampleSize, int outputSize,
                          double *dataBeamform)
{
    switch (order) {
        case 2:  beamform<2, CF>(dataSignals, rootSignals, delayMatrix, nSamples, nChannels, nDirections, sampleSize, outputSize, dataBeamform); break;
        case 3:  beamform<3, CF>(dataSignals, rootSignals, delayMatrix, nSamples, nChannels, nDirections, sampleSize, outputSize, dataBeamform); break;
        case 4:  beamform<4, CF>(dataSignals, rootSignals, delayMatrix, nSamples, nChannels, nDirections, sampleSize, outputSize, dataBeamform); break;
        case 5:  beamform<5, CF>(dataSignals, rootSignals, delayMatrix, nSamples, nChannels, nDirections, sampleSize, outputSize, dataBeamform); break;
        default: beamform<1, CF>(dataSignals, rootSignals, delayMatrix, nSamples, nChannels, nDirections, sampleSize, outputSize, dataBeamform); break;
    }
}

void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] )
{
    if (nrhs != 4) {
        mexErrMsgIdAndTxt("DMAS_CF_CPU:InvalidInput", "Expected 4 inputs: signals, delay matrix, DMAS order, CF toggle.");
    }
    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0]) || !mxIsDouble(prhs[1]) || mxIsComplex(prhs[1])) {
        mexErrMsgIdAndTxt("DMAS_CF_CPU:InvalidInput", "Signals and delay matrix must be real double matrices.");
    }

    // Get matrix with signal data:
    const double *dataSignals = mxGetPr( prhs[0] );
    int nChannels = (int) mxGetN( prhs[0] );
    int nSamples = (int) mxGetM( prhs[0] );

    // Get the matrix with the sample delays
    const double *delayMatrix = mxGetPr( prhs[1] );
    int nDirections = (int) mxGetM( prhs[1] );

    // Get DMAS order
    if (mxGetClassID(prhs[2]) != mxINT32_CLASS || mxGetNumberOfElements(prhs[2]) != 1) {
        mexErrMsgIdAndTxt("DMAS_CF_CPU:InvalidInput", "DMAS order must be a scalar int32.");
    }
    int dmasOrder = *((int32_T *)mxGetData(prhs[2]));

    // Get Toggle CF
    if (mxGetClassID(prhs[3]) != mxINT32_CLASS || mxGetNumberOfElements(prhs[3]) != 1) {
        mexErrMsgIdAndTxt("DMAS_CF_CPU:InvalidInput", "CF toggle must be a scalar int32.");
    }
    bool cfToggle = (*((int32_T *)mxGetData(prhs[3])) == 1);

    // Find the maximum of the delay matrix
    int maxDelay = 0;
    for( size_t cnt = 0; cnt < (size_t) nChannels * nDirections; cnt ++ ){
        if( delayMatrix[ cnt ] > maxDelay ){
            maxDelay = (int) delayMatrix[ cnt ];
        }
    }
    int outputSize = nSamples + maxDelay * 4;
    int sampleSize = nSamples - 2 * maxDelay;

    // Allocate the output (zero-initialized by MATLAB). Only rows 0..sampleSize-1 are filled.
    plhs[0] = mxCreateDoubleMatrix( outputSize , nDirections, mxREAL );
    double *dataBeamform = mxGetPr( plhs[0] );
    if (sampleSize <= 0) {
        return;
    }

    // Signed roots sgn(x)*|x|^(1/n), computed once per sample instead of once per direction.
    std::vector<double> roots;
    const double *rootSignals = dataSignals;
    if (dmasOrder >= 2 && dmasOrder <= 5) {
        roots.resize((size_t) nSamples * nChannels);
        for (size_t i = 0; i < roots.size(); i++) {
            roots[i] = signedRoot(dataSignals[i], dmasOrder);
        }
        rootSignals = roots.data();
    }

    if (cfToggle) {
        beamformOrder<true>(dmasOrder, dataSignals, rootSignals, delayMatrix, nSamples, nChannels, nDirections, sampleSize, outputSize, dataBeamform);
    } else {
        beamformOrder<false>(dmasOrder, dataSignals, rootSignals, delayMatrix, nSamples, nChannels, nDirections, sampleSize, outputSize, dataBeamform);
    }
}
