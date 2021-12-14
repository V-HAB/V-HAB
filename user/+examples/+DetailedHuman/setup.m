classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            ttMonitorConfig = struct();
            this@simulation.infrastructure('Example_DetailedHumanModel', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Water content of Urine and Feces is based on BVAD, not all
            % possible components of both substances defined here
            trBaseCompositionUrine.H2O      = 0.9644;
            trBaseCompositionUrine.CH4N2O   = 0.0356;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Urine', trBaseCompositionUrine)
            
            trBaseCompositionFeces.H2O          = 0.7576;
            trBaseCompositionFeces.DietaryFiber = 0.2424;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Feces', trBaseCompositionFeces)
            
            examples.DetailedHuman.systems.Example(this.oSimulationContainer, 'Example');
            
            %% Simulation length
            % Stop when specific time in simulation is reached or after
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 24 * 7 * 5; % In seconds
            this.iSimTicks = 1500;
            this.bUseTime = true;
        end
        
        
        function configureMonitors(this)
            
            %% Logging
            oLogger = this.toMonitors.oLogger;
            
            csStores = fieldnames(this.oSimulationContainer.toChildren.Example.toStores);
            for iStore = 1:length(csStores)
                oLogger.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fMass',        'kg', [csStores{iStore}, ' Mass']);
                oLogger.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fPressure',	'Pa', [csStores{iStore}, ' Pressure']);
                oLogger.addValue(['Example.toStores.', csStores{iStore}, '.aoPhases(1)'],	'fTemperature',	'K',  [csStores{iStore}, ' Temperature']);
            end
            
            csBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toBranches);
            for iBranch = 1:length(csBranches)
                oLogger.addValue(['Example.toBranches.', csBranches{iBranch}],             'fFlowRate',    'kg/s', [csBranches{iBranch}, ' Flowrate']);
            end
            
            oLogger.addValue('Example:s:Cabin.toPhases.CabinAir',	'this.afPP(this.oMT.tiN2I.CO2)', 	'Pa',   'Partial Pressure CO2 Cabin');
            oLogger.addValue('Example:s:Cabin2.toPhases.CabinAir',	'this.afPP(this.oMT.tiN2I.CO2)', 	'Pa',   'Partial Pressure CO2 Cabin2');
            
            oLogger.addValue('Example:s:Cabin.toPhases.CabinAir',	'rRelHumidity', 	'-',   'Relative Humidity Cabin');
            oLogger.addValue('Example:s:Cabin2.toPhases.CabinAir',	'rRelHumidity', 	'-',   'Relative Humidity Cabin2');
            %% Parent System Logging
            csFecesComponents = {'H2O', 'DietaryFiber', 'C6H12O6', 'C51H98O6', 'C3H7NO2', 'Naplus'};
            for iComponent = 1:length(csFecesComponents)
                oLogger.addValue('Example.toStores.FecesStorage.toPhases.Feces',   ['this.afMass(this.oMT.tiN2I.Feces) .* this.arCompoundMass(this.oMT.tiN2I.Feces, this.oMT.tiN2I.', csFecesComponents{iComponent}, ')'],         'kg',   ['Feces ', csFecesComponents{iComponent},' Content']);
            end
            
            csUrineComponents = {'H2O', 'Naplus', 'CH4N2O'};
            for iComponent = 1:length(csUrineComponents)
                oLogger.addValue('Example.toStores.UrineStorage.toPhases.Urine',   ['this.afMass(this.oMT.tiN2I.Urine) .* this.arCompoundMass(this.oMT.tiN2I.Urine, this.oMT.tiN2I.', csUrineComponents{iComponent}, ')'],         'kg',   ['Urine ', csUrineComponents{iComponent},' Content']);
            end
            
            oLogger.addValue('Example.oTimer',     'fTimeStepFinal',	's',   'Timestep');
            
            %% Human Logs
            % This section contains a generalized logging for the values
            % you are most likely interested in from the human model (e.g.
            % O2, CO2, Water, Food etc, so basically all the interface
            % values)
            %
            % We first have to get the name of the root system
            sSystemName = fieldnames(this.oSimulationContainer.toChildren);
            sSystemName = sSystemName{1};
            % First we have to get the current number of crew members:
            iHumans = this.oSimulationContainer.toChildren.(sSystemName).iNumberOfCrewMembers;
            
            csCO2FlowRates                  = cell(1, iHumans);
            csO2FlowRates                   = cell(1, iHumans);
            csIngestedWaterFlowRates        = cell(1, iHumans);
            csRespirationWaterFlowRates     = cell(1, iHumans);
            csPerspirationWaterFlowRates    = cell(1, iHumans);
            csMetabolismWaterFlowRates      = cell(1, iHumans);
            csStomachWaterFlowRates         = cell(1, iHumans);
            csFecesWaterFlowRates           = cell(1, iHumans);
            csUrineWaterFlowRates           = cell(1, iHumans);
            csFoodFlowRates                 = cell(1, iHumans);
            csFecesProteinFlowRates         = cell(1, iHumans);
            csFecesFatFlowRates             = cell(1, iHumans);
            csFecesGlucoseFlowRates         = cell(1, iHumans);
            csFecesFiberFlowRates           = cell(1, iHumans);
            csFecesSodiumFlowRates          = cell(1, iHumans);
            csUrineSodiumFlowRates          = cell(1, iHumans);
            csUrinePotassiumFlowRates       = cell(1, iHumans);
            csUrineUreaFlowRates            = cell(1, iHumans);
            csFecesConverterWaterFlowRates  = cell(1, iHumans);
            csUrineConverterWaterFlowRates  = cell(1, iHumans);
            for iHuman = 1:(iHumans)
                
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.Potable_Water_In'],          'fFlowRate',       'kg/s', ['Ingested Water Flow Rate' num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.RespirationWaterOutput'],    'fFlowRate',       'kg/s', ['Respiration Water Flow Rate' num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.PerspirationWaterOutput'],   'fFlowRate',       'kg/s', ['Perspiration Water Flow Rate' num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.Urine_Out'],                 'fFlowRate',       'kg/s', ['Urine Flow Rate' num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.Food_In'],                   'fFlowRate',       'kg/s', ['Food Flow Rate' num2str(iHuman)]);
                
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.Air_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',                  'kg/s',    ['CO2 Inlet Flowrate',      num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.Air_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',                 'kg/s',    ['CO2 Outlet Flowrate',     num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.Air_In.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',                   'kg/s',    ['O2 Inlet Flowrate',       num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,'.toBranches.Air_Out.aoFlows(1)'], 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',                  'kg/s',    ['O2 Outlet Flowrate',      num2str(iHuman)]);
                
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic'],       'rRespiratoryCoefficient',     '-', ['Respiratory Coefficient ',    num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C3H7NO2)',          'kg/s', ['Metabolism Protein Flow Rate',   num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C51H98O6)',         'kg/s', ['Metabolism Fat Flow Rate',       num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C6H12O6)',          'kg/s', ['Metabolism Glucose Flow Rate',   num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.O2)',               'kg/s', ['Metabolism O2 Flow Rate',        num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.CO2)',              'kg/s', ['Metabolism CO2 Flow Rate',       num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.H2O)',              'kg/s', ['Metabolism H2O Flow Rate',       num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.CH4N2O)',           'kg/s', ['Metabolism Urea Flow Rate',      num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Metabolic.toStores.Metabolism.toPhases.Metabolism.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.Human_Tissue)',     'kg/s', ['Metabolism Muscle Flow Rate',    num2str(iHuman)]);
                
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C3H7NO2)',              'kg/s', ['Stomach Protein Flow Rate',       num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C51H98O6)',             'kg/s', ['Stomach Fat Flow Rate',       	num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.C6H12O6)',              'kg/s', ['Stomach Glucose Flow Rate',   	num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.H2O)',                  'kg/s', ['Stomach H2O Flow Rate',           num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.DietaryFiber)',         'kg/s', ['Stomach Fiber Flow Rate',         num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Stomach.toManips.substance'],       'this.afPartialFlows(this.oMT.tiN2I.Naplus)',               'kg/s', ['Stomach Sodium Flow Rate',        num2str(iHuman)]);

                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder'],              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',      'kg/s',	['H2O Massflow to Bladder',	num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder'],              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)', 	'kg/s',	['Na+ Massflow to Bladder',	num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:WaterBalance.toStores.WaterBalance.toProcsP2P.KidneyToBladder'],              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	['K+ Massflow to Bladder',	num2str(iHuman)]);

                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     ['Protein from LargeIntestine',    num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     ['Fat from LargeIntestine',    num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     ['Glucose from LargeIntestine',    num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],        'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     ['H2O from LargeIntestine',    num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     ['Fiber from LargeIntestine',    num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toProcsP2P.LargeIntestine_to_Rectum'],     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     ['Sodium from LargeIntestine',    num2str(iHuman)]);
                
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:WaterBalance.toStores.WaterBalance.toPhases.Bladder.toManips.substance'], 'this.afPartialFlows(this.oMT.tiN2I.H2O)',            'kg/s', ['Urine Converter H2O Flow Rate',    num2str(iHuman)]);
                oLogger.addValue([sSystemName, ':c:Human_', num2str(iHuman) ,':c:Digestion.toStores.Digestion.toPhases.Rectum.toManips.substance'],        'this.afPartialFlows(this.oMT.tiN2I.H2O)',            'kg/s', ['Feces Converter H2O Flow Rate',    num2str(iHuman)]);
                
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
            
            
            %% %%%%%%%%%%%%% Detailed Logs %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % These are only added for one crew member:
            
            %% Respiration Logging
            oLogger.addValue('Example:c:Human_1:c:Respiration',    'fVolumetricFlow_BrainBlood',       'm^3/s', 'Volumetric Blood Flow Brain');
            oLogger.addValue('Example:c:Human_1:c:Respiration',    'fVolumetricFlow_TissueBlood',      'm^3/s', 'Volumetric Blood Flow Tissue');
            oLogger.addValue('Example:c:Human_1:c:Respiration',    'fVolumetricFlow_Air',              'm^3/s', 'Volumetric Air Flow');
            
            oLogger.addValue('Example:c:Human_1:c:Respiration',	'this.tfPartialPressure.Brain.O2', 	'Pa',   'Partial Pressure O2 Brain');
            oLogger.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Brain.CO2',      'Pa',   'Partial Pressure CO2 Brain');
            oLogger.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Tissue.O2',  	'Pa',   'Partial Pressure O2 Tissue');
            oLogger.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Tissue.CO2', 	'Pa',   'Partial Pressure CO2 Tissue');
            oLogger.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Arteries.O2',  	'Pa',   'Partial Pressure O2 Arteries');
            oLogger.addValue('Example:c:Human_1:c:Respiration',    'tfPartialPressure.Arteries.CO2', 	'Pa',   'Partial Pressure CO2 Arteries');
            
            oLogger.addValue('Example:c:Human_1.toBranches.O2_from_Brain',     'fFlowRate',      'kg/s',     'Metabolic O2 from Brain');
            oLogger.addValue('Example:c:Human_1.toBranches.O2_from_Tissue',    'fFlowRate',      'kg/s',     'Metabolic O2 from Tissue');
            oLogger.addValue('Example:c:Human_1.toBranches.CO2_to_Brain',      'fFlowRate',      'kg/s',     'Metabolic CO2 to Brain');
            oLogger.addValue('Example:c:Human_1.toBranches.CO2_to_Tissue',     'fFlowRate',      'kg/s',     'Metabolic CO2 to Tissue');
            
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Lung.toPhases.Air',         'this.afMass(this.oMT.tiN2I.H2O)',	'kg', 	'Water in Lung Air');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Lung.toPhases.Blood',       'this.afMass(this.oMT.tiN2I.H2O)',	'kg', 	'Water in Lung Blood');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Arteries.toPhases.Blood', 	'this.afMass(this.oMT.tiN2I.H2O)',	'kg', 	'Water in Arteries');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Veins.toPhases.Blood',     	'this.afMass(this.oMT.tiN2I.H2O)',	'kg', 	'Water in Veins');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Brain.toPhases.Blood',      'this.afMass(this.oMT.tiN2I.H2O)',	'kg', 	'Water in Brain Blood');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Brain.toPhases.Tissue',     'this.afMass(this.oMT.tiN2I.H2O)',	'kg', 	'Water in Brain Tissue');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Tissue.toPhases.Blood',     'this.afMass(this.oMT.tiN2I.H2O)',	'kg', 	'Water in Tissue Blood');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Tissue.toPhases.Tissue',    'this.afMass(this.oMT.tiN2I.H2O)',	'kg', 	'Water in Tissue Tissue');
            
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Lung.toProcsP2P.Alveola_to_Air',    'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s', 	'Exhaled CO2');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Lung.toProcsP2P.Air_to_Alveola',    'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Inhaled O2');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Brain.toProcsP2P.Blood_to_Brain',   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Brain absorbed O2');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Brain.toProcsP2P.Brain_to_Blood',   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s',     'Brain desorbed CO2');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Tissue.toProcsP2P.Blood_to_Tissue', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',       'kg/s',     'Tissue absorbed O2');
            oLogger.addValue('Example:c:Human_1:c:Respiration.toStores.Tissue.toProcsP2P.Tissue_to_Blood', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',      'kg/s',     'Tissue desorbed CO2');
            
            %% Metabolic Logging
            
            oLogger.addValue('Example:c:Human_1:c:Metabolic', 'fVO2',                              'L/min',    'VO2');
            oLogger.addValue('Example:c:Human_1:c:Metabolic', 'fVO2_rest',                         'L/min',    'VO2 Rest');
            oLogger.addValue('Example:c:Human_1:c:Metabolic', 'fVO2_max',                          'L/min',    'VO2 Max');
            oLogger.addValue('Example:c:Human_1:c:Metabolic', 'rActivityLevel',                    '-',        'Activity Level');
            oLogger.addValue('Example:c:Human_1:c:Metabolic', 'fTotalMetabolicRate',               'W',        'Current Metabolic Rate');
            oLogger.addValue('Example:c:Human_1:c:Metabolic', 'fMetabolicHeatFlow',                'W',        'Current Metabolic Heatflow');
            oLogger.addValue('Example:c:Human_1:c:Metabolic', 'fRestingDailyEnergyExpenditure',  	'-',        'Resting Daily Energy Demand');
            oLogger.addValue('Example:c:Human_1:c:Metabolic', 'fAdditionalFoodEnergyDemand',       '-',        'Additional Energy Demand from Exercise');
            
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Liver',            'this.afMass(this.oMT.tiN2I.C6H12O6)',  	 'kg', 'Glucose in Liver');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Liver',            'this.afMass(this.oMT.tiN2I.H2O)',          'kg', 'Water in Liver');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.AdiposeTissue',    'this.afMass(this.oMT.tiN2I.C51H98O6)',  	 'kg', 'Fat Mass Adipose Tissue');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.AdiposeTissue',    'this.afMass(this.oMT.tiN2I.H2O)',          'kg', 'Water in Adipose Tissue');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.MuscleTissue',     'this.afMass(this.oMT.tiN2I.C6H12O6)',  	 'kg', 'Glucose in Muscle');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.MuscleTissue',     'this.afMass(this.oMT.tiN2I.Human_Tissue)', 'kg', 'Muscle Mass');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.MuscleTissue',     'this.afMass(this.oMT.tiN2I.H2O)',          'kg', 'Water in Muscle');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism',       'this.afMass(this.oMT.tiN2I.C3H7NO2)',      'kg', 'Protein Mass in Metabolism');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism',       'this.afMass(this.oMT.tiN2I.C51H98O6)',     'kg', 'Fat Mass in Metabolism');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism',       'this.afMass(this.oMT.tiN2I.C6H12O6)',      'kg', 'Glucose Mass in Metabolism');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toPhases.Metabolism',       'this.afMass(this.oMT.tiN2I.H2O)',          'kg', 'Water Mass in Metabolism');
            
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_Liver',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',      'kg/s', 'Glucose to Liver Flow Rate');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_MuscleTissue',      	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',      'kg/s', 'Glucose to Muscle Flow Rate');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_MuscleTissue',      	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Human_Tissue)',	'kg/s', 'Muscle from Metabolism Flow Rate');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_AdiposeTissue',      	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',     'kg/s', 'Fat to Adipose Tissue Flow Rate');
            oLogger.addValue('Example:c:Human_1:c:Metabolic.toStores.Metabolism.toProcsP2P.Metabolism_to_AdiposeTissue',      	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s', 'H2O to Adipose Tissue Flow Rate');
            
            %% Water Balance Logging
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance',      	'fConcentrationOfADHinBloodPlasma',             'munits/L', 'ADH in Blood Plasma');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance',      	'fConcentrationOfReninInBloodPlasma',           'ng/L',     'Renin in Blood Plasma');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance',      	'fConcentrationOfAngiotensinIIInBloodPlasma',  	'ng/L',     'Angiotensin II in Blood Plasma');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance',      	'fConcentrationOfAldosteronInBloodPlasma',    	'ng/L',     'Aldosteron in Blood Plasma');
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance',      	'rRatioOfAvailableSweat',                       '-',        'Available Sweat');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance',      	'fThirst',                                      '-',        'Thirst Level');
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.BloodPlasma',      	'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in Blood Plasma');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.BloodPlasma',      	'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in Blood Plasma');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.BloodPlasma',      	'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in Blood Plasma');
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.InterstitialFluid',	'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in InterstitialFluid');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.InterstitialFluid',	'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in InterstitialFluid');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.InterstitialFluid', 	'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in InterstitialFluid');
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.IntracellularFluid',	'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in IntracellularFluid');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.IntracellularFluid',	'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in IntracellularFluid');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.IntracellularFluid', 'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in IntracellularFluid');
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Kidney',             'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in Kidney');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Kidney',             'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in Kidney');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Kidney',             'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in Kidney');
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Bladder',            'this.afMass(this.oMT.tiN2I.H2O)',      'kg',	'H2O Mass in Bladder');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Bladder',            'this.afMass(this.oMT.tiN2I.Naplus)',  	'kg',	'Na+ Mass in Bladder');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Bladder',            'this.afMass(this.oMT.tiN2I.Kplus)',   	'kg',	'K+ Mass in Bladder');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toPhases.Bladder',            'this.afMass(this.oMT.tiN2I.Urine)',   	'kg',	'Urine Mass in Bladder');
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.PerspirationOutput.toPhases.PerspirationFlow', 'this.afMass(this.oMT.tiN2I.H2O)',  'kg',	'Persipiration Flow Water Mass');
            
            % Flux through endothelium is from Interstitial to Blood Plasma
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxThroughEndothelium',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',   	'kg/s',	'H2O Massflow through Endothelium');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxThroughEndothelium',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',   	'kg/s',	'H2O MassREflow through Endothelium');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxThroughEndothelium',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',	'kg/s',	'Na+ Massflow through Endothelium');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxThroughEndothelium',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',	'kg/s',	'Na+ MassREflow through Endothelium');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxThroughEndothelium',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ Massflow through Endothelium');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxThroughEndothelium',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ MassREflow through Endothelium');
            
            % Flux through cell membranes is from interstital to
            % intracellular
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxthroughCellMembranes',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',   	'kg/s',	'H2O Massflow through CellMembranes');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxthroughCellMembranes', 	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',   	'kg/s',	'H2O MassREflow through CellMembranes');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxthroughCellMembranes',   	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',	'kg/s',	'Na+ Massflow through CellMembranes');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxthroughCellMembranes',  	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',	'kg/s',	'Na+ MassREflow through CellMembranes');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.FluxthroughCellMembranes',  	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ Massflow through CellMembranes');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReFluxthroughCellMembranes',	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ MassREflow through CellMembranes');
            
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.InFluxKidney',                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',      'kg/s',	'H2O Massflow to Kidney');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.InFluxKidney',                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)', 	'kg/s',	'Na+ Massflow to Kidney');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.InFluxKidney',                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ Massflow to Kidney');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReadsorptionFluxFromKidney', 	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',      'kg/s',	'H2O readsorption from Kidney');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReadsorptionFluxFromKidney',  	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)', 	'kg/s',	'Na+ readsorption from Kidney');
            oLogger.addValue('Example:c:Human_1:c:WaterBalance.toStores.WaterBalance.toProcsP2P.ReadsorptionFluxFromKidney',  	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Kplus)', 	'kg/s',	'K+ readsorption from Kidney');
            
            % Since it is confusing to blood the flowrates that basically
            % handle negative flows as two values, we create virtual values
            % for the overall flows
            oLogger.addVirtualValue('"H2O Massflow through Endothelium" - "H2O MassREflow through Endothelium"',       'kg/s', 'Endothelium H2O Massflow');
            oLogger.addVirtualValue('"Na+ Massflow through Endothelium" - "Na+ MassREflow through Endothelium"',       'kg/s', 'Endothelium Na+ Massflow');
            oLogger.addVirtualValue('"K+ Massflow through Endothelium"  - "K+ MassREflow through Endothelium"',        'kg/s', 'Endothelium K+ Massflow');
            
            oLogger.addVirtualValue('"H2O Massflow through CellMembranes" - "H2O MassREflow through CellMembranes"',   'kg/s', 'CellMembranes H2O Massflow');
            oLogger.addVirtualValue('"Na+ Massflow through CellMembranes" - "Na+ MassREflow through CellMembranes"',   'kg/s', 'CellMembranes Na+ Massflow');
            oLogger.addVirtualValue('"K+ Massflow through CellMembranes"  - "K+ MassREflow through CellMembranes"',    'kg/s', 'CellMembranes K+ Massflow');
            
            oLogger.addVirtualValue('"H2O Massflow to Kidney" - "H2O readsorption from Kidney"',   'kg/s', 'Kidney H2O Massflow');
            oLogger.addVirtualValue('"Na+ Massflow to Kidney" - "Na+ readsorption from Kidney"',   'kg/s', 'Kidney Na+ Massflow');
            oLogger.addVirtualValue('"K+ Massflow to Kidney"  - "K+ readsorption from Kidney"',    'kg/s', 'Kidney K+ Massflow');
            
            %% Digestion
            % Stomach
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'fMass',                                            'kg',   'Total Mass in Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.C51H98O6)',            	'kg',   'Fat Mass in Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Stomach',                          'this.afMass(this.oMT.tiN2I.Naplus)',            	'kg',   'Sodium Mass in Stomach');
            
            % Duodenum
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.C51H98O6)',            	'kg',   'Fat Mass in Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Duodenum',                         'this.afMass(this.oMT.tiN2I.Naplus)',             	'kg',   'Sodium Mass in Duodenum');
            
            % Jejunum
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.C51H98O6)',             'kg',   'Fat Mass in Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Jejunum',                          'this.afMass(this.oMT.tiN2I.Naplus)',             	'kg',   'Sodium Mass in Jejunum');
            
            % Ileum
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.C51H98O6)',             'kg',   'Fat Mass in Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Ileum',                            'this.afMass(this.oMT.tiN2I.Naplus)',           	'kg',   'Sodium Mass in Ileum');
            
            % LargeIntestine
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                   'this.afMass(this.oMT.tiN2I.C3H7NO2)',              'kg',   'Protein Mass in LargeIntestine');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                	'this.afMass(this.oMT.tiN2I.C51H98O6)',             'kg',   'Fat Mass in LargeIntestine');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',               	'this.afMass(this.oMT.tiN2I.C6H12O6)',              'kg',   'Glucose Mass in LargeIntestine');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                	'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'H2O Mass in LargeIntestine');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                   'this.afMass(this.oMT.tiN2I.DietaryFiber)',     	'kg',   'Fiber Mass in LargeIntestine');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.LargeIntestine',                 	'this.afMass(this.oMT.tiN2I.Naplus)',              	'kg',   'Sodium Mass in LargeIntestine');
            
            % Rectum
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Rectum',                           'fMass',                                            'kg',   'Total Mass in Rectum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Rectum',                           'this.afMass(this.oMT.tiN2I.Feces)',                'kg',   'Feces Mass in Rectum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toPhases.Rectum',                           'this.afMass(this.oMT.tiN2I.H2O)',                  'kg',   'Water Mass in Rectum');
            
            % Branches to Metabolic Layer
            oLogger.addValue('Example:c:Human_1.toBranches.DuodenumToMetabolism.aoFlows(1)',                               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Digested Protein from Duodenum');
            oLogger.addValue('Example:c:Human_1.toBranches.DuodenumToMetabolism.aoFlows(1)',                               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',   	'kg/s',     'Digested Fat from Duodenum');
            oLogger.addValue('Example:c:Human_1.toBranches.DuodenumToMetabolism.aoFlows(1)',                               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Digested Glucose from Duodenum');
            
            oLogger.addValue('Example:c:Human_1.toBranches.JejunumToMetabolism.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Digested Protein from Jejunum');
            oLogger.addValue('Example:c:Human_1.toBranches.JejunumToMetabolism.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',   	'kg/s',     'Digested Fat from Jejunum');
            oLogger.addValue('Example:c:Human_1.toBranches.JejunumToMetabolism.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Digested Glucose from Jejunum');
            
            oLogger.addValue('Example:c:Human_1.toBranches.IleumToMetabolism.aoFlows(1)',                                  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Digested Protein from Ileum');
            oLogger.addValue('Example:c:Human_1.toBranches.IleumToMetabolism.aoFlows(1)',                                  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',   	'kg/s',     'Digested Fat from Ileum');
            oLogger.addValue('Example:c:Human_1.toBranches.IleumToMetabolism.aoFlows(1)',                                  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Digested Glucose from Ileum');
            
            % Readsorption Branches
            oLogger.addValue('Example:c:Human_1.toBranches.ReadsorptionFromDuodenum.aoFlows(1)',                           'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Readsorption Duodenum');
            oLogger.addValue('Example:c:Human_1.toBranches.ReadsorptionFromDuodenum.aoFlows(1)',                           'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium Readsorption Duodenum');
            
            oLogger.addValue('Example:c:Human_1.toBranches.ReadsorptionFromJejunum.aoFlows(1)',                            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Readsorption Jejunum');
            oLogger.addValue('Example:c:Human_1.toBranches.ReadsorptionFromJejunum.aoFlows(1)',                            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',    	'kg/s',     'Sodium Readsorption Jejunum');
            
            oLogger.addValue('Example:c:Human_1.toBranches.ReadsorptionFromIleum.aoFlows(1)',                              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Readsorption Ileum');
            oLogger.addValue('Example:c:Human_1.toBranches.ReadsorptionFromIleum.aoFlows(1)',                              'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium Readsorption Ileum');
            
            oLogger.addValue('Example:c:Human_1.toBranches.ReadsorptionFromLargeIntestine.aoFlows(1)',                     'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Readsorption LargeIntestine');
            oLogger.addValue('Example:c:Human_1.toBranches.ReadsorptionFromLargeIntestine.aoFlows(1)',                 	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium Readsorption LargeIntestine');
            
            % Secretion Branches
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToStomach.aoFlows(1)',                                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion Stomach');
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToStomach.aoFlows(1)',                                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium Secretion Stomach');
            
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToDuodenum.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion Duodenum');
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToDuodenum.aoFlows(1)',                                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',     	'kg/s',     'Sodium Secretion Duodenum');
            
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToJejunum.aoFlows(1)',                                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion Jejunum');
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToJejunum.aoFlows(1)',                                 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',     	'kg/s',     'Sodium Secretion Jejunum');
            
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToIleum.aoFlows(1)',                                   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion Ileum');
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToIleum.aoFlows(1)',                                   'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',     	'kg/s',     'Sodium Secretion Ileum');
            
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToLargeIntestine.aoFlows(1)',                          'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O Secretion LargeIntestine');
            oLogger.addValue('Example:c:Human_1.toBranches.SecretionToLargeIntestine.aoFlows(1)',                        	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',     	'kg/s',     'Sodium Secretion LargeIntestine');
            
            % Transport P2Ps
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',      'H2O from Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from Stomach');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Stomach_to_Duodenum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from Stomach');
            
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O from Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from Duodenum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Duodenum_to_Jejunum',            'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from Duodenum');
            
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O from Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from Jejunum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Jejunum_to_Ileum',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from Jejunum');
            
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',       	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C3H7NO2)',    	'kg/s',     'Protein from Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C51H98O6)',    	'kg/s',     'Fat from Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',       	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C6H12O6)',    	'kg/s',     'Glucose from Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',         'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',          'kg/s',     'H2O from Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.DietaryFiber)',	'kg/s',     'Fiber from Ileum');
            oLogger.addValue('Example:c:Human_1:c:Digestion.toStores.Digestion.toProcsP2P.Ileum_to_LargeIntestine',     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Naplus)',      	'kg/s',     'Sodium from Ileum');
            
            oLogger.addVirtualValue('"H2O Mass in LargeIntestine" + "H2O Mass in Ileum" + "H2O Mass in Jejunum" + "H2O Mass in Duodenum" + "H2O Mass in Stomach" + "Water Mass in Rectum"',                                         	'kg', 'Water Mass in Digestion Layer');
            oLogger.addVirtualValue('"H2O Mass in Blood Plasma" + "H2O Mass in InterstitialFluid" + "H2O Mass in IntracellularFluid" + "H2O Mass in Kidney" + "H2O Mass in Bladder" + "Persipiration Flow Water Mass"',                'kg', 'Water Mass in Water Layer');
            oLogger.addVirtualValue('"Water in Adipose Tissue" + "Water Mass in Metabolism" + "Water in Liver" + "Water in Muscle"',                                                                                                   'kg', 'Water Mass in Metabolic Layer');
            oLogger.addVirtualValue('"Water in Lung Air" + "Water in Lung Blood" + "Water in Arteries" + "Water in Veins" + "Water in Brain Blood" + "Water in Brain Tissue" + "Water in Tissue Blood" + "Water in Tissue Tissue"',	'kg', 'Water Mass in Respiration Layer');
            
            
            
        end
        
        function plot(this, varargin) % Plotting the results
            
            %% Define Plots
            
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            
            tPlotOptions.sTimeUnit  = 'hours';
            
            
            %% Basic Crew Plot
            % This section contains the basic plots which show the
            % interfaces of the crew. This can be added to your simulations
            % if you want a plot showing this overview
            
            sSystemName = fieldnames(this.oSimulationContainer.toChildren);
            sSystemName = sSystemName{1};
            % First we have to get the current number of crew members:
            iHumans = this.oSimulationContainer.toChildren.(sSystemName).iNumberOfCrewMembers;
            
            csRespiratoryCoefficient = cell(1,iHumans);
            for iHuman = 1:iHumans
                csRespiratoryCoefficient{iHuman} = ['"Respiratory Coefficient ',    num2str(iHuman), '"'];
            end
            coPlot = cell(0);
            coPlot{1,1} = oPlotter.definePlot({'"Effective CO_2 Flow Crew"', '"Effective O_2 Flow Crew"'},	'Crew Respiration Flowrates', tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot(csRespiratoryCoefficient,                                     'Crew Respiratory Coefficients', tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({'"Exhaled CO_2"', '"Inhaled O_2"'},                          'Crew Cumulative Respiration', tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Respiration Water"', '"Perspiration Water"', '"Metabolism Water"', '"Urine Urea"'},    'Crew Cumulative Masses', tPlotOptions);
           
            oPlotter.defineFigure(coPlot,       'Crew Values');
            
            %% General Plots
            
            coPlot = cell(2,2);
            csFecesComponents = {'H2O', 'DietaryFiber', 'C6H12O6', 'C51H98O6', 'C3H7NO2', 'Naplus'};
            csFecesMass = cell(1, length(csFecesComponents));
            for iComponent = 1:length(csFecesComponents)
                csFecesMass{iComponent} = ['"Feces ', csFecesComponents{iComponent},' Content"'];
            end
            
            csUrineComponents = {'H2O', 'Naplus', 'CH4N2O'};
            csUrineMass = cell(1, length(csUrineComponents));
            for iComponent = 1:length(csUrineComponents)
                csUrineMass{iComponent} = ['"Urine ', csUrineComponents{iComponent},' Content"'];
            end
            
            coPlot{1,1} = oPlotter.definePlot(csFecesMass, 'Feces Composition', tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot(csUrineMass, 'Urine Composition', tPlotOptions);
           
            coPlot{1,2} = oPlotter.definePlot({'"Ingested Water Flow Rate1"', '"Respiration Water Flow Rate1"', '"Perspiration Water Flow Rate1"', '"Urine Flow Rate1"'}, 'Human Water Flows', tPlotOptions);
            
            coPlot{2,2} = oPlotter.definePlot({'"Partial Pressure CO2 Cabin"', '"Partial Pressure CO2 Cabin2"'}, 'Cabin CO2', tPlotOptions);
            coPlot{3,1} = oPlotter.definePlot({'"Relative Humidity Cabin"', '"Relative Humidity Cabin2"'}, 'Cabin Relative Humidity', tPlotOptions);
            
            oPlotter.defineFigure(coPlot,  'General Plots');
            
            %% Respiration
            coPlot = cell(2,2);
            coPlot{1,1} = oPlotter.definePlot({'"Volumetric Blood Flow Brain"', '"Volumetric Blood Flow Tissue"', '"Volumetric Air Flow"'}, 'Respiration Volumetric Flows', tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({ '"Partial Pressure O2 Brain"',      '"Partial Pressure CO2 Brain"', ....
                '"Partial Pressure O2 Tissue"',     '"Partial Pressure CO2 Tissue"', ....
                '"Partial Pressure O2 Arteries"',   '"Partial Pressure CO2 Arteries"'}, 'Respiration Partial Presssures', tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({'"Exhaled CO2"', '"Inhaled O2"', '"Brain absorbed O2"', '"Brain desorbed CO2"', '"Tissue absorbed O2"', '"Tissue desorbed CO2"'}, 'Respiration P2P Flows', tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Metabolic CO2 to Brain"', '"Metabolic CO2 to Tissue"', '"Metabolic O2 from Brain"', '"Metabolic O2 from Tissue"'}, 'Metabolic O2 and CO2 Flows', tPlotOptions);
            oPlotter.defineFigure(coPlot,  'Respiration');
            
            %% Metabolic
            coPlot = cell(3,3);
            coPlot{1,1} = oPlotter.definePlot({'"VO2"', '"VO2 Rest"', '"VO2 Max"'}, 'VO2', tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({ '"Current Metabolic Rate"', '"Current Metabolic Heatflow"'}, 'Metabolic Rate', tPlotOptions);
            coPlot{1,3} = oPlotter.definePlot({'"Activity Level"', '"Respiratory Coefficient 1"'}, 'Activity Level and Respiratory Coefficient', tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({'"Fat Mass Adipose Tissue"', '"Water in Adipose Tissue"', '"Muscle Mass"'}, 'Masses in Metabolic Layer', tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Protein Mass in Metabolism"', '"Fat Mass in Metabolism"', '"Glucose Mass in Metabolism"', '"Water Mass in Metabolism"'}, 'Masses in Metabolism Phase', tPlotOptions);
            
            coPlot{2,3} = oPlotter.definePlot({'"Metabolism Protein Flow Rate1"', '"Metabolism Fat Flow Rate1"', '"Metabolism Glucose Flow Rate1"', '"Metabolism O2 Flow Rate1"',...
                '"Metabolism CO2 Flow Rate1"', '"Metabolism H2O Flow Rate1"', '"Metabolism Urea Flow Rate1"', '"Metabolism Muscle Flow Rate1"'}, 'Manipulator Flowrates in Metabolism', tPlotOptions);
            
            coPlot{3,1} = oPlotter.definePlot({'"Glucose in Liver"', '"Glucose in Muscle"', }, 'Glucose Masses in Metabolic Layer', tPlotOptions);
            
            coPlot{3,2} = oPlotter.definePlot({'"Resting Daily Energy Demand"', '"Additional Energy Demand from Exercise"', }, 'Metabolic Energy Demands', tPlotOptions);
            
            coPlot{3,3} = oPlotter.definePlot({'"Glucose to Liver Flow Rate"', '"Glucose to Muscle Flow Rate"', '"Muscle from Metabolism Flow Rate"', '"Fat to Adipose Tissue Flow Rate"', '"H2O to Adipose Tissue Flow Rate"'}, 'P2P Flowrates in Metabolism', tPlotOptions);
            
            oPlotter.defineFigure(coPlot,  'Metabolic');
            
            %% Water Balance
            coPlot = cell(3,3);
            
            coPlot{1,1} = oPlotter.definePlot({'"ADH in Blood Plasma"', '"Renin in Blood Plasma"', '"Angiotensin II in Blood Plasma"', '"Aldosteron in Blood Plasma"'}, 'Hormone Concentrations in Blood Plasma',   tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({'"Thirst Level"'}, 'Thirst', tPlotOptions);
            coPlot{1,3} = oPlotter.definePlot({'"Urine Mass in Bladder"',       '"H2O Mass in Bladder"',	'"Na+ Mass in Bladder"',                    '"K+ Mass in Bladder"'},              	'Bladder Masses',   tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({'"H2O Mass in Blood Plasma"',    '"H2O Mass in Kidney"',    	'"H2O Mass in InterstitialFluid"',          '"H2O Mass in IntracellularFluid"'}, 	'Water Masses',     tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Na+ Mass in Blood Plasma"', 	'"Na+ Mass in Kidney"',     '"Na+ Mass in InterstitialFluid"',          '"Na+ Mass in IntracellularFluid"'},  	'Na+ Masses',       tPlotOptions);
            coPlot{2,3} = oPlotter.definePlot({'"K+ Mass in Blood Plasma"',     '"K+ Mass in Kidney"',      '"K+ Mass in InterstitialFluid"',           '"K+ Mass in IntracellularFluid"'},     'K+ Masses',        tPlotOptions);
            
            coPlot{3,1} = oPlotter.definePlot({'"Endothelium H2O Massflow"',        '"Endothelium Na+ Massflow"',       '"Endothelium K+ Massflow"'},                                           'Endothelium Flows', tPlotOptions);
            
            coPlot{3,2} = oPlotter.definePlot({'"CellMembranes H2O Massflow"',      '"CellMembranes Na+ Massflow"',   	'"CellMembranes K+ Massflow"'},                                       	'Cell Membrane Flows', tPlotOptions);
            
            coPlot{3,3} = oPlotter.definePlot({'"Kidney H2O Massflow"',         	'"Kidney Na+ Massflow"',         	'"Kidney K+ Massflow"', '"H2O Massflow to Bladder1"',      	'"Na+ Massflow to Bladder1"',      	'"K+ Massflow to Bladder1"'},	'Kidney Flows', tPlotOptions);
            
            oPlotter.defineFigure(coPlot,  'Water Balance');
            
            coPlot = cell(2,2);
            coPlot{1,1} = oPlotter.definePlot({'"Water Mass in Digestion Layer"', '"Water Mass in Water Layer"', '"Water Mass in Metabolic Layer"', '"Water Mass in Respiration Layer"'},      'Water Masses in Layers',       tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({'"Ingested Water Flow Rate1"', '"Respiration Water Flow Rate1"', '"Perspiration Water Flow Rate1"', '"Metabolism H2O Flow Rate1"', '"Stomach H2O Flow Rate1"', '"H2O from LargeIntestine1"', '"H2O Massflow to Bladder1"'},      'Water Flows',       tPlotOptions);
                
            oPlotter.defineFigure(coPlot,  'Water Balance all Layers Overview');
            
            %% Digestion
            csPhases = {'Stomach', 'Duodenum', 'Jejunum', 'Ileum', 'LargeIntestine'};
            csMasses = {'Protein', 'Fat', 'Glucose', 'H2O', 'Sodium', 'Fiber'};
            
            tfMass = struct();
            
            iPhases = length(csPhases);
            iMasses = length(csMasses);
            
            for iMass = 1:iMasses
                tfMass.(csMasses{iMass}) = cell(1, iPhases);
                for iPhase = 1:iPhases
                    tfMass.(csMasses{iMass}){iPhase} = ['"', csMasses{iMass}, ' Mass in ', csPhases{iPhase}, '"'];
                end
            end
            
            csPhases{end} = 'LargeIntestine1';
            
            % For the transport flows inside the digestion layer, consider
            % all phases and masses again:
            tfTransportFlows = struct();
            for iMass = 1:iMasses
                tfTransportFlows.(csMasses{iMass}) = cell(1, iPhases + 1);
                for iPhase = 1:iPhases
                    tfTransportFlows.(csMasses{iMass}){iPhase} = ['"', csMasses{iMass}, ' from ', csPhases{iPhase}, '"'];
                end
                tfTransportFlows.(csMasses{iMass}){iPhases + 1} = ['"Stomach ', csMasses{iMass}, ' Flow Rate1"'];
            end
            
            % For the flows to metabolism, all phases except stomach and
            % large intestine, and for masses only the major nutrients
            % (water and sodium are handled in the readsorption part)
            csMasses = {'Protein', 'Fat', 'Glucose'};
            csPhases{end} = 'LargeIntestine';
            iMasses = length(csMasses);
            
            tfMetabolismFlows = struct();
            for iMass = 1:(iMasses)
                tfMetabolismFlows.(csMasses{iMass}) = cell(1, iPhases - 2);
                for iPhase = 2:(iPhases - 1)
                    tfMetabolismFlows.(csMasses{iMass}){iPhase - 1} = ['"Digested ', csMasses{iMass}, ' from ', csPhases{iPhase}, '"'];
                end
            end
            
            % For secretion and readsorption only water and sodium
            csMasses = {'H2O', 'Sodium'};
            iMasses = length(csMasses);
            % Readsorption Branches, without stomach
            tfReadsorptionFlows = struct();
            for iMass = 1:(iMasses)
                tfReadsorptionFlows.(csMasses{iMass}) = cell(1, iPhases - 1);
                for iPhase = 2:(iPhases)
                    tfReadsorptionFlows.(csMasses{iMass}){iPhase - 1} = ['"', csMasses{iMass}, ' Readsorption ', csPhases{iPhase}, '"'];
                end
            end
            
            tfSecretionFlows = struct();
            for iMass = 1:(iMasses)
                tfSecretionFlows.(csMasses{iMass}) = cell(1, iPhases);
                for iPhase = 1:(iPhases)
                    tfSecretionFlows.(csMasses{iMass}){iPhase} = ['"', csMasses{iMass}, ' Secretion ', csPhases{iPhase}, '"'];
                end
            end
            
            % Define the figures, for digestion we use more than one figure
            coPlot = cell(3,2);
            csMasses = fieldnames(tfMass);
            iMasses = length(csMasses);
            for iMass = 1:iMasses
                coPlot{iMass} = oPlotter.definePlot(tfMass.(csMasses{iMass}), [csMasses{iMass}, ' Masses'],   tPlotOptions);
            end
            oPlotter.defineFigure(coPlot,  'Digestion Masses');
            
            coPlot = cell(3,1);
            csFlows = fieldnames(tfMetabolismFlows);
            iFlows = length(csFlows);
            for iFlow = 1:iFlows
                coPlot{iFlow} = oPlotter.definePlot(tfMetabolismFlows.(csFlows{iFlow}), [csFlows{iFlow}, ' Flows to Metabolism'],   tPlotOptions);
            end
            oPlotter.defineFigure(coPlot,  'Digestion Flows to Metabolism');
            
            coPlot = cell(3,2);
            csFlows = fieldnames(tfTransportFlows);
            iFlows = length(csFlows);
            for iFlow = 1:iFlows
                coPlot{iFlow} = oPlotter.definePlot(tfTransportFlows.(csFlows{iFlow}), [csFlows{iFlow}, ' Transport and Stomach Manip Flows'],   tPlotOptions);
            end
            oPlotter.defineFigure(coPlot,  'Digestion Internal Flows');
            
            coPlot = cell(3,2);
            coPlot{1,1} = oPlotter.definePlot(tfReadsorptionFlows.H2O,      'H2O Readsorption Flows',       tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot(tfReadsorptionFlows.Sodium,   'Sodium Readsorption Flows',    tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot(tfSecretionFlows.H2O,         'H2O Secretion Flows',          tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot(tfSecretionFlows.Sodium,      'Sodium Secretion Flows',       tPlotOptions);
            coPlot{3,1} = oPlotter.definePlot({'"Total Mass in Stomach"', '"Total Mass in Rectum"', '"Feces Mass in Rectum"'},      'Masses in Stomach and Rectum',       tPlotOptions);
                
            oPlotter.defineFigure(coPlot,  'Digestion Readsorption and Secretion Flows');
            
            
            
            
            oPlotter.plot();
            
            oLogger = this.toMonitors.oLogger;
            
            iLogs = length(oLogger.afTime);
            
            afTimeSteps = (oLogger.afTime(2:end) - oLogger.afTime(1:end-1));

            for iLog = 1:oLogger.iNumberOfLogItems
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Timestep')
                    afTimeStepsLogged = oLogger.mfLog(:, iLog);
                end
            end
            
            for iVirtualLog = 1:length(oLogger.tVirtualValues)
                if strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Ingested Water')
                    afConsumedDrinkingWater     = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Respiration Water')
                    afProducedRespirationWater  = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Perspiration Water')
                    afProducedPerspirationWater = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Metabolism Water')
                    afProducedMetabolicWater    = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Ingested Water in Food')
                    afIngestedWaterInFood       = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Feces Water')
                    afFecesWater                = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Urine Water')
                    afUrineWater                = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Ingested Food')
                    afFood                      = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Feces Protein')
                    afFecesProtein            	= oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Feces Fat')
                    afFecesFat                	= oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Feces Glucose')
                    afFecesGlucose            	= oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Feces Fiber')
                    afFecesFiber            	= oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Feces Na+')
                    afFecesSodium             	= oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Urine Na+')
                    afUrineSodium             	= oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Urine K+')
                    afUrinePotassium          	= oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Urine Urea')
                    afUrineUrea                 = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel,  'Water Mass in Digestion Layer')
                    afWaterDigestionLayer       = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel,  'Water Mass in Water Layer')
                    afWaterWaterLayer           = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel,  'Water Mass in Metabolic Layer')
                    afWaterMetabolicLayer       = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel,  'Water Mass in Respiration Layer')
                    afWaterRespirationLayer     = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Exhaled CO_2')
                    mfExhaledCO2                = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Inhaled O_2')
                    mfInhaledO2                 = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Feces Converter Water')
                    afFecesConverterWaterFlow   = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                elseif strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Urine Converter Water')
                    afUrineConverterWaterFlow 	= oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                end
            end
            
            
            % We calculated the individual masses to be able to check
            % those, but for now we just compare the total feces solid
            % production
            afFecesSolids = afFecesProtein + afFecesFat + afFecesGlucose + afFecesFiber + afFecesSodium;
            afUrineSolids = afUrineSodium + afUrinePotassium + afUrineUrea;
            
            afGeneratedCO2Mass  = zeros(iLogs,1);
            afConsumedO2Mass    = zeros(iLogs,1);
            for iVirtualLog = 2:iLogs
                afGeneratedCO2Mass(iVirtualLog)  = sum(afTimeSteps(1:iVirtualLog-1)' .* mfExhaledCO2(2:iVirtualLog));
                afConsumedO2Mass(iVirtualLog)    = sum(afTimeSteps(1:iVirtualLog-1)' .* mfInhaledO2(2:iVirtualLog));
            end
            
            if any(isnan(afConsumedO2Mass))
                iLastIndex = find(isnan(afConsumedO2Mass), 1) - 1;
            else
                iLastIndex = length(afConsumedO2Mass);
            end
            
            figure()
            plot(oLogger.afTime(1:iLastIndex)./3600, -1 .* afConsumedDrinkingWater(1:iLastIndex),         '-')
            hold on
            grid on
            plot(oLogger.afTime(1:iLastIndex)./3600, -1 .* afProducedRespirationWater(1:iLastIndex),   	'-')
            plot(oLogger.afTime(1:iLastIndex)./3600, -1 .* afProducedPerspirationWater(1:iLastIndex),  	'-')
            plot(oLogger.afTime(1:iLastIndex)./3600,       afProducedMetabolicWater(1:iLastIndex),     	'--')
            plot(oLogger.afTime(1:iLastIndex)./3600, -1 .* afFecesWater(1:iLastIndex),                    '--')
            plot(oLogger.afTime(1:iLastIndex)./3600, -1 .* afFecesSolids(1:iLastIndex),                   '--')
            plot(oLogger.afTime(1:iLastIndex)./3600, -1 .* afUrineWater(1:iLastIndex),                    ':')
            plot(oLogger.afTime(1:iLastIndex)./3600, -1 .* afUrineSolids(1:iLastIndex),                   ':')
            plot(oLogger.afTime(1:iLastIndex)./3600, -1 .* afGeneratedCO2Mass(1:iLastIndex),              ':')
            plot(oLogger.afTime(1:iLastIndex)./3600,       afIngestedWaterInFood(1:iLastIndex),           '-.')
            plot(oLogger.afTime(1:iLastIndex)./3600,       afFood(1:iLastIndex),                          '-.')
            plot(oLogger.afTime(1:iLastIndex)./3600,       afConsumedO2Mass(1:iLastIndex),                '-.')
           
            legend( 'Drinking Water', 'Respiration Water', 'Perspiration Water', 'Metabolic Water', 'Feces Water', 'Feces Solids', ...
                    'Urine Water', 'Urine Solids', 'Generated CO2', 'Ingested Water from Food', 'Consumed Food', 'Consumed O2');
            xlabel('Time in [h]')
            ylabel('Mass in [kg]')
            hold off
            
            % Check water mass balance:
            
            fInitialWaterMassHuman  = afWaterDigestionLayer(1) + afWaterWaterLayer(1) + afWaterMetabolicLayer(1) + afWaterRespirationLayer(1);
            fFinalWaterMassHuman    = afWaterDigestionLayer(iLastIndex) + afWaterWaterLayer(iLastIndex) + afWaterMetabolicLayer(iLastIndex) + afWaterRespirationLayer(iLastIndex);
            fWaterMassDiffHuman     = fInitialWaterMassHuman - fFinalWaterMassHuman;
            
            % Drinking water is an input, but as the logged value is the
            % input branch, an inflow into the human has negative values
            fTotalWaterDiffInOuts   = afProducedMetabolicWater(iLastIndex) + afIngestedWaterInFood(iLastIndex) - afConsumedDrinkingWater(iLastIndex)  - ...
            (afProducedRespirationWater(iLastIndex) + afProducedPerspirationWater(iLastIndex) + afUrineWater(iLastIndex) + afFecesWater(iLastIndex));
            
            fTotalWaterChangeManips = afFecesConverterWaterFlow(iLastIndex) + afUrineConverterWaterFlow(iLastIndex) + afProducedMetabolicWater(iLastIndex) + afIngestedWaterInFood(iLastIndex);
        
            % Average Daily consumptions and productions
            fAverageO2              = abs(afConsumedO2Mass(iLastIndex)                                                          / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageCO2             = abs(afGeneratedCO2Mass(iLastIndex)                                                        / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageHumidity        = abs((afProducedRespirationWater(iLastIndex) + afProducedPerspirationWater(iLastIndex))    / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAveragePotableWater    = abs(afConsumedDrinkingWater(iLastIndex)                                                   / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageMetabolicWater 	= abs(afProducedMetabolicWater(iLastIndex)                                                  / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageFoodWater       = abs(afIngestedWaterInFood(iLastIndex)                                                     / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageFood            = abs(afFood(iLastIndex)                                                                    / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageUrine           = abs((afUrineWater(iLastIndex))                                                            / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageUrineSolids    	= abs((afUrineSolids(iLastIndex))                                                           / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageFeces           = abs((afFecesWater(iLastIndex))                                                            / (oLogger.afTime(iLastIndex) / (24*3600)));
            fAverageFecesSolid    	= abs((afFecesSolids(iLastIndex))                                                           / (oLogger.afTime(iLastIndex) / (24*3600)));
            
            fDifferenceO2               = ((fAverageO2              / 0.816)    - 1)	* 100;
            fDifferenceCO2              = ((fAverageCO2             / 1.04)     - 1)    * 100;
            fDifferenceHumidity         = ((fAverageHumidity        / 1.9)      - 1) 	* 100; 
            fDifferencePotableWater     = ((fAveragePotableWater    / 2.5)      - 1)  	* 100; 
            fDifferenceMetabolicWater	= ((fAverageMetabolicWater  / 0.345)    - 1)    * 100; 
            fDifferenceFoodWater        = ((fAverageFoodWater       / 0.7)      - 1)  	* 100; 
            fDifferenceFood             = ((fAverageFood            / 1.5)      - 1)  	* 100; 
            fDifferenceUrine            = ((fAverageUrine           / 1.6)      - 1)   	* 100; 
            fDifferenceUrineSolids    	= ((fAverageUrineSolids     / 0.059)    - 1)    * 100; 
            fDifferenceFeces            = ((fAverageFeces           / 0.1)      - 1)  	* 100; 
            fDifferenceFecesSolid    	= ((fAverageFecesSolid      / 0.032)    - 1)    * 100; 
            
            disp(['Average daily O2 consumption:                    ', num2str(fAverageO2), ' kg           	BVAD value is 0.816 kg'])
            disp(['Average daily Water consumption:                 ', num2str(fAveragePotableWater), ' kg              BVAD value is 2.5 kg'])
            disp(['Average daily Food Water consumption:            ', num2str(fAverageFoodWater), ' kg             BVAD value is 0.7 kg'])
            disp(['Average daily Food consumption:                  ', num2str(fAverageFood), ' kg         	BVAD value is 1.5 kg'])
            disp(['Average daily Metabolic Water production:        ', num2str(fAverageMetabolicWater), ' kg                BVAD value is 0.345 kg'])
            disp(['Average daily CO2 production:                    ', num2str(fAverageCO2), ' kg          	BVAD value is 1.04 kg'])
            disp(['Average daily Humidity production:               ', num2str(fAverageHumidity), ' kg          BVAD value is 1.9 kg'])
            disp(['Average daily Urine Water production:            ', num2str(fAverageUrine), ' kg             BVAD value is 1.6 kg'])
            disp(['Average daily Urine Solid production:            ', num2str(fAverageUrineSolids), ' kg       BVAD value is 0.059 kg'])
            disp(['Average daily Feces Water production:            ', num2str(fAverageFeces), ' kg             BVAD value is 0.1 kg'])
            disp(['Average daily Feces Solid production:            ', num2str(fAverageFecesSolid), ' kg        BVAD value is 0.032 kg'])
            disp(' ')
            disp(['Difference daily O2 consumption:                ', num2str(fDifferenceO2), ' %'])
            disp(['Difference daily Water consumption:             ', num2str(fDifferencePotableWater), ' %'])
            disp(['Difference daily Food Water consumption:        ', num2str(fDifferenceFoodWater), ' %'])
            disp(['Difference daily Food consumption:              ', num2str(fDifferenceFood), ' %'])
            disp(['Difference daily Metabolic Water production:    ', num2str(fDifferenceMetabolicWater), ' %'])
            disp(['Difference daily CO2 production:                ', num2str(fDifferenceCO2), ' %'])
            disp(['Difference daily Humidity production:           ', num2str(fDifferenceHumidity), ' %'])
            disp(['Difference daily Urine Water production:        ', num2str(fDifferenceUrine), ' %'])
            disp(['Difference daily Urine Solid production:        ', num2str(fDifferenceUrineSolids), ' %'])
            disp(['Difference daily Feces Water production:        ', num2str(fDifferenceFeces), ' %'])
            disp(['Difference daily Feces Solid production:        ', num2str(fDifferenceFecesSolid), ' %'])
            disp(' ')
            disp(['Difference in total water within the Human:      ', num2str(fWaterMassDiffHuman), ' kg'])
            disp(['Difference in water in- and outputs of Human:    ', num2str(fTotalWaterDiffInOuts), ' kg'])
            disp(' ')
            disp('All BVAD values refer to Table 3.26 in the NASA Baseline Values and Assumptions Document (BVAD) 2018')
            
            
        end
    end
end