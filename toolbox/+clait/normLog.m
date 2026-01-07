function [mat_out] = normLog(mat_in,threshDB)
%NORMLOG Normalizes a matrix and converts it to a logarithmic (dB) scale.
%
%   [mat_out] = NORMLOG(mat_in, threshDB) normalizes the input matrix `mat_in` 
%   to its global maximum, clips negative values to zero, and then converts 
%   the result to a logarithmic scale in decibels (dB), applying a threshold 
%   to prevent log(0) errors.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   mat_in      : The input matrix or array of any dimension.
%
%   threshDB    : A threshold value in decibels (dB). Values below this 
%                 threshold (relative to the maximum) will be clamped to 
%                 this value in the output. [1 x 1] (dB)
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   mat_out     : The normalized, thresholded, and log-scaled output matrix.
%                 Dimensions are the same as `mat_in`.
%
%   NOTES:
%   - The function normalizes the input matrix by dividing by its global maximum value.
%   - The `threshDB` value is converted to a linear scale and added to the 
%     matrix before the `log10` operation to handle values close to zero.
%   - Negative values in the input matrix are clipped to zero before log-scaling.
%
    
    thresh = 10^(threshDB/20);
    mat_out = mat_in / max(max(max(max(mat_in))));
    mat_out( mat_out < 0 ) = 0;
    mat_out = 20*log10( mat_out + thresh);
end