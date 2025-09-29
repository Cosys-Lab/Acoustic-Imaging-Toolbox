function dmasOut = calculateDMASCFNativeSingleDirection(dataMatrix, delayVector, gainSet, orderProcessing, coherenceType)
%CALCULATEDMASCFNATIVESINGLEDIRECTION Single direction beamforming using D(M)AS and coherence factors.
%
%   dmasOut = CALCULATEDMASCFNATIVESINGLEDIRECTION(dataMatrix, delayVector,
%             gainSet, orderProcessing, coherenceType) 
%   Computes a single direction using various beamforming algorithms (DAS, DMAS) with optional
%   Coherence Factor (CF) application, leveraging native MATLAB functions.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   dataMatrix       : Received signal data. 
%                      Dimensions: (samples * channels).
%
%   delayVector      : Delay indices for beamforming. 
%                      Dimensions: (1 * channels). Integers.
%
%   gainSet          : Optional gain set for the specific channel.
%                      Dimensions: (1 * channels).
%
%   orderProcessing  : String specifying the beamforming algorithm.
%                      Options: 1=DAS, 2=DMAS, 3=DMAS3, 4=DMAS4, 5=DMAS5
%
%   coherenceType    : String specifying the Coherence Factor type.
%                      Options: 'none', 'cf' (default), 'pcf', 'scf'.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   dmasOut          : The computed beamformed sonar image vector.
%                      Dimensions: (samples * 1).

    if nargin < 5
        coherenceType = 'none';
    end

    % Apply delays & gains
    [maxDelay, ~] = max(delayVector);
    [numSamples, numChannels] = size(dataMatrix);  
 
    dataMatrixDel = zeros(numSamples - maxDelay, numChannels);

    for ch = 1:numChannels
        dataMatrixDel(:, ch) = dataMatrix( ...
            (1 + delayVector(ch)) : (numSamples - maxDelay + delayVector(ch)), ch ) ...
            * gainSet(ch);
    end  

    % Precompute power sums S_p across channels
    S1 = sum( dataMatrixDel, 2 );  
    S2 = sign(dataMatrixDel) .* ( abs( dataMatrixDel ).^(1/2) );
    S3 = sign(dataMatrixDel) .* ( abs( dataMatrixDel ).^(1/3) );
    S4 = sign(dataMatrixDel) .* ( abs( dataMatrixDel ).^(1/4) );
    S5 = sign(dataMatrixDel) .* ( abs( dataMatrixDel ).^(1/5) );

    
    % Select method
    switch orderProcessing
        case 1
            % Simple Delay and Sum
            dmasOut = S1;                      
        case 2
            dmasOut = 1/2 * ( abs(sum(S2,2)).^2 - sum(S2.^2,2) );       
        case 3
            dmasOut = 1/6 * ( sum(S3,2).^3 + 2 * sum(S3.^3,2) - 3*sum(S3,2).*sum(S3.^2,2) );
        case 4
            dmasOut = 1/24 * ( sum(S4,2).^4 - 6*sum(S4.^4,2) + 3*( sum(S4.^2,2).^2 ) - 6*sum(S4.^2,2).*(sum(S4,2).^2) + 8*sum(S4.^3,2).*sum(S4,2) );
        case 5
            dmasOut = 1/120 * ( sum(S5,2).^5 + 24*sum(S5.^5,2) - 30*sum(S5,2).*sum(S5.^4,2) + 20*sum(S5.^3,2).*( sum(S5,2).^2 ) - 20*sum(S5.^3,2).*sum(S5.^2,2) + 15*( sum(S5.^2,2).^2 ).*sum(S5,2) - 10*sum(S5.^2,2).*( sum(S5,2).^3 ) );
        otherwise
            error( 'Wrong DMAS Order');
    end
    
    % Apply coherence factor if requested
    dataMatrixDelAnalytical = hilbert(dataMatrixDel);
    switch lower(coherenceType)
        case 'none'
            % do nothing

        case 'cf'
            numerator   = abs( sum( dataMatrixDelAnalytical, 2 ) ).^2;
            denominator = numChannels * sum( abs( dataMatrixDelAnalytical ).^2, 2 );
            cf = numerator ./ ( denominator + eps );
            dmasOut = dmasOut .* cf;

        case 'pcf'
            % Phase Coherence Factor
            phaseTerms = exp( 1j * angle( dataMatrixDelAnalytical ) );
            pcf = abs( sum( phaseTerms, 2 ) ) / numChannels;
            dmasOut = dmasOut .* pcf;

        case 'scf'
            % Sign Coherence Factor
            signTerms = sign( real( dataMatrixDelAnalytical ) );
            scf = abs( sum( signTerms, 2 ) ) / numChannels;
            dmasOut = dmasOut .* scf;

        otherwise
            error( 'Unknown coherenceType: %s', coherenceType );
    end
end