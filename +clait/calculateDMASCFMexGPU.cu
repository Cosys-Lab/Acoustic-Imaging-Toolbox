/*
 * DMAS-CF using CUDA accelerated kernels. 
 *
 * Arguments: Signals [(samples * channels), type single]
 *            Delay matrix [(directions * channels), type int32]           
 *            DMAS order [type int32, 0/1=DAS | 2=DMAS | 3=DMAS3 | 4=DMAS4 | 5=DMAS5]
 *            Toggle CF [type int32, 0=disabled | 1=enabled]
 *
 * Compile with 'mexcuda -v calculateDMASCFMexGPU.cu' (-v for extra details for debugging)
 * Requires CUDA toolkit and a C compiler.
 * Make sure to correctly set c++ compiler with 'mex -setup c++' and clicking on the link of the version you want if asked.
 * And make sure to set the CUDA enviroment variable correctly with
 * 'setenv('MW_NVCC_PATH','/usr/local/cuda-X/bin')' on Linux
 * 'setenv('MW_NVCC_PATH','C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\vX\bin')' on Windows
 * 
 * By Cosys-Lab, University of Antwerp
 * Contributors: Wouter Jansen, Jan Steckel, Edwin Walsh
 */

#include "mex.h"
#include "gpu/mxGPUArray.h"
#include <string>     
        
/*
 * Old device code for GPU kernel to calculate DAS beamforming with atomic operations. Slower then DMAS kernel. 
 * This uses threads going over all 3 dimensions: directions, samples and microphones.
 */
void __global__ das_kernel(int const *delayMatrix, float const *dataSignals,float *dataBeamform,
     int nMicrophones, int nDirections, int nSamples, int outputSize, int sampleSize){
    int output_size_block = blockIdx.x * blockDim.x + threadIdx.x;
    int direction = blockIdx.y * blockDim.y + threadIdx.y;
    int microphone = blockIdx.z * blockDim.z + threadIdx.z;
    if(direction < nDirections && output_size_block < sampleSize && microphone < nMicrophones){
            atomicAdd(&dataBeamform[output_size_block + direction*outputSize], dataSignals[microphone*nSamples + delayMatrix[microphone*nDirections + direction] + output_size_block]);
    }
}

