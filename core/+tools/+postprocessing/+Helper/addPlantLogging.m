function addPlantLogging(oLogger, oSystem, oSetup)
%% Plant Logs
oSetup.tiPLantLogs = struct();

for iPlant = 1:length(oSystem.csPlants)
    oSetup.tiPLantLogs(iPlant).miMass                  = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miEdibleMass            = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miWaterUptake           = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miO2                    = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miCO2                   = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miTranspiration         = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miEdibleGrowth          = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miInedibleGrowth        = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miNO3UptakeStorage      = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miNO3UptakeStructure    = zeros(1:length(oSystem.miSubcultures(iPlant)),1);
    oSetup.tiPLantLogs(iPlant).miNO3UptakeEdible       = zeros(1:length(oSystem.miSubcultures(iPlant)),1);

    csMass                 = cell(1, length(oSystem.miSubcultures(iPlant)));
    csEdibleMass           = cell(1, length(oSystem.miSubcultures(iPlant)));
    csWaterUptake          = cell(1, length(oSystem.miSubcultures(iPlant)));
    csO2                   = cell(1, length(oSystem.miSubcultures(iPlant)));
    csCO2                  = cell(1, length(oSystem.miSubcultures(iPlant)));
    csTranspiration        = cell(1, length(oSystem.miSubcultures(iPlant)));
    csEdibleGrowth         = cell(1, length(oSystem.miSubcultures(iPlant)));
    csInedibleGrowth       = cell(1, length(oSystem.miSubcultures(iPlant)));
    csNO3UptakeStorage     = cell(1, length(oSystem.miSubcultures(iPlant)));
    csNO3UptakeStructure   = cell(1, length(oSystem.miSubcultures(iPlant)));
    csNO3UptakeEdible      = cell(1, length(oSystem.miSubcultures(iPlant)));

    for iSubculture = 1:oSystem.miSubcultures(iPlant)
        sCultureName = [oSystem.csPlants{iPlant},'_', num2str(iSubculture)];

        oSetup.tiPLantLogs(iPlant).miMass(iSubculture)                 = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName, '.toStores.Plant_Culture.toPhases.Plants'], 'fMass',                                   'kg',   [sCultureName, ' Mass']);
        oSetup.tiPLantLogs(iPlant).miEdibleMass(iSubculture)           = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName, '.toStores.Plant_Culture.toPhases.Plants'], ['this.afMass(this.oMT.tiN2I.', oSystem.csPlants{iPlant}, ')'],     'kg',   [sCultureName, ' Edible Biomass']);

        oSetup.tiPLantLogs(iPlant).miWaterUptake(iSubculture)          = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],                                            'fWaterConsumptionRate',                   'kg/s', [sCultureName, ' Water Consumption Rate']);

        oSetup.tiPLantLogs(iPlant).miO2(iSubculture)                   = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],  'this.tfGasExchangeRates.fO2ExchangeRate',            'kg/s', [sCultureName, ' O2 Rate']);
        oSetup.tiPLantLogs(iPlant).miCO2(iSubculture)                  = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],  'this.tfGasExchangeRates.fCO2ExchangeRate',           'kg/s', [sCultureName, ' CO2 Rate']);
        oSetup.tiPLantLogs(iPlant).miTranspiration(iSubculture)        = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],  'this.tfGasExchangeRates.fTranspirationRate',         'kg/s', [sCultureName, ' Transpiration Rate']);
        oSetup.tiPLantLogs(iPlant).miEdibleGrowth(iSubculture)         = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],  'this.tfBiomassGrowthRates.fGrowthRateEdible',        'kg/s', [sCultureName, ' Inedible Growth Rate']);
        oSetup.tiPLantLogs(iPlant).miInedibleGrowth(iSubculture)       = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],  'this.tfBiomassGrowthRates.fGrowthRateInedible',      'kg/s', [sCultureName, ' Edible Growth Rate']);

        oSetup.tiPLantLogs(iPlant).miNO3UptakeStorage(iSubculture)     = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],  'this.tfUptakeRate_Storage.NO3',                      'kg/s', [sCultureName, ' NO3 Uptake Storage']);
        oSetup.tiPLantLogs(iPlant).miNO3UptakeStructure(iSubculture)	 = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],  'this.tfUptakeRate_Structure.NO3',                	'kg/s', [sCultureName, ' NO3 Uptake Structure']);
        oSetup.tiPLantLogs(iPlant).miNO3UptakeEdible(iSubculture)      = oLogger.addValue([oSystem.sName, '.toChildren.', sCultureName],  'this.tfUptakeRate_Structure.fEdibleUptakeNO3',    	'kg/s', [sCultureName, ' NO3 Uptake Edible']);

        csMass{iSubculture}                 = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miMass(iSubculture)).sLabel,'" +'];
        csEdibleMass{iSubculture}           = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miEdibleMass(iSubculture)).sLabel,'" +'];
        csWaterUptake{iSubculture}          = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miWaterUptake(iSubculture)).sLabel,'" +'];
        csO2{iSubculture}                   = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miO2(iSubculture)).sLabel,'" +'];
        csCO2{iSubculture}                  = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miCO2(iSubculture)).sLabel,'" +'];
        csTranspiration{iSubculture}        = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miTranspiration(iSubculture)).sLabel,'" +'];
        csEdibleGrowth{iSubculture}         = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miEdibleGrowth(iSubculture)).sLabel,'" +'];
        csInedibleGrowth{iSubculture}       = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miInedibleGrowth(iSubculture)).sLabel,'" +'];
        csNO3UptakeStorage{iSubculture}     = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miNO3UptakeStorage(iSubculture)).sLabel,'" +'];
        csNO3UptakeStructure{iSubculture}   = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miNO3UptakeStructure(iSubculture)).sLabel,'" +'];
        csNO3UptakeEdible{iSubculture}      = ['"', oLogger.tLogValues(oSetup.tiPLantLogs(iPlant).miNO3UptakeEdible(iSubculture)).sLabel,'" +'];
    end

    sMass = strjoin(csMass);
    sMass(end) = [];
    oSetup.tiLogIndexes.Plants.Biomass{iPlant}            = oLogger.addVirtualValue( sMass,   'kg', [oSystem.csPlants{iPlant} ' current Biomass']);

    sEdibleMass = strjoin(csEdibleMass);
    sEdibleMass(end) = [];
    oSetup.tiLogIndexes.Plants.EdibleBiomass{iPlant}      = oLogger.addVirtualValue( sEdibleMass,   'kg', [oSystem.csPlants{iPlant} ' current Edible Biomass']);

    sWaterUptake = strjoin(csWaterUptake);
    sWaterUptake(end) = [];
    oSetup.tiLogIndexes.Plants.WaterUptakeRate{iPlant}    = oLogger.addVirtualValue( sWaterUptake,   'kg/s', [oSystem.csPlants{iPlant} ' Water Uptake']);
    oSetup.tiLogIndexes.Plants.WaterUptake{iPlant}        = oLogger.addVirtualValue(['cumsum((', sWaterUptake,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' Water Uptake Mass']);

    sO2 = strjoin(csO2);
    sO2(end) = [];
    oSetup.tiLogIndexes.Plants.OxygenRate{iPlant}         = oLogger.addVirtualValue( sO2,   'kg/s', [oSystem.csPlants{iPlant} ' O2 Exchange']);
    oSetup.tiLogIndexes.Plants.Oxygen{iPlant}             = oLogger.addVirtualValue(['cumsum((', sO2,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' O2 Exchange Mass']);

    sCO2 = strjoin(csCO2);
    sCO2(end) = [];
    oSetup.tiLogIndexes.Plants.CO2Rate{iPlant}            = oLogger.addVirtualValue( sCO2,   'kg/s', [oSystem.csPlants{iPlant} ' CO2 Exchange']);
    oSetup.tiLogIndexes.Plants.CO2{iPlant}                = oLogger.addVirtualValue(['cumsum((', sCO2,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' CO2 Exchange Mass']);

    sTranspiration = strjoin(csTranspiration);
    sTranspiration(end) = [];
    oSetup.tiLogIndexes.Plants.TranspirationRate{iPlant}  = oLogger.addVirtualValue( sTranspiration,   'kg/s', [oSystem.csPlants{iPlant} ' Transpiration']);
    oSetup.tiLogIndexes.Plants.Transpiration{iPlant}      = oLogger.addVirtualValue(['cumsum((', sTranspiration,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' Transpiration Mass']);

    sEdibleGrowth = strjoin(csEdibleGrowth);
    sEdibleGrowth(end) = [];
    oSetup.tiLogIndexes.Plants.EdibleGrowthRate{iPlant}   = oLogger.addVirtualValue( sEdibleGrowth,   'kg/s', [oSystem.csPlants{iPlant} ' Edible Growth']);
    oSetup.tiLogIndexes.Plants.EdibleBiomassCum{iPlant} 	= oLogger.addVirtualValue(['cumsum((', sEdibleGrowth,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' total Edible Mass']);

    sInedibleGrowth = strjoin(csInedibleGrowth);
    sInedibleGrowth(end) = [];
    oSetup.tiLogIndexes.Plants.InedibleGrowthRate{iPlant} = oLogger.addVirtualValue( sInedibleGrowth,   'kg/s', [oSystem.csPlants{iPlant} ' Inedible Growth']);
    oSetup.tiLogIndexes.Plants.InedibleBiomassCum{iPlant} = oLogger.addVirtualValue(['cumsum((', sInedibleGrowth,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' total Inedible Mass']);

    sNO3UptakeStorage = strjoin(csNO3UptakeStorage);
    sNO3UptakeStorage(end) = [];
    oSetup.tiLogIndexes.Plants.NitrateStorageRate{iPlant} = oLogger.addVirtualValue( sNO3UptakeStorage,   'kg/s', [oSystem.csPlants{iPlant} ' NO3 Storage Uptake']);
    oSetup.tiLogIndexes.Plants.NitrateStorage{iPlant}     = oLogger.addVirtualValue(['cumsum((', sNO3UptakeStorage,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' NO3 Storage Uptake Mass']);

    sNO3UptakeStructure = strjoin(csNO3UptakeStructure);
    sNO3UptakeStructure(end) = [];
    oSetup.tiLogIndexes.Plants.NitrateStructureRate{iPlant} = oLogger.addVirtualValue( sNO3UptakeStructure,   'kg/s', [oSystem.csPlants{iPlant} ' NO3 Structure Uptake']);
    oSetup.tiLogIndexes.Plants.Nitratestructure{iPlant}   = oLogger.addVirtualValue(['cumsum((', sNO3UptakeStructure,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' NO3 Structure Uptake Mass']);

    sNO3UptakeEdible = strjoin(csNO3UptakeEdible);
    sNO3UptakeEdible(end) = [];
    oSetup.tiLogIndexes.Plants.NitrateEdibleRate{iPlant}  = oLogger.addVirtualValue( sNO3UptakeEdible,   'kg/s', [oSystem.csPlants{iPlant} ' NO3 Edible Uptake']);
    oSetup.tiLogIndexes.Plants.NitrateEdible{iPlant}      = oLogger.addVirtualValue(['cumsum((', sNO3UptakeEdible,')	.* "Timestep")'], 'kg', [oSystem.csPlants{iPlant} ' NO3 Edible Uptake Mass']);
end
end