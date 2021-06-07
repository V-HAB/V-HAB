classdef setup < simulation.infrastructure
    
    %% README
    % This is the setup file to simulate the full ISS air revitalization 
    % build up by American and Russian technologies.
    %
    % Note use the command: vhab.exec('simulations.ISS.setup', containers.Map('tbCases', struct('ACLS', true, ))))
    % to specify a case for the simulation (in this case ACLS) by setting
    % the respective field in the struct to true
    % Currently implemented cases:
    %
    %'ACLS': Adds the ACLS to the ISS LSS in the US Lab
    %
    %'IronRing1' & 'IronRing2':
    % Both IronRing casesput the whole crew into JEM during nominal phase
    % case 2 additionally reduces the IMV from Node 2 to JEM and JEM to
    % Node 2 to 80 cfm
    %
    % 'PlantChamber' will add a plant growth chamber to the ISS, this case
    % requires the additional parameter, sPlantLocation
    %
    % vhab.exec('simulations.ISS.setup', containers.Map({'tbCases', 'sPlantLocation'},{struct('ACLS', false, 'PlantChamber', true), 'Columbus'}))
    %
    % to specify a locations, just replace the string 'Columbus' with one of
    % the following available strings:
    % 'US_Lab', 'Node1', 'Airlock', 'Node3', 'FGM', 'SM', 'Node2', 'Columbus', 'JEM', 'PMM'
    properties
        tiPLantLogs;
        tiLogIndexes;
    end
    
    methods
        function this = setup (ptConfigParams, tSolverParams)
            
