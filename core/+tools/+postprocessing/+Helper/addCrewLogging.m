function addCrewLogging(oLogger, oSystem)

%% Human Logs
csCO2FlowRates                  = cell(1, oSystem.iCrewMembers);
csO2FlowRates                   = cell(1, oSystem.iCrewMembers);
csIngestedWaterFlowRates        = cell(1, oSystem.iCrewMembers);
csRespirationWaterFlowRates     = cell(1, oSystem.iCrewMembers);
csPerspirationWaterFlowRates    = cell(1, oSystem.iCrewMembers);
csMetabolismWaterFlowRates      = cell(1, oSystem.iCrewMembers);
csStomachWaterFlowRates         = cell(1, oSystem.iCrewMembers);
csFecesWaterFlowRates           = cell(1, oSystem.iCrewMembers);
csUrineWaterFlowRates           = cell(1, oSystem.iCrewMembers);
csFoodFlowRates                 = cell(1, oSystem.iCrewMembers);
csFecesProteinFlowRates         = cell(1, oSystem.iCrewMembers);
csFecesFatFlowRates             = cell(1, oSystem.iCrewMembers);
csFecesGlucoseFlowRates         = cell(1, oSystem.iCrewMembers);
csFecesFiberFlowRates           = cell(1, oSystem.iCrewMembers);
csFecesSodiumFlowRates          = cell(1, oSystem.iCrewMembers);
csUrineSodiumFlowRates          = cell(1, oSystem.iCrewMembers);
csUrinePotassiumFlowRates       = cell(1, oSystem.iCrewMembers);
csUrineUreaFlowRates            = cell(1, oSystem.iCrewMembers);
csFecesConverterWaterFlowRates  = cell(1, oSystem.iCrewMembers);
csUrineConverterWaterFlowRates  = cell(1, oSystem.iCrewMembers);
for iHuman = 1:(oSystem.iCrewMembers)

    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.Potable_Water_In'],          'fFlowRate',       'kg/s', ['Ingested Water Flow Rate' num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.RespirationWaterOutput'],    'fFlowRate',       'kg/s', ['Respiration Water Flow Rate' num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.PerspirationWaterOutput'],   'fFlowRate',       'kg/s', ['Perspiration Water Flow Rate' num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.Urine_Out'],                 'fFlowRate',       'kg/s', ['Urine Flow Rate' num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.Food_In'],                   'fFlowRate',       'kg/s', ['Food Flow Rate' num2str(iHuman)]);


    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.Air_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',                  'kg/s',    ['CO2 Inlet Flowrate',      num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.Air_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',                 'kg/s',    ['CO2 Outlet Flowrate',     num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.Air_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',                   'kg/s',    ['O2 Inlet Flowrate',       num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,'.toBranches.Air_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',                  'kg/s',    ['O2 Outlet Flowrate',      num2str(iHuman)]);

    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic'],       'rRespiratoryCoefficient',     '-', ['Respiratory Coefficient ',    num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C3H7NO2)',          'kg/s', ['Metabolism Protein Flow Rate',   num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C51H98O6)',         'kg/s', ['Metabolism Fat Flow Rate',       num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C6H12O6)',          'kg/s', ['Metabolism Glucose Flow Rate',   num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.O2)',               'kg/s', ['Metabolism O2 Flow Rate',        num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.CO2)',              'kg/s', ['Metabolism CO2 Flow Rate',       num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.H2O)',              'kg/s', ['Metabolism H2O Flow Rate',       num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.CH4N2O)',           'kg/s', ['Metabolism Urea Flow Rate',      num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.Human_Tissue)',     'kg/s', ['Metabolism Muscle Flow Rate',    num2str(iHuman)]);

    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C3H7NO2)',              'kg/s', ['Stomach Protein Flow Rate',       num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C51H98O6)',             'kg/s', ['Stomach Fat Flow Rate',       	num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C6H12O6)',              'kg/s', ['Stomach Glucose Flow Rate',   	num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.H2O)',                  'kg/s', ['Stomach H2O Flow Rate',           num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.DietaryFiber)',         'kg/s', ['Stomach Fiber Flow Rate',         num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.Naplus)',               'kg/s', ['Stomach Sodium Flow Rate',        num2str(iHuman)]);

    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder'],              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',      'kg/s',	['H2O Massflow to Bladder',	num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder'],              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)', 	'kg/s',	['Na+ Massflow to Bladder',	num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder'],              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	['K+ Massflow to Bladder',	num2str(iHuman)]);

    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     ['Protein from LargeIntestine',    num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     ['Fat from LargeIntestine',    num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     ['Glucose from LargeIntestine',    num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],        'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     ['H2O from LargeIntestine',    num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     ['Fiber from LargeIntestine',    num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     ['Sodium from LargeIntestine',    num2str(iHuman)]);

    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:WaterBalance.toStores.WaterBalance.toPhases.Bladder.toManips.substance'], 'this.afPartialFlows(this.oMT.tiN2I.H2O)',            'kg/s', ['Urine Converter H2O Flow Rate',    num2str(iHuman)]);
    oLogger.addValue([oSystem.sName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Rectum.toManips.substance'],        'this.afPartialFlows(this.oMT.tiN2I.H2O)',            'kg/s', ['Feces Converter H2O Flow Rate',    num2str(iHuman)]);

    csCO2FlowRates{iHuman}                  = ['"CO2 Outlet Flowrate',          num2str(iHuman),'"    + "CO2 Inlet Flowrate', num2str(iHuman),'" +'];
    csO2FlowRates{iHuman}                   = ['"O2 Outlet Flowrate',           num2str(iHuman),'"    + "O2 Inlet Flowrate', num2str(iHuman),'" +'];
    csIngestedWaterFlowRates{iHuman}        = ['"Ingested Water Flow Rate',     num2str(iHuman),'" +'];
    csRespirationWaterFlowRates{iHuman}     = ['"Respiration Water Flow Rate',  num2str(iHuman),'" +'];
    csPerspirationWaterFlowRates{iHuman}    = ['"Perspiration Water Flow Rate', num2str(iHuman),'" +'];
    csMetabolismWaterFlowRates{iHuman}      = ['"Metabolism H2O Flow Rate',     num2str(iHuman),'" +'];
    csStomachWaterFlowRates{iHuman}         = ['"Stomach H2O Flow Rate',        num2str(iHuman),'" +'];
    csFecesWaterFlowRates{iHuman}           = ['"H2O from LargeIntestine',      num2str(iHuman),'" +'];
    csUrineWaterFlowRates{iHuman}           = ['"H2O Massflow to Bladder',      num2str(iHuman),'" +'];
    csFoodFlowRates{iHuman}                 = ['"Food Flow Rate',               num2str(iHuman),'" +'];
    csFecesProteinFlowRates{iHuman}         = ['"Protein from LargeIntestine',  num2str(iHuman),'" +'];
    csFecesFatFlowRates{iHuman}             = ['"Fat from LargeIntestine',      num2str(iHuman),'" +'];
    csFecesGlucoseFlowRates{iHuman}         = ['"Glucose from LargeIntestine',  num2str(iHuman),'" +'];
    csFecesFiberFlowRates{iHuman}           = ['"Fiber from LargeIntestine',    num2str(iHuman),'" +'];
    csFecesSodiumFlowRates{iHuman}          = ['"Sodium from LargeIntestine',   num2str(iHuman),'" +'];
    csUrineSodiumFlowRates{iHuman}          = ['"Na+ Massflow to Bladder',      num2str(iHuman),'" +'];
    csUrinePotassiumFlowRates{iHuman}       = ['"K+ Massflow to Bladder',       num2str(iHuman),'" +'];
    csUrineUreaFlowRates{iHuman}            = ['"Metabolism Urea Flow Rate',    num2str(iHuman),'" +'];
    csFecesConverterWaterFlowRates{iHuman}  = ['"Feces Converter H2O Flow Rate', num2str(iHuman),'" +'];
    csUrineConverterWaterFlowRates{iHuman}  = ['"Urine Converter H2O Flow Rate', num2str(iHuman),'" +'];
end

sFlowRates = strjoin(csCO2FlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(sFlowRates,   'kg/s', 'Effective CO_2 Flow Crew');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Exhaled CO_2');

sFlowRates = strjoin(csO2FlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue( sFlowRates,   'kg/s', 'Effective O_2 Flow Crew');
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Inhaled O_2');

sFlowRates = strjoin(csIngestedWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Ingested Water');

sFlowRates = strjoin(csRespirationWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Respiration Water');

sFlowRates = strjoin(csPerspirationWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Perspiration Water');

sFlowRates = strjoin(csMetabolismWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Metabolism Water');

sFlowRates = strjoin(csStomachWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Ingested Water in Food');

sFlowRates = strjoin(csFecesWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Feces Water');

sFlowRates = strjoin(csUrineWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Urine Water');

sFlowRates = strjoin(csFoodFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Ingested Food');

sFlowRates = strjoin(csFecesProteinFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Feces Protein');

sFlowRates = strjoin(csFecesFatFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Feces Fat');

sFlowRates = strjoin(csFecesGlucoseFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Feces Glucose');

sFlowRates = strjoin(csFecesFiberFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Feces Fiber');

sFlowRates = strjoin(csFecesSodiumFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Feces Na+');

sFlowRates = strjoin(csUrineSodiumFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Urine Na+');

sFlowRates = strjoin(csUrinePotassiumFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Urine K+');

sFlowRates = strjoin(csUrineUreaFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Urine Urea');

sFlowRates = strjoin(csFecesConverterWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Feces Converter Water');

sFlowRates = strjoin(csUrineConverterWaterFlowRates);
sFlowRates(end) = [];
oLogger.addVirtualValue(['cumsum((', sFlowRates,')         .* "Timestep")'], 'kg', 'Urine Converter Water');
            

end