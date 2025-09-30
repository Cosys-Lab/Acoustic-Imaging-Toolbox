function [structEnergyscape] = generate2DEnergyscape(dataMicrophones, structSensor, structEnergyscapeGeneration)
        
    structImage = struct();
    structImage.directionsAzimuth = -90:structEnergyscapeGeneration.azimuthResolution:90;
    structImage.directionsElevation = zeros(size( structImage.directionsAzimuth));
    structImage.numDirections = length(structImage.directionsAzimuth);
    structImage.lowpassFreq = structEnergyscapeGeneration.lowpassFreq;
    structImage.doEnvelope = structEnergyscapeGeneration.doEnvelope;
    structImage.doThresholdAtZero = 1;
    structImage.decimationFactor = structEnergyscapeGeneration.decimationFactor;
    structImage.matchedFilterMethod = structEnergyscapeGeneration.matchedFilterMethod;
    structImage.matchedFilterFreq = structEnergyscapeGeneration.matchedFilterFreq;
    structImage.doMatchedFilter = structEnergyscapeGeneration.doMatchedFilter;
    structImage.methodImaging = structEnergyscapeGeneration.methodImaging;
    structImage.coherenceType = structEnergyscapeGeneration.coherenceType;
    structImage.methodProcessing = structEnergyscapeGeneration.methodProcessing; 

    acousticImage = clait.calculateAcousticImage(dataMicrophones, structSensor, structImage);

    acousticImageFiltered = imgaussfilt(acousticImage, structEnergyscapeGeneration.filterSize);
    acousticImageFiltered = acousticImageFiltered - structEnergyscapeGeneration.sizeFactor * mean(acousticImageFiltered, 2);
    acousticImageFiltered(acousticImageFiltered < 0) = 0;

    splStart = round(structEnergyscapeGeneration.minRange * 2 / 343 * (structSensor.sampleRate / structEnergyscapeGeneration.decimationFactor)); 
    splStop = round(structEnergyscapeGeneration.maxRange * 2 / 343 * (structSensor.sampleRate / structEnergyscapeGeneration.decimationFactor));    
    acousticImageFilteredRangeSelected = acousticImageFiltered(splStart : splStop, :);
    ranges = structEnergyscapeGeneration.minRange:(structEnergyscapeGeneration.maxRange - structEnergyscapeGeneration.minRange) / ((splStop - splStart)):structEnergyscapeGeneration.maxRange;

    acousticImageTransformedLog = 20 * log10( acousticImageFilteredRangeSelected + 10^(structEnergyscapeGeneration.dbCut / 20)) - structEnergyscapeGeneration.dbCut;
    acousticImageTransformedLog = min(acousticImageTransformedLog, structEnergyscapeGeneration.dbMax);
    energyscapeTransformedLog = acousticImageTransformedLog / structEnergyscapeGeneration.dbMax;

    acousticImageFilteredRangeSelected = acousticImageFilteredRangeSelected .* (ranges.^2)';
    angleCompCurve = (1 + 3 * sin(abs(deg2rad(structImage.directionsAzimuth)))) .^4 ;
    angleCompCurve = angleCompCurve / max(angleCompCurve);
    angleCompCurve = angleCompCurve + 1;
    acousticImageFilteredRangeSelected = acousticImageFilteredRangeSelected .* angleCompCurve;
    acousticImageFilteredRangeSelected = tanh(structEnergyscapeGeneration.tanhFactor * acousticImageFilteredRangeSelected - 0.5) + 0.5;    
    energyscapeIntensity = ((acousticImageFilteredRangeSelected - min(acousticImageFilteredRangeSelected(:))).^0.15);

    structEnergyscape.intensity = energyscapeIntensity;
    structEnergyscape.transformedLog = energyscapeTransformedLog;
    structEnergyscape.acousticImage = acousticImage;
    structEnergyscape.acousticImageFilteredRangeSelected = acousticImageFilteredRangeSelected;
    structEnergyscape.ranges = ranges;
    structEnergyscape.directionsAzimuth = structImage.directionsAzimuth;
    structEnergyscape.dbMax = structEnergyscapeGeneration.dbMax;
end