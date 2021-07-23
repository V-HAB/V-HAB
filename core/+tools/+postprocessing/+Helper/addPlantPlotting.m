function addPlantPlotting(oPlotter, tPlotOptions, oSetup)

coPlotBiomasses = cell(0);
coPlotBiomasses{1,1} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.Biomass(:),             'Current Biomass',              tPlotOptions);
coPlotBiomasses{1,2} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.EdibleBiomassCum(:),    'Cumulative Edible Biomass',    tPlotOptions);
coPlotBiomasses{1,3} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.InedibleBiomassCum(:),  'Cumulative Inedible Biomass',	tPlotOptions);
coPlotBiomasses{2,1} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.EdibleBiomass(:),       'Current Edible Biomass',       tPlotOptions);
coPlotBiomasses{2,2} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.EdibleGrowthRate(:),  	'Current Edible Growth Rate',   tPlotOptions);
coPlotBiomasses{2,3} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.InedibleGrowthRate(:), 	'Current Inedible Growth Rate', tPlotOptions);

coPlotExchange = cell(0);
coPlotExchange{1,1} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.WaterUptakeRate(:),  	'Current Water Uptake',     	tPlotOptions);
coPlotExchange{1,2} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.TranspirationRate(:),  	'Current Transpiration',     	tPlotOptions);
coPlotExchange{1,3} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.OxygenRate(:),          'Current Oxygen Production',    tPlotOptions);
coPlotExchange{1,4} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.CO2Rate(:),             'Curent CO_2 Consumption',      tPlotOptions);
coPlotExchange{2,1} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.WaterUptake(:),         'Cumulative Water Uptake',      tPlotOptions);
coPlotExchange{2,2} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.Transpiration(:),      	'Cumulative Transpiration',     tPlotOptions);
coPlotExchange{2,3} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.Oxygen(:),              'Cumulative Oxygen',            tPlotOptions);
coPlotExchange{2,4} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.CO2(:),                 'Cumulative CO_2',              tPlotOptions);

coPlotNutrients = cell(0);
coPlotNutrients{1,1} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.NitrateStorageRate(:), 	'Current Storage Nitrate Uptake',	tPlotOptions);
coPlotNutrients{1,2} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.NitrateStructureRate(:),'Current Structure Nitrate Uptake', tPlotOptions);
coPlotNutrients{1,3} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.NitrateEdibleRate(:),	'Current Edible Nitrate Uptake',    tPlotOptions);
coPlotNutrients{2,1} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.NitrateStorage(:),  	'Cumulative Storage Nitrate',       tPlotOptions);
coPlotNutrients{2,2} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.Nitratestructure(:), 	'Cumulative Structure Nitrate',     tPlotOptions);
coPlotNutrients{2,3} = oPlotter.definePlot(oSetup.tiLogIndexes.Plants.NitrateEdible(:),     	'Cumulative Edible Nitrate',      	tPlotOptions);

oPlotter.defineFigure(coPlotBiomasses,       'Plant Biomass');

oPlotter.defineFigure(coPlotExchange,        'Plant Exchange Rates');

oPlotter.defineFigure(coPlotNutrients,       'Plant Nutrients');

end