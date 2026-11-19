/*
 * DMAS-CF CUDA kernel. Shipped precompiled as calculateDMASCFKernel.ptx and launched
 * from MATLAB through parallel.gpu.CUDAKernel in calculateDMASCFCUDAKernel.m. Needs no
 * compiler on the user's machine, only an NVIDIA driver and Parallel Computing Toolbox.
 *
 * Regenerate the PTX after changing this file or calculateDMASCFCore.h
 * (done by the "ptx" task in buildfile.m):
 *   nvcc -ptx -arch=compute_50 calculateDMASCFKernel.cu -o calculateDMASCFKernel.ptx
 *
 * Kernel arguments: delay matrix [(directions * channels), int32]
 *                   signals [(samples * channels), single]
 *                   signed roots of the signals, sgn(x)*|x|^(1/order) [(samples * channels), single]
 *                     (computed once in MATLAB instead of once per direction; ignored for DAS)
 *                   output [(outputSize * directions), single, zero-initialized]
 *                   nMicrophones, nDirections, nSamples, outputSize, sampleSize,
 *                   dmasOrder [1=DAS | 2..5=DMAS2..5], cfToggle [0 | 1]
 * Only output rows 0..sampleSize-1 are written (sampleSize = nSamples - 2*maxDelay),
 * matching the CPU MEX implementation.
 *
 * By Cosys-Lab, University of Antwerp
 * Contributors: Wouter Jansen, Jan Steckel, Edwin Walsh
 */

#include "calculateDMASCFCore.h"

/* One thread computes one output pixel (sample, direction) by looping over the microphones. */
template <int ORDER, bool CF>
__device__ float dmasPixel(int const *delayMatrix, float const *dataSignals, float const *rootSignals,
    int nMicrophones, int nDirections, int nSamples, int direction, int outputIndex) {

	DmasSums<float> sums;
	dmasResetSums(sums);
	for (int microphone = 0; microphone < nMicrophones; ++microphone) {
		int address = microphone * nSamples + outputIndex + delayMatrix[microphone * nDirections + direction];
		float x = dataSignals[address];
		float s = (ORDER >= 2) ? rootSignals[address] : x;
		dmasAccumulate<ORDER, CF>(sums, x, s);
	}
	return dmasOutput<ORDER, CF>(sums, nMicrophones);
}

/* Select the specialized loop once per thread, outside the microphone loop. */
template <bool CF>
__device__ float dmasPixelForOrder(int dmasOrder, int const *delayMatrix, float const *dataSignals,
    float const *rootSignals, int nMicrophones, int nDirections, int nSamples, int direction, int outputIndex) {
	switch (dmasOrder) {
		case 2: return dmasPixel<2, CF>(delayMatrix, dataSignals, rootSignals, nMicrophones, nDirections, nSamples, direction, outputIndex);
		case 3: return dmasPixel<3, CF>(delayMatrix, dataSignals, rootSignals, nMicrophones, nDirections, nSamples, direction, outputIndex);
		case 4: return dmasPixel<4, CF>(delayMatrix, dataSignals, rootSignals, nMicrophones, nDirections, nSamples, direction, outputIndex);
		case 5: return dmasPixel<5, CF>(delayMatrix, dataSignals, rootSignals, nMicrophones, nDirections, nSamples, direction, outputIndex);
		default: return dmasPixel<1, CF>(delayMatrix, dataSignals, rootSignals, nMicrophones, nDirections, nSamples, direction, outputIndex);
	}
}

extern "C" __global__ void dmascf_kernel(int const *delayMatrix, float const *dataSignals, float const *rootSignals,
    float *dataBeamform, int nMicrophones, int nDirections, int nSamples, int outputSize, int sampleSize,
    int dmasOrder, int cfToggle) {

	int direction = blockIdx.y * blockDim.y + threadIdx.y;
	int outputIndex = blockIdx.x * blockDim.x + threadIdx.x;
	if (direction >= nDirections || outputIndex >= sampleSize) {
		return;
	}

	float value;
	if (cfToggle) {
		value = dmasPixelForOrder<true>(dmasOrder, delayMatrix, dataSignals, rootSignals, nMicrophones, nDirections, nSamples, direction, outputIndex);
	} else {
		value = dmasPixelForOrder<false>(dmasOrder, delayMatrix, dataSignals, rootSignals, nMicrophones, nDirections, nSamples, direction, outputIndex);
	}
	dataBeamform[direction * outputSize + outputIndex] = value;
}