%             ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestepObserver';
%             ttMonitorConfig.oTimeStepObserver.cParams = { 0 };
%             fAccuracy = 1e-8;
%             fMaxMassBalanceDifference = inf;
%             bSetBreakPoints = false;
%             ttMonitorConfig.oMassBalanceObserver.cParams = { fAccuracy, fMaxMassBalanceDifference, bSetBreakPoints };
            

            ttMonitorConfig.oLogger.cParams = {true, 20000};

            this@simulation.infrastructure('ISS_ARS_MultiStore', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Water content of Urine and Feces is based on BVAD, not all
            % possible components of both substances defined here
            trBaseCompositionUrine.H2O      = 0.9644;
            trBaseCompositionUrine.CH4N2O   = 0.0356;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Urine', trBaseCompositionUrine)
            
            trBaseCompositionFeces.H2O          = 0.7576;
            trBaseCompositionFeces.DietaryFiber = 0.2424;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Feces', trBaseCompositionFeces)
            
            trBaseCompositionBrine.H2O      = 0.8;
            trBaseCompositionBrine.C2H6O2N2 = 0.2;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Brine', trBaseCompositionBrine);
            
            trBaseCompositionBrine.H2O      = 0.44;
            trBaseCompositionBrine.C2H6O2N2 = 0.56;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'ConcentratedBrine', trBaseCompositionBrine);
            
            %% Creating the root object
            fFixedTS = 300;
            
            if isempty(ptConfigParams)
                simulations.ISS.systems.ISS_ARS_MultiStore(this.oSimulationContainer, 'ISS_ARS_MultiStore', fFixedTS, struct());
            else
                if isKey(ptConfigParams, 'sPlantLocation')
                    simulations.ISS.systems.ISS_ARS_MultiStore(this.oSimulationContainer, 'ISS_ARS_MultiStore', fFixedTS, ptConfigParams('tbCases'), ptConfigParams('sPlantLocation'));
                else
                    simulations.ISS.systems.ISS_ARS_MultiStore(this.oSimulationContainer, 'ISS_ARS_MultiStore', fFixedTS, ptConfigParams('tbCases'));
                end
            end
            
        end
        function configureMonitors(this)
            %% Logging for the modules of the ISS
            % written adaptiv so that it is simple to add additional modules
            % to the system. If you do not want to log/plot any of the
            % subsystem simply outcomment the code (but remember to do so in
            % the plotting as well, otherwise that will throw errors)
            
            oLogger = this.toMonitors.oLogger;
            
            %% Logging for the ISS modules
            
            csModules = {'Node1', 'Node2', 'Node3', 'PMM', 'FGM', 'Airlock', 'SM', 'US_Lab' 'JEM', 'Columbus'};
            csNumbers = {'1', '2', '3', '4', '5', '6', '7', '8' '9', '10'};
            for iModule = 1:length(csModules)
                
                oLogger.addValue(['ISS_ARS_MultiStore:s:', csModules{iModule}, '.aoPhases(1)'], 'fTemperature',                'K',  [csModules{iModule}, ' Temperature']);
                oLogger.addValue(['ISS_ARS_MultiStore:s:', csModules{iModule}, '.aoPhases(1)'], 'fPressure',                   'Pa', [csModules{iModule}, ' Pressure']);
                oLogger.addValue(['ISS_ARS_MultiStore:s:', csModules{iModule}, '.aoPhases(1)'], 'afPP(this.oMT.tiN2I.O2)',     'Pa', [csModules{iModule}, ' O2']);
                oLogger.addValue(['ISS_ARS_MultiStore:s:', csModules{iModule}, '.aoPhases(1)'], 'afPP(this.oMT.tiN2I.CO2)',    'Pa', [csModules{iModule}, ' CO2']);
                oLogger.addValue(['ISS_ARS_MultiStore:s:', csModules{iModule}, '.aoPhases(1)'], 'rRelHumidity',                '-',  [csModules{iModule}, ' RelativeHumidity']);
                %oLog.addValue(['ISS_ARS_MultiStore:s:', csModules{iModule}, '.aoPhases(1)'], 'fMass',                       'kg', [csModules{iModule}, ' Mass']);
                oLogger.addValue('ISS_ARS_MultiStore', ['afDewPointModules(' ,csNumbers{iModule},')'], 'K',   [csModules{iModule}, ' DewPoint']);
            end
            
            oLogger.addValue('ISS_ARS_MultiStore.oTimer',                                                              'fTimeStepFinal',            's',   'Timestep');
            
            %% Tank Masses
            % Water tank masses, currently no differentiation between the
            % russian and US segment is implemented. Would require more
            % information on the russian segment to do that
            oLogger.addValue('ISS_ARS_MultiStore:s:WSS.aoPhases(1)',            'fMass', 'kg', 'WSS Water');
            oLogger.addValue('ISS_ARS_MultiStore:s:UrineStorage.aoPhases(1)',   'fMass', 'kg', 'Urine Mass');
            oLogger.addValue('ISS_ARS_MultiStore:s:FecesStorage.aoPhases(1)',   'fMass', 'kg', 'Feces Mass');
            oLogger.addValue('ISS_ARS_MultiStore:s:FoodStore.aoPhases(1)',      'fMass', 'kg', 'Food Mass');
            
            %% CCAAs logging
            if this.oSimulationContainer.toChildren.ISS_ARS_MultiStore.tbCases.ModelInactiveSystems
                csCCAAs = {'CCAA_Node3', 'CCAA_USLab', 'CCAA_SM', 'CCAA_Airlock', 'CCAA_Node2', 'CCAA_JEM', 'CCAA_Columbus'};
            else
                csCCAAs = {'CCAA_Node3', 'CCAA_SM', 'CCAA_JEM', 'CCAA_Columbus'};
            end
            for iCCAA = 1:length(csCCAAs)
                sLabel = strrep(csCCAAs{iCCAA}, '_', ' ');
                oLogger.addValue(['ISS_ARS_MultiStore:c:', csCCAAs{iCCAA}, ':c:CCAA_CHX'],                             'fTotalHeatFlow',            'W',    ['Total Heat Flow ', sLabel]);
                oLogger.addValue(['ISS_ARS_MultiStore:c:', csCCAAs{iCCAA}, ':c:CCAA_CHX'],                             'fTotalCondensateHeatFlow',  'W',    ['Condensation Heat Flow ', sLabel]);
                oLogger.addValue(['ISS_ARS_MultiStore:c:', csCCAAs{iCCAA}],                                            'fTCCV_Angle',               '°',    ['TCCV Angle ', sLabel]);
                oLogger.addValue(['ISS_ARS_MultiStore:c:', csCCAAs{iCCAA}, '.toStores.CHX.toProcsP2P.CondensingHX'],  	'fFlowRate',                 'kg/s', ['Condensate Flow ', sLabel]);
                
                oLogger.addVirtualValue(['cumsum("Condensate Flow ', sLabel, '" .* "Timestep")'], 'kg', ['Condensate Mass ',  sLabel]);
            end
            
            
            %% SCRA logging
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toStores.CRA_Accumulator.toPhases.CO2',                  'fPressure',                 'Pa',   'SCRA CO_2 Accumulator Pressure');
            
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.CRA_CO2_In',                                  'fFlowRate',                 'kg/s', 'SCRA CO_2 Inlet');
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.CRA_H2_In',                                   'fFlowRate',                 'kg/s', 'SCRA H_2 Inlet');
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.Accumulator_To_CRA',                          'fFlowRate',                 'kg/s', 'SCRA CO_2 flow to Reactor');
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.H2_to_Sabatier',                              'fFlowRate',                 'kg/s', 'SCRA H_2 flow to Reactor');
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.H2_to_Vent',                                  'fFlowRate',                 'kg/s', 'SCRA H_2 flow to Vent');
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.CRA_RecWaterOut',                             'fFlowRate',                 'kg/s', 'SCRA recovered H_2O');
            
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.CRA_DryGastoVent.aoFlows(1,1)',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',	'kg/s', 'SCRA Vented CO2');
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.CRA_DryGastoVent.aoFlows(1,1)',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2)',	'kg/s', 'SCRA Vented H2');
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.CRA_DryGastoVent.aoFlows(1,1)',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',	'kg/s', 'SCRA Vented H2O');
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3.toBranches.CRA_DryGastoVent.aoFlows(1,1)',               'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CH4)',	'kg/s', 'SCRA Vented CH4');
            
            oLogger.addValue('ISS_ARS_MultiStore:c:SCRA_Node3',                                                        'fCurrentPowerConsumption',  'W',    'SCRA Power Consumption');
            
            oLogger.addVirtualValue('cumsum("SCRA Vented CO2"    .* "Timestep")', 'kg', 'SCRA Vented CO2 Mass');
            oLogger.addVirtualValue('cumsum("SCRA Vented H2"     .* "Timestep")', 'kg', 'SCRA Vented H2 Mass');
            oLogger.addVirtualValue('cumsum("SCRA Vented H2O"    .* "Timestep")', 'kg', 'SCRA Vented H2O Mass');
            oLogger.addVirtualValue('cumsum("SCRA Vented CH4"    .* "Timestep")', 'kg', 'SCRA Vented CH4 Mass');
            
            oLogger.addVirtualValue('cumsum("SCRA recovered H_2O" .* "Timestep")', 'kg', 'SCRA Recovered H2O Mass');
            
            %% WPA Logging
            oLogger.addValue('ISS_ARS_MultiStore:c:WPA.toStores.WasteWater.toPhases.Water',            'fMass',        'kg',   'WPA Waste Water');
            oLogger.addValue('ISS_ARS_MultiStore:c:WPA.toBranches.Inlet',                              'fFlowRate',    'kg/s', 'WPA Waste Water Inflow');
            oLogger.addValue('ISS_ARS_MultiStore:c:WPA.toBranches.Check_to_WasteWater',                'fFlowRate',    'kg/s', 'WPA Water Reflow after Check');
            oLogger.addValue('ISS_ARS_MultiStore:c:WPA.toBranches.Outlet',                             'fFlowRate',    'kg/s', 'WPA Potable Water Outflow');
            oLogger.addValue('ISS_ARS_MultiStore:c:WPA.toBranches.Outlet.aoFlowProcs',                 'fPPM',         'ppm',  'WPA PPM Outlet');
            oLogger.addValue('ISS_ARS_MultiStore:c:WPA.toBranches.Outlet.aoFlowProcs',                 'fTOC',         '-',    'WPA TOC Outlet');
            
            oLogger.addValue('ISS_ARS_MultiStore:c:WPA.toStores.Rack_Air.toPhases.Water.toManips.substance',  	'this.afFlowRates(this.oMT.tiN2I.O2)',         'kg/s',    'WPA O2 Consumption');
            oLogger.addValue('ISS_ARS_MultiStore:c:WPA.toStores.Rack_Air.toPhases.Water.toManips.substance',  	'this.afFlowRates(this.oMT.tiN2I.CO2)',        'kg/s',    'WPA CO2 Production');
            
            %% UPA + BPA Logging
            oLogger.addValue('ISS_ARS_MultiStore.toChildren.UPA.toBranches.Outlet',                    'fFlowRate',	'kg/s', 'UPA Water Flow');
            oLogger.addValue('ISS_ARS_MultiStore.toChildren.UPA.toBranches.BrineOutlet',               'fFlowRate',	'kg/s', 'UPA Brine Flow');
            oLogger.addValue('ISS_ARS_MultiStore.toChildren.UPA.toStores.WSTA.toPhases.Urine',         'fMass',        'kg',   'UPA WSTA Mass');
            oLogger.addValue('ISS_ARS_MultiStore.toChildren.UPA.toStores.ARTFA.toPhases.Brine',        'fMass',        'kg',   'UPA ARTFA Mass');
            
            oLogger.addValue('ISS_ARS_MultiStore.toChildren.BPA.toStores.Bladder.toProcsP2P.WaterP2P',                             'fFlowRate',	'kg/s', 'BPA Water Flow');
            oLogger.addValue('ISS_ARS_MultiStore.toChildren.BPA.toStores.Bladder.toPhases.Brine',                                  'fMass',        'kg',   'BPA Bladder Mass');
            oLogger.addValue('ISS_ARS_MultiStore.toChildren.BPA.toStores.ConcentratedBrineDisposal.toPhases.ConcentratedBrine',  	'fMass',        'kg',   'BPA Concentrated Brine Mass');
            
            
            oLogger.addVirtualValue('cumsum("UPA Water Flow"    .* "Timestep")', 'kg', 'UPA Produced Water');
            oLogger.addVirtualValue('cumsum("UPA Brine Flow"    .* "Timestep")', 'kg', 'UPA Produced Brine');
            oLogger.addVirtualValue('cumsum("BPA Water Flow"    .* "Timestep")', 'kg', 'BPA Produced Water');
            
            %% Mass and Temperature logging for all phases (can be usefull for debugging)