void __global__ dmascf_kernel(int const *delayMatrix, float const *dataSignals, float *dataBeamform,
     int nMicrophones, int nDirections, int nSamples, int outputSize, int dmasOrder, bool cfToggle) {

	int direction = blockIdx.y * blockDim.y + threadIdx.y;
	int output_index = blockIdx.x * blockDim.x + threadIdx.x;
	float S2_sum_signed_root = 0.0f;
	float S3_sum_signed_root = 0.0f;
	float S4_sum_signed_root = 0.0f;
	float S5_sum_signed_root = 0.0f;

	float S3_cubed_sum = 0.0f;
	float S3_squared_sum = 0.0f;
	float S4_quad_sum = 0.0f;
	float S4_cubed_sum = 0.0f;
	float S4_squared_sum = 0.0f;
	float S5_quint_sum = 0.0f;
	float S5_quad_sum = 0.0f;
	float S5_cubed_sum = 0.0f;
	float S5_squared_sum = 0.0f;

	float S1_raw_sum = 0.0f;
	float S_raw_sq_sum = 0.0f;
    float S_abs_sum = 0.0f;
    
	
	for (int microphone = 0; microphone < nMicrophones; ++microphone) {
		int delay = delayMatrix[microphone * nDirections + direction];
		int sample_address = microphone * nSamples + (output_index + delay);
		float x = dataSignals[sample_address];

		S1_raw_sum += x;
    	S_raw_sq_sum += x * x;

		if (dmasOrder >= 2) {
			float s2 = copysignf(1.0f, x) * powf(fabsf(x), 1.0f / 2.0f);
			S2_sum_signed_root += s2;
            S_abs_sum += fabsf(x);
		}

		if (dmasOrder >= 3) {
			float s3 = copysignf(1.0f, x) * powf(fabsf(x), 1.0f / 3.0f);
			S3_sum_signed_root += s3;
			S3_cubed_sum += powf(s3, 3.0f);
			S3_squared_sum += powf(s3, 2.0f);
		}
		
		if (dmasOrder >= 4) {
			float s4 = copysignf(1.0f, x) * powf(fabsf(x), 1.0f / 4.0f);
			S4_sum_signed_root += s4;
			S4_quad_sum += powf(s4, 4.0f);
			S4_cubed_sum += powf(s4, 3.0f);
			S4_squared_sum += powf(s4, 2.0f);
		}

		if (dmasOrder >= 5) {
			float s5 = copysignf(1.0f, x) * powf(fabsf(x), 1.0f / 5.0f);
			S5_sum_signed_root += s5;
			S5_quint_sum += powf(s5, 5.0f);
			S5_quad_sum += powf(s5, 4.0f);
			S5_cubed_sum += powf(s5, 3.0f);
			S5_squared_sum += powf(s5, 2.0f);
		}
	}
	
	float dmasOut = 0.0f;
	
	switch (dmasOrder) {
		case 1: 
			dmasOut = S1_raw_sum;
			break;
			
		case 2:
			dmasOut = 0.5f * (powf(S2_sum_signed_root, 2.0f) - S_abs_sum);
			break;
		
		case 3: 
			dmasOut = 1.0f / 6.0f * (powf(S3_sum_signed_root, 3.0f) + 2.0f * S3_cubed_sum - 3.0f * S3_sum_signed_root * S3_squared_sum);
			break;
			
		case 4:
			dmasOut = 1.0f / 24.0f * (
				powf(S4_sum_signed_root, 4.0f)
				- 6.0f * S4_quad_sum
				+ 3.0f * powf(S4_squared_sum, 2.0f)
				- 6.0f * S4_squared_sum * powf(S4_sum_signed_root, 2.0f)
				+ 8.0f * S4_cubed_sum * S4_sum_signed_root
			);
			break;
			
		case 5:
			dmasOut = 1.0f / 120.0f * (
				powf(S5_sum_signed_root, 5.0f)
				+ 24.0f * S5_quint_sum
				- 30.0f * S5_sum_signed_root * S5_quad_sum
				+ 20.0f * S5_cubed_sum * powf(S5_sum_signed_root, 2.0f)
				- 20.0f * S5_cubed_sum * S5_squared_sum
				+ 15.0f * powf(S5_squared_sum, 2.0f) * S5_sum_signed_root
				- 10.0f * S5_squared_sum * powf(S5_sum_signed_root, 3.0f)
			);
			break;
	}

	if (cfToggle) {
		float numerator = powf(S1_raw_sum, 2.0f);
		float denominator = (float)nMicrophones * S_raw_sq_sum;
		const float eps = 1e-6f;
		float cf = numerator / (denominator + eps);
		dmasOut *= cf;
	}

	dataBeamform[direction * outputSize + output_index] = fabsf(dmasOut);
}

