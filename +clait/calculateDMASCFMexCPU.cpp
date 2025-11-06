// DMAS-CF CPU implementation. 
//
// Arguments: Signals [(samples * channels), type double]
//            Delay matrix [(directions * channels), type double]           
//            DMAS order [type int32, 0/1=DAS | 2=DMAS | 3=DMAS3 | 4=DMAS4 | 5=DMAS5]
//            Toggle CF [type int32, 0=disabled | 1=enabled]
//
// Compile with 'mex calculateDMASCFMexCPU.cpp'
// Requires a C compiler. See README.md for more details.
// Make sure to correctly set c++ compiler with 'mex -setup c++' and clicking on the link of the version you want if asked.
// 
// By Cosys-Lab, University of Antwerp
// Contributors: Wouter Jansen, Jan Steckel, Edwin Walsh
#include "math.h"
#include "mex.h"
#include <cmath>
#include <numeric>
#include <algorithm>

#define DATASIG_2D( a, b ) data_SIG[ ( a ) + ( b ) * n_sps ]
#define DATABF_2D( c, d ) data_BF[ ( c ) + ( d ) * n_sps_BF ]
#define DELAYS_2D( e, f ) delay_Int_mat[ ( e ) + ( f ) * n_azel ]

void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[] )
{
    // Declarations
    double *data_SIG, *data_BF;    
    double * delay_Int_mat;       
    int n_sps, n_chans, n_azel, n_sps_BF;
    int azel_cnt, chan_cnt, spl_cnt;    
    int max_delay = 0;
    int cur_delay;
    int chan_offset = 0;
    int BF_offset = 0;  

    // Get matrix with signal data:
    data_SIG = mxGetPr( prhs[0] );
    n_chans = mxGetN( prhs[0] ); 
    n_sps = mxGetM( prhs[0] );   
    
    // Get the matrix with the sample delays
    delay_Int_mat = mxGetPr( prhs[1] );
    n_azel = mxGetM( prhs[1] ); 

    // Get DMAS order 
    if (mxGetClassID(prhs[2]) != mxINT32_CLASS || mxGetNumberOfElements(prhs[2]) != 1) {
        mexErrMsgIdAndTxt("DMAS_CF_CPU:InvalidInput", "DMAS order must be a scalar int32.");
    }
    int dmasOrder = *((int32_T *)mxGetData(prhs[2]));

    // Get Toggle CF
    if (mxGetClassID(prhs[3]) != mxINT32_CLASS || mxGetNumberOfElements(prhs[3]) != 1) {
        mexErrMsgIdAndTxt("DMAS_CF_CPU:InvalidInput", "CF toggle must be a scalar int32.");
    }
    int cfToggle = *((int32_T *)mxGetData(prhs[3]));
    bool cfToggleBool = (cfToggle == 1);

    // Find the maximum of the delay matrix
    for( int cnt = 0; cnt < n_chans * n_azel; cnt ++ ){
        if( delay_Int_mat[ cnt ] > max_delay ){
            max_delay = (int) delay_Int_mat[ cnt ];
        }
    }    
    n_sps_BF = n_sps + max_delay * 4;
	int sampleSize = n_sps - 2 * max_delay;

    // mexPrintf("microphones:%i directions:%i samples:%i output size:%i sample size:%i dmas order:%i cf toggle:%i\n", 
    //            n_chans, n_azel, n_sps, n_sps_BF, sampleSize, dmasOrder, cfToggle);

    // Allocate memory and assign output pointer
    plhs[0] = mxCreateDoubleMatrix( n_sps_BF , n_azel, mxREAL );
    
    //Get a pointer to the data space in our newly allocated memory
    data_BF = mxGetPr( plhs[0] );  

    // Beamforming
    for( azel_cnt = 0; azel_cnt < n_azel; azel_cnt++ ){
        
        // Zero-initialize the full output
        for( spl_cnt = 0; spl_cnt < n_sps_BF ; spl_cnt++ ){
            DATABF_2D( spl_cnt, azel_cnt ) = 0.0;
        }
        if(dmasOrder == 0 && cfToggle == 0){
            BF_offset = azel_cnt * n_sps_BF; 
            for( chan_cnt = 0; chan_cnt < n_chans; chan_cnt++ ){
                cur_delay = (int) DELAYS_2D( azel_cnt, chan_cnt );
                chan_offset = chan_cnt * n_sps;
                
                // Now, add all the other channels
                for( spl_cnt = 0; spl_cnt < ( n_sps - 2 * max_delay ) ; spl_cnt++ ){
                    data_BF[ spl_cnt +  BF_offset ] += data_SIG[ spl_cnt + cur_delay + chan_offset ];
                }
            }
        }
        else {
            // New DMAS-CF implementation (or DAS with CF).
            if(dmasOrder == 0 && cfToggle == 1) mexPrintf("Old DAS beamformer does not support CF, using new beamformer!\n");
            
            // --- Per-Sample DMAS/CF Calculation Loop ---
            for( spl_cnt = 0; spl_cnt < sampleSize ; spl_cnt++ ){
                
                // Temporary sums for DMAS and CF calculation for this (azel, spl) point
                double S1_raw_sum = 0.0;     // Sum of x_m
                double S_raw_sq_sum = 0.0;   // Sum of x_m^2
                double S_abs_sum = 0.0;
                double S2_sum_signed_root = 0.0;
                double S3_sum_signed_root = 0.0;
                double S4_sum_signed_root = 0.0;
                double S5_sum_signed_root = 0.0;

                double S3_cubed_sum = 0.0;
                double S3_squared_sum = 0.0;
                double S4_quad_sum = 0.0;
                double S4_cubed_sum = 0.0;
                double S4_squared_sum = 0.0;
                double S5_quint_sum = 0.0;
                double S5_quad_sum = 0.0;
                double S5_cubed_sum = 0.0;
                double S5_squared_sum = 0.0;

                // Gather samples for all channels at the current (spl_cnt, azel_cnt)
                for( chan_cnt = 0; chan_cnt < n_chans; chan_cnt++ ){
                    cur_delay = (int) DELAYS_2D( azel_cnt, chan_cnt );
                    
                    // Get the delayed sample x
                    double x = DATASIG_2D( spl_cnt + cur_delay, chan_cnt );
                    
                    S1_raw_sum += x;
                    S_raw_sq_sum += x * x;

                    if (dmasOrder >= 2) {
                        double s2 = copysign(1.0, x) * pow(fabs(x), 1.0 / 2.0);
                        S2_sum_signed_root += s2;
                        S_abs_sum += fabs(x);
                    }

                    if (dmasOrder >= 3) {
                        double s3 = copysign(1.0, x) * pow(fabs(x), 1.0 / 3.0);
                        S3_sum_signed_root += s3;
                        S3_cubed_sum += pow(s3, 3.0);
                        S3_squared_sum += pow(s3, 2.0);
                    }
                    
                    if (dmasOrder >= 4) {
                        double s4 = copysign(1.0, x) * pow(fabs(x), 1.0 / 4.0);
                        S4_sum_signed_root += s4;
                        S4_quad_sum += pow(s4, 4.0);
                        S4_cubed_sum += pow(s4, 3.0);
                        S4_squared_sum += pow(s4, 2.0);
                    }

                    if (dmasOrder >= 5) {
                        double s5 = copysign(1.0, x) * pow(fabs(x), 1.0 / 5.0);
                        S5_sum_signed_root += s5;
                        S5_quint_sum += pow(s5, 5.0);
                        S5_quad_sum += pow(s5, 4.0);
                        S5_cubed_sum += pow(s5, 3.0);
                        S5_squared_sum += pow(s5, 2.0);
                    }
                } // end chan_cnt loop
                
                // --- DMAS Output Calculation ---
                double dmasOut = 0.0;
                
                switch (dmasOrder) {
                    case 0: // Fallback for order 0 when CF is ON
                    case 1: 
                        dmasOut = S1_raw_sum; // DAS (Delay-and-Sum)
                        break;
                        
                    case 2: // DMAS2
                        dmasOut = 0.5 * (pow(S2_sum_signed_root, 2.0) - S_abs_sum);
                        break;
                    
                    case 3: // DMAS3
                        dmasOut = 1.0 / 6.0 * (pow(S3_sum_signed_root, 3.0) + 2.0 * S3_cubed_sum - 3.0 * S3_sum_signed_root * S3_squared_sum);
                        break;
                        
                    case 4: // DMAS4
                        dmasOut = 1.0 / 24.0 * (
                            pow(S4_sum_signed_root, 4.0)
                            - 6.0 * S4_quad_sum
                            + 3.0 * pow(S4_squared_sum, 2.0)
                            - 6.0 * S4_squared_sum * pow(S4_sum_signed_root, 2.0)
                            + 8.0 * S4_cubed_sum * S4_sum_signed_root
                        );
                        break;
                        
                    case 5: // DMAS5
                        dmasOut = 1.0 / 120.0 * (
                            pow(S5_sum_signed_root, 5.0)
                            + 24.0 * S5_quint_sum
                            - 30.0 * S5_sum_signed_root * S5_quad_sum
                            + 20.0 * S5_cubed_sum * pow(S5_sum_signed_root, 2.0)
                            - 20.0 * S5_cubed_sum * S5_squared_sum
                            + 15.0 * pow(S5_squared_sum, 2.0) * S5_sum_signed_root
                            - 10.0 * S5_squared_sum * pow(S5_sum_signed_root, 3.0)
                        );
                        break;

                    default:
                        // If dmasOrder is something unexpected, default to DAS (Order 1)
                        dmasOut = S1_raw_sum;
                        break;
                }

                // --- Coherence Factor (CF) Weighting ---
                if (cfToggleBool) {
                    double numerator = pow(S1_raw_sum, 2.0);
                    double denominator = (double)n_chans * S_raw_sq_sum;
                    const double eps = 1e-6; // Epsilon for stability
                    double cf = numerator / (denominator + eps);
                    dmasOut *= cf;
                }

                // The final output is the absolute value of the DMAS result
                DATABF_2D( spl_cnt, azel_cnt ) = fabs(dmasOut);
                
            } // end spl_cnt loop
        } // end if/else for DMAS/DAS choice
    } // end azel_cnt loop
}