%             oISS_ARS_MultiStore = this.oSimulationContainer.toChildren.ISS_ARS_MultiStore;
% 
%             csStoreNames = fieldnames(oISS_ARS_MultiStore.toStores);
%             for iStore = 1:length(csStoreNames)
%                 for iPhase = 1:length(oISS_ARS_MultiStore.toStores.(csStoreNames{iStore}).aoPhases)
%                     csPhaseNames = fieldnames(oISS_ARS_MultiStore.toStores.(csStoreNames{iStore}).toPhases);
% 
%                     oLog.addValue(['ISS_ARS_MultiStore:s:', csStoreNames{iStore}, '.toPhases.' csPhaseNames{iPhase}], 'fMass', 'kg', ['ISS ', csStoreNames{iStore}, csPhaseNames{iPhase}, ' Mass']);
% 
%                     oLog.addValue(['ISS_ARS_MultiStore:s:', csStoreNames{iStore}, '.toPhases.' csPhaseNames{iPhase}], 'fTemperature', 'K', ['ISS ', csStoreNames{iStore}, csPhaseNames{iPhase}, ' Temperature']);
% 
%                 end
%             end
% 
%             csChildNames = fieldnames(oISS_ARS_MultiStore.toChildren);
%             for iChildren = 1:length(csChildNames)
%                 csStoreNames = fieldnames(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores);
%                 for iStore = 1:length(csStoreNames)
%                     for iPhase = 1:length(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores.(csStoreNames{iStore}).aoPhases)
%                         csPhaseNames = fieldnames(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores.(csStoreNames{iStore}).toPhases);
% 
%                         oLog.addValue(['ISS_ARS_MultiStore:c:', csChildNames{iChildren}, ':s:', csStoreNames{iStore}, '.toPhases.' csPhaseNames{iPhase}], 'fMass', 'kg', [csChildNames{iChildren}, csStoreNames{iStore}, csPhaseNames{iPhase}, ' Mass']);
% 
%                         oLog.addValue(['ISS_ARS_MultiStore:c:', csChildNames{iChildren}, ':s:', csStoreNames{iStore}, '.toPhases.' csPhaseNames{iPhase}], 'fTemperature', 'K', [csChildNames{iChildren}, csStoreNames{iStore}, csPhaseNames{iPhase}, ' Temperature']);
% 
%                     end
%                 end
%             end
             
            %% ACLS Specific logging & plotting
            if this.oSimulationContainer.toChildren.ISS_ARS_MultiStore.tbCases.ACLS
                
                for iBed = 1:3
                    oLogger.addValue(['ISS_ARS_MultiStore:c:ACLS:s:CCA_Bed',num2str(iBed),'.toPhases.ResineAB',num2str(iBed)],    'afMass(this.oMT.tiN2I.H2O)',   'kg',    ['ACLS Bed ',num2str(iBed),' Absorbed Mass H2O']);
                    oLogger.addValue(['ISS_ARS_MultiStore:c:ACLS:s:CCA_Bed',num2str(iBed),'.toPhases.ResineAB',num2str(iBed)],    'afMass(this.oMT.tiN2I.CO2)',   'kg',    ['ACLS Bed ',num2str(iBed),' Absorbed Mass CO2']);
                end
                
                oLogger.addValue('ISS_ARS_MultiStore:s:ACLS_Water.toPhases.ACLS_Water_Phase', 'fMass',	'kg',     'ACLS Supply Water');
                
                % Condensate Massflows of the CHXs
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS:s:CRA_WaterRec.toProcsP2P.CondensingHX',               'fFlowRate',	'kg/s',     'Sabatier Condensate Flowrate');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS:s:CCA_WaterSeperator.toProcsP2P.CHX_Air_p2p',          'fFlowRate',	'kg/s',     'Air Condensate Flowrate');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS:s:CCA_CO2_WaterRecovery.toProcsP2P.CHX_CO2_p2p',       'fFlowRate',	'kg/s',     'CO2 Condensate Flow Rate');
                
                % Sabatier vented mass flow and composition (CO2, CH4, H2O, O2,
                % N2, H2)
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CRA_DryGastoVent.aoFlows(1)',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.N2)', 	'kg/s',     'ACLS Vent FlowRate N2');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CRA_DryGastoVent.aoFlows(1)',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)', 	'kg/s',     'ACLS Vent FlowRate O2');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CRA_DryGastoVent.aoFlows(1)',   	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2)', 	'kg/s',     'ACLS Vent FlowRate H2');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CRA_DryGastoVent.aoFlows(1)',    	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 	'kg/s',     'ACLS Vent FlowRate CO2');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CRA_DryGastoVent.aoFlows(1)',     	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 	'kg/s',     'ACLS Vent FlowRate H2O');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CRA_DryGastoVent.aoFlows(1)',   	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CH4)', 	'kg/s',     'ACLS Vent FlowRate CH4');
                
                % ACLS overall CO2 and H2O In- and Outlet flowrates
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CCA_AirInlet.aoFlows(1)',           'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 	'kg/s',     'ACLS CO2 Inlet FlowRate');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CCA_AirInlet.aoFlows(1)',           'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',  'kg/s',     'ACLS H2O Inlet FlowRate');
                
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CCA_AirOutlet.aoFlows(1)',          'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',	'kg/s',     'ACLS CO2 Outlet FlowRate');
                oLogger.addValue('ISS_ARS_MultiStore:c:ACLS.toBranches.CCA_AirOutlet.aoFlows(1)',          'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',	'kg/s',     'ACLS H2O Outlet FlowRate');
            end
            
            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                   PLANT MODULE LOGGING                  %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if this.oSimulationContainer.toChildren.ISS_ARS_MultiStore.tbCases.PlantChamber
                oISS = this.oSimulationContainer.toChildren.ISS_ARS_MultiStore;
                this.tiPLantLogs = struct();

                for iPlant = 1:length(oISS.csPlants)
                    this.tiPLantLogs(iPlant).miMass                  = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miEdibleMass            = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miWaterUptake           = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miO2                    = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miCO2                   = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miTranspiration         = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miEdibleGrowth          = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miInedibleGrowth        = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miNO3UptakeStorage      = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miNO3UptakeStructure    = zeros(1:length(oISS.miSubcultures(iPlant)),1);
                    this.tiPLantLogs(iPlant).miNO3UptakeEdible       = zeros(1:length(oISS.miSubcultures(iPlant)),1);

                    csMass                 = cell(1, length(oISS.miSubcultures(iPlant)));
                    csEdibleMass           = cell(1, length(oISS.miSubcultures(iPlant)));
                    csWaterUptake          = cell(1, length(oISS.miSubcultures(iPlant)));
                    csO2                   = cell(1, length(oISS.miSubcultures(iPlant)));
                    csCO2                  = cell(1, length(oISS.miSubcultures(iPlant)));
                    csTranspiration        = cell(1, length(oISS.miSubcultures(iPlant)));
                    csEdibleGrowth         = cell(1, length(oISS.miSubcultures(iPlant)));
                    csInedibleGrowth       = cell(1, length(oISS.miSubcultures(iPlant)));
                    csNO3UptakeStorage     = cell(1, length(oISS.miSubcultures(iPlant)));
                    csNO3UptakeStructure   = cell(1, length(oISS.miSubcultures(iPlant)));
                    csNO3UptakeEdible      = cell(1, length(oISS.miSubcultures(iPlant)));

                    for iSubculture = 1:oISS.miSubcultures(iPlant)
                        sCultureName = [oISS.csPlants{iPlant},'_', num2str(iSubculture)];

                        this.tiPLantLogs(iPlant).miMass(iSubculture)                 = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName, '.toStores.Plant_Culture.toPhases.Plants'], 'fMass',                                   'kg',   [sCultureName, ' Mass']);
                        this.tiPLantLogs(iPlant).miEdibleMass(iSubculture)           = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName, '.toStores.Plant_Culture.toPhases.Plants'], ['this.afMass(this.oMT.tiN2I.', oISS.csPlants{iPlant}, ')'],     'kg',   [sCultureName, ' Edible Biomass']);

                        this.tiPLantLogs(iPlant).miWaterUptake(iSubculture)          = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],                                            'fWaterConsumptionRate',                   'kg/s', [sCultureName, ' Water Consumption Rate']);

                        this.tiPLantLogs(iPlant).miO2(iSubculture)                   = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],  'this.tfGasExchangeRates.fO2ExchangeRate',          'kg/s', [sCultureName, ' O2 Rate']);
                        this.tiPLantLogs(iPlant).miCO2(iSubculture)                  = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],  'this.tfGasExchangeRates.fCO2ExchangeRate',         'kg/s', [sCultureName, ' CO2 Rate']);
                        this.tiPLantLogs(iPlant).miTranspiration(iSubculture)        = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],  'this.tfGasExchangeRates.fTranspirationRate',       'kg/s', [sCultureName, ' Transpiration Rate']);
                        this.tiPLantLogs(iPlant).miEdibleGrowth(iSubculture)         = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],  'this.tfBiomassGrowthRates.fGrowthRateInedible',    'kg/s', [sCultureName, ' Inedible Growth Rate']);
                        this.tiPLantLogs(iPlant).miInedibleGrowth(iSubculture)       = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],  'this.tfBiomassGrowthRates.fGrowthRateEdible',      'kg/s', [sCultureName, ' Edible Growth Rate']);

                        this.tiPLantLogs(iPlant).miNO3UptakeStorage(iSubculture)     = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],  'this.tfUptakeRate_Storage.NO3',                     'kg/s', [sCultureName, ' NO3 Uptake Storage']);
                        this.tiPLantLogs(iPlant).miNO3UptakeStructure(iSubculture)	 = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],  'this.tfUptakeRate_Structure.NO3',                	'kg/s', [sCultureName, ' NO3 Uptake Structure']);
                        this.tiPLantLogs(iPlant).miNO3UptakeEdible(iSubculture)      = oLogger.addValue(['ISS_ARS_MultiStore.toChildren.', sCultureName],  'this.tfUptakeRate_Structure.fEdibleUptakeNO3',    	'kg/s', [sCultureName, ' NO3 Uptake Edible']);

                        csMass{iSubculture}                 = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miMass(iSubculture)).sLabel,'" +'];
                        csEdibleMass{iSubculture}           = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miEdibleMass(iSubculture)).sLabel,'" +'];
                        csWaterUptake{iSubculture}          = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miWaterUptake(iSubculture)).sLabel,'" +'];
                        csO2{iSubculture}                   = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miO2(iSubculture)).sLabel,'" +'];
                        csCO2{iSubculture}                  = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miCO2(iSubculture)).sLabel,'" +'];
                        csTranspiration{iSubculture}        = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miTranspiration(iSubculture)).sLabel,'" +'];
                        csEdibleGrowth{iSubculture}         = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miEdibleGrowth(iSubculture)).sLabel,'" +'];
                        csInedibleGrowth{iSubculture}       = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miInedibleGrowth(iSubculture)).sLabel,'" +'];
                        csNO3UptakeStorage{iSubculture}     = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miNO3UptakeStorage(iSubculture)).sLabel,'" +'];
                        csNO3UptakeStructure{iSubculture}   = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miNO3UptakeStructure(iSubculture)).sLabel,'" +'];
                        csNO3UptakeEdible{iSubculture}      = ['"', oLogger.tLogValues(this.tiPLantLogs(iPlant).miNO3UptakeEdible(iSubculture)).sLabel,'" +'];
                    end

                    sMass = strjoin(csMass);
                    sMass(end) = [];
                    this.tiLogIndexes.Plants.Biomass{iPlant}            = oLogger.addVirtualValue( sMass,   'kg', [oISS.csPlants{iPlant} ' current Biomass']);

                    sEdibleMass = strjoin(csEdibleMass);
                    sEdibleMass(end) = [];
                    this.tiLogIndexes.Plants.EdibleBiomass{iPlant}      = oLogger.addVirtualValue( sEdibleMass,   'kg', [oISS.csPlants{iPlant} ' current Edible Biomass']);

                    sWaterUptake = strjoin(csWaterUptake);
                    sWaterUptake(end) = [];
                    this.tiLogIndexes.Plants.WaterUptakeRate{iPlant}    = oLogger.addVirtualValue( sWaterUptake,   'kg/s', [oISS.csPlants{iPlant} ' Water Uptake']);
                    this.tiLogIndexes.Plants.WaterUptake{iPlant}        = oLogger.addVirtualValue(['cumsum((', sWaterUptake,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' Water Uptake Mass']);

                    sO2 = strjoin(csO2);
                    sO2(end) = [];
                    this.tiLogIndexes.Plants.OxygenRate{iPlant}         = oLogger.addVirtualValue( sO2,   'kg/s', [oISS.csPlants{iPlant} ' O2 Exchange']);
                    this.tiLogIndexes.Plants.Oxygen{iPlant}             = oLogger.addVirtualValue(['cumsum((', sO2,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' O2 Exchange Mass']);

                    sCO2 = strjoin(csCO2);
                    sCO2(end) = [];
                    this.tiLogIndexes.Plants.CO2Rate{iPlant}            = oLogger.addVirtualValue( sCO2,   'kg/s', [oISS.csPlants{iPlant} ' CO2 Exchange']);
                    this.tiLogIndexes.Plants.CO2{iPlant}                = oLogger.addVirtualValue(['cumsum((', sCO2,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' CO2 Exchange Mass']);

                    sTranspiration = strjoin(csTranspiration);
                    sTranspiration(end) = [];
                    this.tiLogIndexes.Plants.TranspirationRate{iPlant}  = oLogger.addVirtualValue( sTranspiration,   'kg/s', [oISS.csPlants{iPlant} ' Transpiration']);
                    this.tiLogIndexes.Plants.Transpiration{iPlant}      = oLogger.addVirtualValue(['cumsum((', sTranspiration,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' Transpiration Mass']);

                    sEdibleGrowth = strjoin(csEdibleGrowth);
                    sEdibleGrowth(end) = [];
                    this.tiLogIndexes.Plants.EdibleGrowthRate{iPlant}   = oLogger.addVirtualValue( sEdibleGrowth,   'kg/s', [oISS.csPlants{iPlant} ' Edible Growth']);
                    this.tiLogIndexes.Plants.EdibleBiomassCum{iPlant} 	= oLogger.addVirtualValue(['cumsum((', sEdibleGrowth,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' total Edible Mass']);

                    sInedibleGrowth = strjoin(csInedibleGrowth);
                    sInedibleGrowth(end) = [];
                    this.tiLogIndexes.Plants.InedibleGrowthRate{iPlant} = oLogger.addVirtualValue( sInedibleGrowth,   'kg/s', [oISS.csPlants{iPlant} ' Inedible Growth']);
                    this.tiLogIndexes.Plants.InedibleBiomassCum{iPlant} = oLogger.addVirtualValue(['cumsum((', sInedibleGrowth,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' total Inedible Mass']);

                    sNO3UptakeStorage = strjoin(csNO3UptakeStorage);
                    sNO3UptakeStorage(end) = [];
                    this.tiLogIndexes.Plants.NitrateStorageRate{iPlant} = oLogger.addVirtualValue( sNO3UptakeStorage,   'kg/s', [oISS.csPlants{iPlant} ' NO3 Storage Uptake']);
                    this.tiLogIndexes.Plants.NitrateStorage{iPlant}     = oLogger.addVirtualValue(['cumsum((', sNO3UptakeStorage,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' NO3 Storage Uptake Mass']);

                    sNO3UptakeStructure = strjoin(csNO3UptakeStructure);
                    sNO3UptakeStructure(end) = [];
                    this.tiLogIndexes.Plants.NitrateStructureRate{iPlant} = oLogger.addVirtualValue( sNO3UptakeStructure,   'kg/s', [oISS.csPlants{iPlant} ' NO3 Structure Uptake']);
                    this.tiLogIndexes.Plants.Nitratestructure{iPlant}   = oLogger.addVirtualValue(['cumsum((', sNO3UptakeStructure,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' NO3 Structure Uptake Mass']);

                    sNO3UptakeEdible = strjoin(csNO3UptakeEdible);
                    sNO3UptakeEdible(end) = [];
                    this.tiLogIndexes.Plants.NitrateEdibleRate{iPlant}  = oLogger.addVirtualValue( sNO3UptakeEdible,   'kg/s', [oISS.csPlants{iPlant} ' NO3 Edible Uptake']);
                    this.tiLogIndexes.Plants.NitrateEdible{iPlant}      = oLogger.addVirtualValue(['cumsum((', sNO3UptakeEdible,')	.* "Timestep")'], 'kg', [oISS.csPlants{iPlant} ' NO3 Edible Uptake Mass']);
                end
            end
            
            %% Simulation length
            %             this.iMassLogInterval = 10000;
            if isKey(this.oSimulationContainer.oCfgParams.ptConfigParams, 'fSimTime')
                this.fSimTime = this.oSimulationContainer.oCfgParams.ptConfigParams('fSimTime');
            else
                this.fSimTime = 3600 * 24 * 7; % e.g. 321 hours
            end
            this.iSimTicks = 600;
            this.bUseTime = true;
        end
        
        
        %% Plotting the results
        
        function plot(this, mfTime)
            
            close all
            try
                this.toMonitors.oLogger.readFromMat;
            catch
                disp('no data outputted yet')
            end
            %Variable containing the names for all modules of the ISS
            csModules = {'Node1', 'Node2', 'Node3', 'PMM', 'FGM', 'Airlock', 'SM', 'US_Lab' 'JEM', 'Columbus'};
            mSubplotNumber = [8, 10, 3, 4, 7, 13, 6, 9, 5, 15];
            %for loop that looks up the logging indices for the relative
            %humidity, CO2 and O2 for each module of the ISS
            for iIndex = 1:length(this.toMonitors.oLogger.tLogValues)
                for iModule = 1:length(csModules)
                    
                    sRelativeHum = [csModules{iModule},' RelativeHumidity'];
                    sCO2 = [csModules{iModule},' CO2'];
                    sO2 = [csModules{iModule},' O2'];
                    sPressure = [csModules{iModule},' Pressure'];
                    sTemperature = [csModules{iModule},' Temperature'];
                    sDewPoint = [csModules{iModule},' DewPoint'];
                    
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, sRelativeHum)
                        tIndices.(csModules{iModule}).RelativeHumidity = iIndex;
                    end
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, sCO2)
                        tIndices.(csModules{iModule}).CO2 = iIndex;
                    end
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, sO2)
                        tIndices.(csModules{iModule}).O2 = iIndex;
                    end
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, sPressure)
                        tIndices.(csModules{iModule}).Pressure = iIndex;
                    end
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, sTemperature)
                        tIndices.(csModules{iModule}).Temperature = iIndex;
                    end
                    if strcmp(this.toMonitors.oLogger.tLogValues(iIndex).sLabel, sDewPoint)
                        tIndices.(csModules{iModule}).DewPoint = iIndex;
                    end
                end
            end
            
            afTime = this.toMonitors.oLogger.afTime;
            
            %% Plotting of the ISS Module Values
            mMonitors = get(0,'MonitorPositions');
            iMonitors = size(mMonitors);
            iMonitors = iMonitors(1);
            %             if iMonitors == 2
            %                 iFigureStartPositionX = mMonitors(2,1);
            %             else
            %                 iFigureStartPositionX = mMonitors(1,1);
            %             end
            
            iFigureStartPositionX = mMonitors(1,1);
            
            PlotScale = 1.3;
            TitlePos = 0.9;
            
            csPlots = { 'Pressure', 'RelativeHumidity', 'CO2', 'O2', 'DewPoint'}; %'Temperature',
            
            for iPlot = 1:length(csPlots)
                
                mLogData = zeros(length(this.toMonitors.oLogger.mfLog), length(csModules));
                for iModule = 1:length(csModules)
                    mLogData(:,iModule) = this.toMonitors.oLogger.mfLog(:,tIndices.(csModules{iModule}).(csPlots{iPlot}));
                end
                mLogData(isnan(mLogData(:,1)),:)=[];
                
                LowerYLimit = min(min(mLogData));
                UpperYLimit = max(max(mLogData));
                
                figure1 = figure('name', ['ISS ', csPlots{iPlot}],'Position',[iFigureStartPositionX 1 1280 1024]);
                
                switch csPlots{iPlot}
                    case 'Temperature'
                        csLegend = {"y-axis: Temperature / K" + newline + "x-axis: Time / h"};
                    case 'Pressure'
                        csLegend = {"y-axis: Absolute Pressure / Pa" + newline + "x-axis: Time / h"};
                    case 'RelativeHumidity'
                        csLegend = {"y-axis: Relative Humidity / -" + newline + "x-axis: Time / h"};
                    case 'CO2'
                        csLegend = {"y-axis: Partial Pressure CO_2 / Pa" + newline + "x-axis: Time / h"};
                    case 'O2'
                        csLegend = {"y-axis: Partial Pressure O_2 / Pa" + newline + "x-axis: Time / h"};
                    case 'DewPoint'
                        csLegend = {"y-axis: Dew Point / K" + newline + "x-axis: Time / h"};
                end
                
                annotation(figure1,'textbox',...
                    [0.15 0.9 0.15 0.03],...
                    'String',csLegend,...
                    'FitBoxToText','on',...
                    'EdgeColor',[1 1 1]);
                
                for iModule = 1:length(csModules)
                    
                    h = subplot(3,5,mSubplotNumber(iModule));
                    plot((afTime./3600), mLogData(:,iModule))
                    grid on
                    if nargin == 2
                        xlim(mfTime);
                    else
                        xlim([0, max(afTime./3600)]);
                    end
                    if LowerYLimit ~= UpperYLimit
                        ylim([LowerYLimit, UpperYLimit]);
                    end
                    if iModule == 8
                        t = title('US Lab');
                    else
                        t = title(csModules{iModule});
                    end
                    ax = gca;
                    if (mSubplotNumber(iModule) ~= 3) && (mSubplotNumber(iModule) ~= 6) && (mSubplotNumber(iModule) ~= 13)
                        ax.YTickLabel = {''};
                    end
                    ax.YTickMode = 'manual';
                    if (mSubplotNumber(iModule) ~= 6) && (mSubplotNumber(iModule) ~= 7) && (mSubplotNumber(iModule) ~= 9) && (mSubplotNumber(iModule) ~= 13) && (mSubplotNumber(iModule) ~= 15)
                        ax.XTickLabel = {''};
                    end
                    Pos = get(h, 'Position');
                    Pos(3) = Pos(3)*PlotScale;
                    Pos(4) = Pos(4)*PlotScale;
                    set(h,'Position',Pos);
                    tPos = get(t, 'Position');
                    tPos(2) = LowerYLimit+((UpperYLimit-LowerYLimit) * TitlePos);
                    set(t,'Position',tPos);
                end
            end
            
            %% Options for other plots
            oPlotter = plot@simulation.infrastructure(this);
            
            % you can specify additional parameters for the plots, for
            % example you can define the unit for the time axis that should
            % be used (s, min, h, d, weeks possible)
            tPlotOptions.sTimeUnit = 'hours';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
            
            %% Tank Masses
            coPlots = cell.empty();
            coPlots{1,1} = oPlotter.definePlot({'"WSS Water"'},                     'Potable Water',  	tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"WPA Waste Water"'},               'Waste Water',  	tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Food Mass"'},                     'Food',             tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"Feces Mass"', '"Urine Mass"', '"UPA WSTA Mass"', '"UPA ARTFA Mass"', '"BPA Bladder Mass"', '"BPA Concentrated Brine Mass"'}, 	'Waste',            tPlotOptions);
            
            oPlotter.defineFigure(coPlots,         'Tank Masses',          tFigureOptions);
            
            %% CCAA plotting
            if this.oSimulationContainer.toChildren.ISS_ARS_MultiStore.tbCases.ModelInactiveSystems
                csCCAAs =       {'CCAA Node3', 'CCAA USLab', 'CCAA SM', 'CCAA Airlock', 'CCAA Node2', 'CCAA JEM', 'CCAA Columbus'};
                mSubplotNumber = [1,1;          1,2;          1,3;      2,1;            2,2;          2,3;         3,1];
            else
                csCCAAs =       {'CCAA SM',     'CCAA Node3',   'CCAA JEM', 'CCAA Columbus'};
                mSubplotNumber = [1,1;          1,2;            2,1;        2,2;];
            end
            % mSubplotNumber = [1,3;          2,4;          2,1;      3,3;            2,5;          1,5;         3,5];
            for iCCAA = 1:length(csCCAAs)
                csNames = {['"Total Heat Flow ', csCCAAs{iCCAA}, '"'], ['"Condensation Heat Flow ', csCCAAs{iCCAA}, '"']};
                
                coPlotsHeatFlows{       mSubplotNumber(iCCAA,1), mSubplotNumber(iCCAA,2)} = oPlotter.definePlot(csNames,                                      ['Heatflows ' ,csCCAAs{iCCAA}],       tPlotOptions);
                coPlotsTCCVAngles{      mSubplotNumber(iCCAA,1), mSubplotNumber(iCCAA,2)} = oPlotter.definePlot({['"TCCV Angle ', csCCAAs{iCCAA}, '"']},        ['TCCV Angle ' ,csCCAAs{iCCAA}],      tPlotOptions);
                coPlotsCondensateFlow{  mSubplotNumber(iCCAA,1), mSubplotNumber(iCCAA,2)} = oPlotter.definePlot({['"Condensate Flow ', csCCAAs{iCCAA}, '"']},   ['Condensate Flow ' ,csCCAAs{iCCAA}], tPlotOptions);
                coPlotsCondensateMass{  mSubplotNumber(iCCAA,1), mSubplotNumber(iCCAA,2)} = oPlotter.definePlot({['"Condensate Mass ', csCCAAs{iCCAA}, '"']},   ['Condensate Mass ' ,csCCAAs{iCCAA}], tPlotOptions);
                
            end
            
            oPlotter.defineFigure(coPlotsHeatFlows,         'CCAA Heat Flows',          tFigureOptions);
            oPlotter.defineFigure(coPlotsTCCVAngles,        'CCAA Anlges',              tFigureOptions);
            oPlotter.defineFigure(coPlotsCondensateFlow,    'CCAA Condensate Flows',    tFigureOptions);
            oPlotter.defineFigure(coPlotsCondensateMass,    'CCAA Condensate Mass',    tFigureOptions);
            
            %% SCRA plotting
            csSCRAFlowRates     = {'"SCRA CO_2 Inlet"', '"SCRA H_2 Inlet"', '"SCRA CO_2 flow to Reactor"', '"SCRA H_2 flow to Reactor"', '"SCRA H_2 flow to Vent"', '"SCRA recovered H_2O"'};
            csVentedFlowRates   = {'"SCRA Vented CO2"', '"SCRA Vented H2"', '"SCRA Vented H2O"', '"SCRA Vented CH4"'};
            csVentedMasses      = {'"SCRA Vented CO2 Mass"', '"SCRA Vented H2 Mass"', '"SCRA Vented H2O Mass"', '"SCRA Vented CH4 Mass"', '"SCRA Recovered H2O Mass"'};
            coPlots = cell.empty();
            coPlots{1,1} = oPlotter.definePlot({'"SCRA CO_2 Accumulator Pressure"'}, 	'Sabatier Accumulator Pressure',  	tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csSCRAFlowRates,                         'Sabatier Reactor Flow Rates',  	tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csVentedFlowRates,                       'Sabatier Vented Flow Rates',       tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(csVentedMasses,                          'Sabatier Vented Masses',           tPlotOptions);
            
            oPlotter.defineFigure(coPlots,         'Sabatier',          tFigureOptions);
            
            %% WPA, UPA + BPA
            csWPAFlowRates     = {'"WPA Waste Water Inflow"', '"WPA Water Reflow after Check"', '"WPA Potable Water Outflow"'};
            csWPAReactorFlows  = {'"WPA O2 Consumption"', '"WPA CO2 Production"'};
            coPlots = cell.empty();
            coPlots{1,1} = oPlotter.definePlot({'"WPA Waste Water"'},                               'WPA Waste Water Mass',  	tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(csWPAFlowRates,                                      'WPA Flow Rates',           tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(csWPAReactorFlows,                                   'WPA Reactor Flow Rates',   tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"WPA PPM Outlet"', '"WPA TOC Outlet"'},            'WPA Water Quality',        tPlotOptions);
            coPlots{3,1} = oPlotter.definePlot({'"UPA Produced Water"', '"UPA Produced Brine"'},    'UPA',                      tPlotOptions);
            coPlots{3,2} = oPlotter.definePlot({'"BPA Produced Water"'},                            'BPA',                      tPlotOptions);
            
            oPlotter.defineFigure(coPlots,         'WPA, UPA + BPA',          tFigureOptions);
            
            %% Plotting for ACLS
            if this.oSimulationContainer.toChildren.ISS_ARS_MultiStore.tbCases.ACLS
                
                csNamesPartialMass      = cell(3,2);
                for iBed = 1:3
                    csNamesPartialMass {iBed,1}     = ['"ACLS Bed ',num2str(iBed),' Absorbed Mass H2O"'];
                    csNamesPartialMass {iBed,2}     = ['"ACLS Bed ',num2str(iBed),' Absorbed Mass CO2"'];
                end
                coPlots = [];
                coPlots{1,1} = oPlotter.definePlot(csNamesPartialMass(:,1),     'Absorbed Mass CO2 ACLS', tPlotOptions);
                coPlots{1,2} = oPlotter.definePlot(csNamesPartialMass(:,2),     'Absorbed Mass H2O ACLS', tPlotOptions);

                csNames = {'"ACLS Vent FlowRate N2"', '"ACLS Vent FlowRate O2"', '"ACLS Vent FlowRate H2"', '"ACLS Vent FlowRate CO2"', '"ACLS Vent FlowRate H2O"', '"ACLS Vent FlowRate CH4"'};
                coPlots{2,1} = oPlotter.definePlot(csNames,     'Vent Flowrates', tPlotOptions);
                
                csNames = {'"ACLS CO2 Inlet FlowRate"', '"ACLS CO2 Outlet FlowRate"'};
                coPlots{2,2} = oPlotter.definePlot(csNames,     'ACLS CO2 Flowrates', tPlotOptions);
                
                csNames = {'"ACLS H2O Inlet FlowRate"', '"ACLS H2O Outlet FlowRate"'};
                coPlots{3,1} = oPlotter.definePlot(csNames,     'ACLS H2O Flowrates', tPlotOptions);
                
%                 csNames = {'"ACLS Supply Water"'};
%                 coPlots{3,2} = oPlotter.definePlot(csNames,     'ACLS Supply Water', tPlotOptions);
                
                oPlotter.defineFigure(coPlots,  'ACLS Plots', tFigureOptions);
            end
            
            

            %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%                   PLANT MODULE PLOTTING                 %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Plots the total water that was consumed by the plants
            if this.oSimulationContainer.toChildren.ISS_ARS_MultiStore.tbCases.PlantChamber
                oISS = this.oSimulationContainer.toChildren.ISS_ARS_MultiStore;
                for iPlant = 1:length(oISS.csPlants)

                    coPlot = cell(0);
                    coPlot{1,1} = oPlotter.definePlot(this.tiLogIndexes.Plants.Biomass(iPlant),             'Current Biomass',              tPlotOptions);
                    coPlot{1,2} = oPlotter.definePlot(this.tiLogIndexes.Plants.EdibleBiomassCum(iPlant),    'Cumulative Edible Biomass',    tPlotOptions);
                    coPlot{1,3} = oPlotter.definePlot(this.tiLogIndexes.Plants.InedibleBiomassCum(iPlant),  'Cumulative Inedible Biomass',	tPlotOptions);
                    coPlot{2,1} = oPlotter.definePlot(this.tiLogIndexes.Plants.EdibleBiomass(iPlant),       'Current Edible Biomass',       tPlotOptions);
                    coPlot{2,2} = oPlotter.definePlot(this.tiLogIndexes.Plants.EdibleGrowthRate(iPlant),  	'Current Edible Growth Rate',   tPlotOptions);
                    coPlot{2,3} = oPlotter.definePlot(this.tiLogIndexes.Plants.InedibleGrowthRate(iPlant), 	'Current Inedible Growth Rate', tPlotOptions);

                    oPlotter.defineFigure(coPlot,       ['Plant Biomass ', oISS.csPlants{iPlant}]);

                    coPlot = cell(0);
                    coPlot{1,1} = oPlotter.definePlot(this.tiLogIndexes.Plants.WaterUptakeRate(iPlant),  	'Current Water Uptake',     	tPlotOptions);
                    coPlot{1,2} = oPlotter.definePlot(this.tiLogIndexes.Plants.TranspirationRate(iPlant),  	'Current Transpiration',     	tPlotOptions);
                    coPlot{1,3} = oPlotter.definePlot(this.tiLogIndexes.Plants.OxygenRate(iPlant),          'Current Oxygen Production',    tPlotOptions);
                    coPlot{1,4} = oPlotter.definePlot(this.tiLogIndexes.Plants.CO2Rate(iPlant),             'Curent CO_2 Consumption',      tPlotOptions);
                    coPlot{2,1} = oPlotter.definePlot(this.tiLogIndexes.Plants.WaterUptake(iPlant),         'Cumulative Water Uptake',      tPlotOptions);
                    coPlot{2,2} = oPlotter.definePlot(this.tiLogIndexes.Plants.Transpiration(iPlant),      	'Cumulative Transpiration',     tPlotOptions);
                    coPlot{2,3} = oPlotter.definePlot(this.tiLogIndexes.Plants.Oxygen(iPlant),              'Cumulative Oxygen',            tPlotOptions);
                    coPlot{2,4} = oPlotter.definePlot(this.tiLogIndexes.Plants.CO2(iPlant),                 'Cumulative CO_2',              tPlotOptions);

                    oPlotter.defineFigure(coPlot,       ['Plant Exchange Rates ', oISS.csPlants{iPlant}]);

                    coPlot = cell(0);
                    coPlot{1,1} = oPlotter.definePlot(this.tiLogIndexes.Plants.NitrateStorageRate(iPlant), 	'Current Storage Nitrate Uptake',	tPlotOptions);
                    coPlot{1,2} = oPlotter.definePlot(this.tiLogIndexes.Plants.NitrateStructureRate(iPlant),'Current Structure Nitrate Uptake', tPlotOptions);
                    coPlot{1,3} = oPlotter.definePlot(this.tiLogIndexes.Plants.NitrateEdibleRate(iPlant),	'Current Edible Nitrate Uptake',    tPlotOptions);
                    coPlot{2,1} = oPlotter.definePlot(this.tiLogIndexes.Plants.NitrateStorage(iPlant),  	'Cumulative Storage Nitrate',       tPlotOptions);
                    coPlot{2,2} = oPlotter.definePlot(this.tiLogIndexes.Plants.Nitratestructure(iPlant), 	'Cumulative Structure Nitrate',     tPlotOptions);
                    coPlot{2,3} = oPlotter.definePlot(this.tiLogIndexes.Plants.NitrateEdible(iPlant),     	'Cumulative Edible Nitrate',      	tPlotOptions);

                    oPlotter.defineFigure(coPlot,       ['Plant Nutrients ', oISS.csPlants{iPlant}]);
                end
            end
            
            
            %% Debugging plots
            
%             oISS_ARS_MultiStore = this.oSimulationContainer.toChildren.ISS_ARS_MultiStore;
%             coPlots = [];
%             
%             iValue =1;
%             csStoreNames = fieldnames(oISS_ARS_MultiStore.toStores);
%             for iStore = 1:length(csStoreNames)
%                 for iPhase = 1:length(oISS_ARS_MultiStore.toStores.(csStoreNames{iStore}).aoPhases)
%                     csPhaseNames = fieldnames(oISS_ARS_MultiStore.toStores.(csStoreNames{iStore}).toPhases);
% 
%                     tMassLabels.ISS.csMassLabel{iValue}                 = ['"ISS ', csStoreNames{iStore}, csPhaseNames{iPhase}, ' Mass"'];
%                     tTemperatureLabels.ISS.csTemperatureLabel{iValue}   = ['"ISS ', csStoreNames{iStore}, csPhaseNames{iPhase}, ' Temperature"'];
%                     
%                     iValue = iValue + 1;
%                 end
%             end
% 
%             coPlots{1,1} = oPlotter.definePlot(tMassLabels.ISS.csMassLabel,                 'ISS Masses', tPlotOptions);
%             coPlots{1,2} = oPlotter.definePlot(tTemperatureLabels.ISS.csTemperatureLabel,   'ISS Temperatures', tPlotOptions);
            
%             csChildNames = fieldnames(oISS_ARS_MultiStore.toChildren);
%             for iChildren = 1:7
%                 csStoreNames = fieldnames(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores);
%                 
%                 iValue = 1;
%                 for iStore = 1:length(csStoreNames)
%                     for iPhase = 1:length(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores.(csStoreNames{iStore}).aoPhases)
%                         csPhaseNames = fieldnames(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores.(csStoreNames{iStore}).toPhases);
% 
%                         tMassLabels.(csChildNames{iChildren}).csMassLabel{iValue}                 = ['"', csChildNames{iChildren}, csStoreNames{iStore}, csPhaseNames{iPhase}, ' Mass"'];
%                         tTemperatureLabels.(csChildNames{iChildren}).csTemperatureLabel{iValue}   = ['"', csChildNames{iChildren}, csStoreNames{iStore}, csPhaseNames{iPhase}, ' Temperature"'];
%                         iValue = iValue + 1;
%                     end
%                 end
%                 
%                 coPlots{iChildren,1} = oPlotter.definePlot(tMassLabels.(csChildNames{iChildren}).csMassLabel,                 [csChildNames{iChildren}, ' Masses'], tPlotOptions);
%                 coPlots{iChildren,2} = oPlotter.definePlot(tTemperatureLabels.(csChildNames{iChildren}).csTemperatureLabel,   [csChildNames{iChildren}, ' Temperatures'], tPlotOptions);
%             end
%             
%             oPlotter.defineFigure(coPlots,  'Temperatures and Masses 1', tFigureOptions);
%             
%             coPlots = [];
%             csChildNames = fieldnames(oISS_ARS_MultiStore.toChildren);
%             for iChildren = 8:14
%                 csStoreNames = fieldnames(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores);
%                 
%                 iValue = 1;
%                 for iStore = 1:length(csStoreNames)
%                     for iPhase = 1:length(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores.(csStoreNames{iStore}).aoPhases)
%                         csPhaseNames = fieldnames(oISS_ARS_MultiStore.toChildren.(csChildNames{iChildren}).toStores.(csStoreNames{iStore}).toPhases);
% 
%                         tMassLabels.(csChildNames{iChildren}).csMassLabel{iValue}                 = ['"', csChildNames{iChildren}, csStoreNames{iStore}, csPhaseNames{iPhase}, ' Mass"'];
%                         tTemperatureLabels.(csChildNames{iChildren}).csTemperatureLabel{iValue}   = ['"', csChildNames{iChildren}, csStoreNames{iStore}, csPhaseNames{iPhase}, ' Temperature"'];
%                         iValue = iValue + 1;
%                     end
%                 end
%                 
%                 coPlots{iChildren-7,1} = oPlotter.definePlot(tMassLabels.(csChildNames{iChildren}).csMassLabel,                 [csChildNames{iChildren}, ' Masses'], tPlotOptions);
%                 coPlots{iChildren-7,2} = oPlotter.definePlot(tTemperatureLabels.(csChildNames{iChildren}).csTemperatureLabel,   [csChildNames{iChildren}, ' Temperatures'], tPlotOptions);
%             end
%             
%             oPlotter.defineFigure(coPlots,  'Temperatures and Masses 2', tFigureOptions);
            

            oPlotter.plot();
        end
    end
end