/*
 * Host code for CPU
 */
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] )
{
    /* Declare all variables.*/
    mxGPUArray const *dataSignals;
    mxGPUArray const *delayMatrix;
    int * delayMatrixCPU;
    mxGPUArray *dataBeamForm;
    float const *d_dataSignals;
    int const *d_delayMatrix;
    float *d_dataBeamForm;
    int nMicrophones;
    int nDirections;
    int nSamples;
    int outputSize;
    int sampleSize;
    int maxDelay = 0;

    /* Initialize the MathWorks GPU API. */
    mxInitGPU();

    /* Throw an error if the input are not a CPU arrays. */
    if ((mxIsGPUArray(prhs[0])) || (mxIsGPUArray(prhs[1]))) {
        mexErrMsgIdAndTxt("parallel:gpu:mexGPUExample:InvalidInput", "The input matrices have to be normal CPU arrays, not GPUArrays.\n");
    }

    /* Throw an error if the input are not the correct datatype. */
    if (mxGetClassID(prhs[0]) != mxSINGLE_CLASS) {
        mexErrMsgIdAndTxt("parallel:gpu:mexGPUExample:InvalidInput", "The signal data matrix has to be of datatype 'single'.\n");
    }
    if (mxGetClassID (prhs[1]) !=  mxINT32_CLASS) {
        mexErrMsgIdAndTxt("parallel:gpu:mexGPUExample:InvalidInput", "The delay matrix has to be of datatype 'int32'.\n");
    }

    if (mxGetClassID (prhs[2]) !=  mxINT32_CLASS) {
        mexErrMsgIdAndTxt("parallel:gpu:mexGPUExample:InvalidInput", "The DMAS order has to be of datatype 'int32'.\n");
    }

    if (mxGetClassID (prhs[3]) !=  mxINT32_CLASS) {
        mexErrMsgIdAndTxt("parallel:gpu:mexGPUExample:InvalidInput", "The CF toggle has to be of datatype 'int32'.\n");
    }

    dataSignals = mxGPUCreateFromMxArray(prhs[0]);
    delayMatrix = mxGPUCreateFromMxArray(prhs[1]);
    delayMatrixCPU = (int *)mxGetData(prhs[1]);
    int dmasOrder = *((int32_T *)mxGetData(prhs[2]));
    int cfToggle = *((int32_T *)mxGetData(prhs[3]));

    nMicrophones = mxGPUGetDimensions(dataSignals)[1];
    nSamples = mxGPUGetDimensions(dataSignals)[0];
    nDirections = mxGPUGetDimensions(delayMatrix)[0];

    /* Extract a pointer to the input data on the device. */
    d_dataSignals = (float const *)(mxGPUGetDataReadOnly(dataSignals));
    d_delayMatrix = (int const *)(mxGPUGetDataReadOnly(delayMatrix));

    /* Calculate the maximum delay and set the output size. */
    for( int cnt = 0; cnt < nMicrophones * nDirections; cnt ++ ){
        if(delayMatrixCPU[cnt] > maxDelay){
            maxDelay = delayMatrixCPU[cnt];
        }
    }
    outputSize = nSamples + maxDelay * 4;
    sampleSize = nSamples - 2 * maxDelay;

    // printf("microphones:%i directions:%i samples:%i output size:%i sample size:%i dmas order:%i cf toggle:%i\n",nMicrophones, nDirections, nSamples, outputSize, sampleSize, dmasOrder, cfToggle);

    /* Create a GPUArray to hold the result and get its underlying pointer. */
    mwSize dims[2] = {outputSize, nDirections};
    dataBeamForm = mxGPUCreateGPUArray(mxGPUGetNumberOfDimensions(dataSignals),
                            dims,
                            mxGPUGetClassID(dataSignals),
                            mxGPUGetComplexity(dataSignals),
                            MX_GPU_INITIALIZE_VALUES);
    d_dataBeamForm = (float *)(mxGPUGetData(dataBeamForm));

    /* Execute the beamform kernel. */
    if(dmasOrder == 0 && !cfToggle){
        dim3 threadsPerBlock(32, 8, 4);
        dim3 numBlocks(ceil(sampleSize / (threadsPerBlock.x*1.0)), ceil(nDirections / (threadsPerBlock.y*1.0)), ceil(nMicrophones / (threadsPerBlock.z*1.0)));
        das_kernel<<<numBlocks, threadsPerBlock>>>(d_delayMatrix, d_dataSignals, d_dataBeamForm , nMicrophones, nDirections, nSamples, outputSize, sampleSize);
    }{
        if(dmasOrder == 0 && cfToggle)printf("Old DAS beamformer does not support CF, using new beamformer!\n");
        dim3 threadsPerBlock(64, 4);
        dim3 numBlocks(ceil(outputSize / (threadsPerBlock.x*1.0)), ceil(nDirections / (threadsPerBlock.y*1.0)));
        dmascf_kernel<<<numBlocks, threadsPerBlock>>>(d_delayMatrix, d_dataSignals, d_dataBeamForm , nMicrophones, nDirections, nSamples, outputSize, dmasOrder, cfToggle);
    }

    /* Wrap the result up as a MATLAB gpuArray for return. */
    plhs[0] = mxGPUCreateMxArrayOnGPU(dataBeamForm);

    /*
     * The mxGPUArray pointers are host-side structures that refer to device
     * data. These must be destroyed before leaving the mex function.
     */
    mxGPUDestroyGPUArray(dataSignals);
    mxGPUDestroyGPUArray(delayMatrix);
    mxGPUDestroyGPUArray(dataBeamForm);
}
