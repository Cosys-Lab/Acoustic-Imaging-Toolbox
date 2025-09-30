function [energyscapePlotHandle, hCBarHandle] = plot2DEnergyscape(structEnergyscape, colorMapSize, cmap, gridColor, rangeSpacing, azimuthSpacing)
   
    azimuthSpacing = deg2rad(azimuthSpacing);
    ESColorized = round(structEnergyscape.transformedLog * (colorMapSize - 1)) + 1;   
    cdataES = cmap(ESColorized, :);
    cdataIntensified = cdataES.*repmat(structEnergyscape.intensity(:), 1, 3);
    energyscapeCData = reshape(cdataIntensified, [size(ESColorized), 3]);
    
    angleLimits = deg2rad(structEnergyscape.directionsAzimuth);
    rangeAzimuthSpacing = [angleLimits(1), (angleLimits(1)+mod(angleLimits(1), azimuthSpacing)):azimuthSpacing:angleLimits(end), angleLimits(end)];
    azimuthRangeSpacing = [structEnergyscape.ranges(1), (structEnergyscape.ranges(1)+mod(structEnergyscape.ranges(1), rangeSpacing)):rangeSpacing:structEnergyscape.ranges(end), structEnergyscape.ranges(end)];
    
    rangeRangeSpacing = structEnergyscape.ranges(1):0.01:structEnergyscape.ranges(end);
    azimuthAzimuthSpacing = angleLimits(1):deg2rad(1):angleLimits(end);
    
    [rangeAzimuthGrid, rangeRangeGrid] = meshgrid(rangeAzimuthSpacing, rangeRangeSpacing);
    [angleAzimuthGrid, angleRangeGrid] = meshgrid(azimuthAzimuthSpacing, azimuthRangeSpacing);
    rangeAzimuthTx = rangeRangeGrid .* cos(rangeAzimuthGrid);
    rangeAzimuthTy = rangeRangeGrid .* sin(rangeAzimuthGrid);
    angleAzimuthTx = angleRangeGrid .* cos(angleAzimuthGrid);
    angleAzimuthTy = angleRangeGrid .* sin(angleAzimuthGrid);
    
    [meshAz, meshRange ] = meshgrid(angleLimits, structEnergyscape.ranges);
    tx = meshRange .* cos(meshAz);
    ty = meshRange .* sin(meshAz);
    
    tickPositions = linspace(0,1, 8); % 5 ticks
    tickLabels = linspace( -structEnergyscape.dbMax, 0, 8);
    
    energyscapePlotHandle = pcolor( -ty, tx, energyscapeCData(:,:,1) );
    energyscapePlotHandle.CData = energyscapeCData;  
    
    hold on;
    set( energyscapePlotHandle, 'linestyle', 'none' );
    plot(rangeAzimuthTy, rangeAzimuthTx, 'linewidth', 0.5, 'Color', gridColor)
    plot(angleAzimuthTy.', angleAzimuthTx.', 'linewidth', 0.5, 'Color', gridColor)
    hold off;
    xlabel('Cross Range (m)')
    axis equal
    shading interp
    axis tight
    curPlot = gca();
    colormap(curPlot, cmap)
    clim([ 0 1] )
    hCBarHandle = colorbar;
    set(hCBarHandle, 'Ticks', tickPositions, 'TickLabels', tickLabels);
    hCBarHandle.Label.String = 'Intensity (dB)';

    curPlot.Color = 'w';
    curPlot.XColor = 'k';
    yticks([])
    axis tight
    box off;
    curPlot.YColor = 'w';
end

