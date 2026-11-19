function dmasOut = calculateDMASCFNativeSingleDirection(dataMatrix, delayVector, gainSet, orderProcessing, coherenceType, rootMatrix)
%CALCULATEDMASCFNATIVESINGLEDIRECTION Single direction beamforming using D(M)AS and coherence factors.
%
%   dmasOut = CALCULATEDMASCFNATIVESINGLEDIRECTION(dataMatrix, delayVector,
%             gainSet, orderProcessing, coherenceType, rootMatrix)
%   Computes a single direction using various beamforming algorithms (DAS, DMAS) with optional
%   Coherence Factor (CF) application, leveraging native MATLAB functions.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Jan Steckel, Wouter Jansen
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
%   rootMatrix       : Optional. Signed roots of dataMatrix,
%                      sign(dataMatrix) .* abs(dataMatrix).^(1/orderProcessing).
%                      Pass it when beamforming many directions so the roots
%                      are computed once instead of once per direction.
%                      Computed here when omitted. Not used for DAS.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   dmasOut          : The computed beamformed sonar image vector.
%                      Dimensions: (samples * 1).

    if nargin < 5
        coherenceType = 'none';
    end
    if ~ismember(orderProcessing, 1:5)
        error( 'Wrong DMAS Order');
    end
    useRoots = orderProcessing >= 2;
    if useRoots && (nargin < 6 || isempty(rootMatrix))
        rootMatrix = sign(dataMatrix) .* abs(dataMatrix).^(1/orderProcessing);
    end

    % Apply delays & gains
    [maxDelay, ~] = max(delayVector);
    [numSamples, numChannels] = size(dataMatrix);
    numOutput = numSamples - maxDelay;

    dataMatrixDel = zeros(numOutput, numChannels);
    rootMatrixDel = zeros(numOutput, numChannels * useRoots);

    for ch = 1:numChannels
        rows = (1 + delayVector(ch)) : (numOutput + delayVector(ch));
        dataMatrixDel(:, ch) = dataMatrix(rows, ch) * gainSet(ch);
        if useRoots
            % Root of the scaled signal: sgn(g*x)|g*x|^(1/n) = sgn(g)|g|^(1/n) * sgn(x)|x|^(1/n)
            rootMatrixDel(:, ch) = rootMatrix(rows, ch) * (sign(gainSet(ch)) * abs(gainSet(ch))^(1/orderProcessing));
        end
    end

    % Newton-Girard identities on the power sums P_k = sum(s.^k) of the signed
    % roots s (paper Eq. 9-12). The highest power sum needs no roots:
    % P_n = sum(x) for odd n and P_n = sum(|x|) for even n.
    S = rootMatrixDel;
    switch orderProcessing
        case 1
            % Simple Delay and Sum
            dmasOut = sum(dataMatrixDel, 2);
        case 2
            P1 = sum(S, 2);
            dmasOut = 1/2 * ( P1.^2 - sum(abs(dataMatrixDel), 2) );
        case 3
            P1 = sum(S, 2);
            P2 = sum(S.^2, 2);
            dmasOut = 1/6 * ( P1.^3 + 2*sum(dataMatrixDel, 2) - 3*P1.*P2 );
        case 4
            S2 = S.^2;
            P1 = sum(S, 2);
            P2 = sum(S2, 2);
            P3 = sum(S2.*S, 2);
            dmasOut = 1/24 * ( P1.^4 - 6*sum(abs(dataMatrixDel), 2) + 3*P2.^2 - 6*P2.*P1.^2 + 8*P3.*P1 );
        case 5
            S2 = S.^2;
            P1 = sum(S, 2);
            P2 = sum(S2, 2);
            P3 = sum(S2.*S, 2);
            P4 = sum(S2.^2, 2);
            dmasOut = 1/120 * ( P1.^5 + 24*sum(dataMatrixDel, 2) - 30*P1.*P4 + 20*P3.*P1.^2 - 20*P3.*P2 + 15*P2.^2.*P1 - 10*P2.*P1.^3 );
    end

    % Apply coherence factor if requested
    switch lower(coherenceType)
        case 'none'
            % do nothing

        case 'cf'
            dataMatrixDelAnalytical = hilbert(dataMatrixDel);
            numerator   = abs( sum( dataMatrixDelAnalytical, 2 ) ).^2;
            denominator = numChannels * sum( abs( dataMatrixDelAnalytical ).^2, 2 );
            cf = numerator ./ ( denominator + eps );
            dmasOut = dmasOut .* cf;

        case 'pcf'
            % Phase Coherence Factor
            dataMatrixDelAnalytical = hilbert(dataMatrixDel);
            phaseTerms = exp( 1j * angle( dataMatrixDelAnalytical ) );
            pcf = abs( sum( phaseTerms, 2 ) ) / numChannels;
            dmasOut = dmasOut .* pcf;

        case 'scf'
            % Sign Coherence Factor
            signTerms = sign( dataMatrixDel );
            scf = abs( sum( signTerms, 2 ) ) / numChannels;
            dmasOut = dmasOut .* scf;

        otherwise
            error( 'Unknown coherenceType: %s', coherenceType );
    end
end
