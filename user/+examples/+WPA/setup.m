classdef setup < simulation.infrastructure
    %plotting data of components and showing water balance operations
    
    properties
        % Property where indices of logs can be stored
        tiLogIndexes = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            %ttMonitorConfig = struct();
            
            ttMonitorConfig = struct('oLogger', struct('cParams', {{ true, 20000 }}));
            
            ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestepObserver';
            ttMonitorConfig.oTimeStepObserver.cParams = { 0 };
            
            this@simulation.infrastructure('MFBED', ptConfigParams, tSolverParams, ttMonitorConfig);
            examples.WPA.systems.Example(this.oSimulationContainer,'Example');
            %% Simulation length
            
            this.fSimTime = 86400;  % 12; % In seconds
            
            this.bUseTime = true;
        end
       
        function configureMonitors(this)
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oMT = this.oSimulationContainer.oMT;
            
            % Logging for the WPA:
            oWPA = this.oSimulationContainer.toChildren.Example.toChildren.WPA;
            oLog.addValue('Example',	'fTotalVolumePassedThroughWPA',      'm^3',     'WPA Total Volume Passed Through');
             
            
            this.tiLogIndexes.WPA.Masses{1}                  = oLog.addValue('Example:c:WPA.toStores.WasteWater.toPhases.Water',	'fMass',      'kg',     'WPA Waste Water Mass');
             
            this.tiLogIndexes.WPA.Flowrates{1}               = oLog.addValue('Example:c:WPA.toBranches.Inlet',                      'fFlowRate',  'kg/s',   'WPA Inflow');
            this.tiLogIndexes.WPA.Flowrates{2}               = oLog.addValue('Example:c:WPA.toBranches.Outlet',                     'fFlowRate',  'kg/s',   'WPA Outflow');
            this.tiLogIndexes.WPA.Flowrates{3}               = oLog.addValue('Example:c:WPA.toBranches.WasteWater_to_MLS1',      	'fFlowRate',  'kg/s',   'WPA Waste Water to Liquid Seperator');
            this.tiLogIndexes.WPA.Flowrates{4}               = oLog.addValue('Example:c:WPA.toBranches.Check_to_WasteWater',      	'fFlowRate',  'kg/s',   'WPA Reflow of Waste Water');
            
            this.tiLogIndexes.WPA.Airflows.Inflows.O2        = oLog.addValue('Example:c:WPA.toBranches.AirInlet.aoFlows(1)',        'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',  'kg/s',   'WPA Inflow O2');
            this.tiLogIndexes.WPA.Airflows.Inflows.N2        = oLog.addValue('Example:c:WPA.toBranches.AirInlet.aoFlows(1)',        'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.N2)',  'kg/s',   'WPA Inflow N2');
            this.tiLogIndexes.WPA.Airflows.Inflows.CO2       = oLog.addValue('Example:c:WPA.toBranches.AirInlet.aoFlows(1)',        'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s',   'WPA Inflow CO2');
            this.tiLogIndexes.WPA.Airflows.Inflows.H2O       = oLog.addValue('Example:c:WPA.toBranches.AirInlet.aoFlows(1)',        'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s',   'WPA Inflow H2O');
            
            this.tiLogIndexes.WPA.Airflows.Outflows.O2       = oLog.addValue('Example:c:WPA.toBranches.AirOutlet.aoFlows(1)',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.O2)',  'kg/s',   'WPA Outflow O2');
            this.tiLogIndexes.WPA.Airflows.Outflows.N2       = oLog.addValue('Example:c:WPA.toBranches.AirOutlet.aoFlows(1)',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.N2)',  'kg/s',   'WPA Outflow N2');
            this.tiLogIndexes.WPA.Airflows.Outflows.CO2      = oLog.addValue('Example:c:WPA.toBranches.AirOutlet.aoFlows(1)',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s',   'WPA Outflow CO2');
            this.tiLogIndexes.WPA.Airflows.Outflows.H2O      = oLog.addValue('Example:c:WPA.toBranches.AirOutlet.aoFlows(1)',       'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s',   'WPA Outflow H2O');
            
            this.tiLogIndexes.WPA.EffectiveFlows{1}          = oLog.addVirtualValue('"WPA Outflow O2"  + "WPA Inflow O2"'  , 'kg/s', 'WPA O2 Output');
            this.tiLogIndexes.WPA.EffectiveFlows{2}          = oLog.addVirtualValue('"WPA Outflow N2"  + "WPA Inflow N2"'  , 'kg/s', 'WPA N2 Output');
            this.tiLogIndexes.WPA.EffectiveFlows{3}          = oLog.addVirtualValue('"WPA Outflow CO2" + "WPA Inflow CO2"' , 'kg/s', 'WPA CO2 Output');
            this.tiLogIndexes.WPA.EffectiveFlows{4}          = oLog.addVirtualValue('"WPA Outflow H2O" + "WPA Inflow H2O"' , 'kg/s', 'WPA H2O Output');
            
            this.tiLogIndexes.WPA.Outflows.PPM              = oLog.addValue('Example:c:WPA.toBranches.Outlet.aoFlowProcs(1)',       'this.fPPM',   'ppm',    'WPA Outflow PPM');
            this.tiLogIndexes.WPA.Outflows.TOC              = oLog.addValue('Example:c:WPA.toBranches.Outlet.aoFlowProcs(1)',       'this.fTOC',   '-',      'WPA Outflow TOC');
            % Logging for the Multifiltration and Ion Exchange beds:
            csBeds = oWPA.csChildren;
            
            abAllContaminants = false(1, this.oSimulationContainer.oMT.iSubstances);
            for iBed = 1:length(csBeds)
                oBed = this.oSimulationContainer.toChildren.Example.toChildren.WPA.toChildren.(csBeds{iBed});
                % String path to the bed for logging purposes
                sBedPath = ['Example:c:WPA:c:', oBed.sName];
                for iResin = 1:oBed.iChildren
                    oResin = oBed.toChildren.(oBed.csChildren{iResin});
                    
                    % String path to the resin store for logging purposes
                    sResinPath = [':c:', oResin.sName, ':s:Resin'];
                    
                    % In order to get the ions which are of interest, we
                    % check for which seperation factors are defined:
                    afSeperationFactors = oResin.toStores.Resin.toProcsP2P.Ion_P2P1.afSeperationFactors;
                    
                    csIons = oMT.csI2N(afSeperationFactors ~= 0);
                    abAllContaminants(afSeperationFactors ~= 0) = true;
                    iIons = length(csIons);
                    
                    % Now we get the cells and loop over the existing
                    % cells:
                    iCells = oResin.iCells;
                    for iCell = 1:iCells
                        for iIon = 1:iIons
                            % Log the P2P flowrate for each relevant Ion
                            % for this cell
                            sAdsorptionLogValue = [oBed.sName, ' ', oResin.sName, ' Cell ', num2str(iCell), ' ', csIons{iIon},' adsorption P2P rate'];
                            sDesorptionLogValue = [oBed.sName, ' ', oResin.sName, ' Cell ', num2str(iCell), ' ', csIons{iIon},' desorption P2P rate'];
                            oLog.addValue([sBedPath, sResinPath, '.toProcsP2P.Ion_P2P', num2str(iCell)],            ['this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.', csIons{iIon},')'],      'kg/s',     sAdsorptionLogValue);
                            oLog.addValue([sBedPath, sResinPath, '.toProcsP2P.Ion_Desorption_P2P', num2str(iCell)],	['this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.', csIons{iIon},')'],      'kg/s',     sDesorptionLogValue);
                            
                            this.tiLogIndexes.(oBed.sName).(oResin.sName).tfP2P_Flowrates(iCell).mfIon{iIon} = oLog.addVirtualValue(['"',sAdsorptionLogValue,'" + "',sDesorptionLogValue,'"'] , 'kg/s', [oBed.sName, ' ', oResin.sName, ' Cell ', num2str(iCell), ' ', csIons{iIon},' adsorption rate']);
                            
                            if iCell < iCells
                                this.tiLogIndexes.(oBed.sName).(oResin.sName).tfCellOutFlowrates(iCell).mfIon{iIon} = oLog.addValue([sBedPath, ':c:', oResin.sName, '.toBranches.Cell_', num2str(iCell), '_to_Cell_', num2str(iCell+1), '.aoFlows(1)'],  	['this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.', csIons{iIon},')'],      'kg/s');
                            else
                                if iBed == 3
                                    this.tiLogIndexes.(oBed.sName).(oResin.sName).tfCellOutFlowrates(iCell).mfIon{iIon} = oLog.addValue('Example:c:WPA.toBranches.IonBed_to_Check.aoFlows(1)',                                                              ['this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.', csIons{iIon},')'],      'kg/s');
                                else
                                    if iResin == 7
                                        this.tiLogIndexes.(oBed.sName).(oResin.sName).tfCellOutFlowrates(iCell).mfIon{iIon} = oLog.addValue([sBedPath, '.toBranches.Resin7_Cell',num2str(iCell) ,'_to_OrganicRemoval.aoFlows(1)'],                          ['this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.', csIons{iIon},')'],      'kg/s');
                                    else
                                        this.tiLogIndexes.(oBed.sName).(oResin.sName).tfCellOutFlowrates(iCell).mfIon{iIon} = oLog.addValue([sBedPath, '.toBranches.Resin', num2str(iResin), '_to_', num2str(iResin+1), '.aoFlows(1)'],                     ['this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.', csIons{iIon},')'],      'kg/s');
                                    end
                                end
                            end
                            % Log the Ion Mass in the resion for each cell
                            % and each ion
                            this.tiLogIndexes.(oBed.sName).(oResin.sName).tfResinMasses(iCell).mfIon{iIon} = oLog.addValue([sBedPath, sResinPath, '.toPhases.Resin_', num2str(iCell)],      ['this.afMass(this.oMT.tiN2I.', csIons{iIon},')'],                            	'kg',       [oBed.sName, ' ', oResin.sName, ' Cell ', num2str(iCell), ' ', csIons{iIon},' Mass']);
                        end
                    end
                    if iBed < 3
                        abAllContaminants(oMT.tiN2I.C30H50) = true;
                        this.tiLogIndexes.(oBed.sName).tfOrganicsP2P_Flowrates = oLog.addValue([sBedPath, '.toStores.OrganicRemoval.toProcsP2P.BigOrganics_P2P'],      'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C30H50)',   	'kg/s',       [oBed.sName, ' Organic Removal Flow']);
                    end
                    if iResin < oBed.iChildren
                        warning('off', 'all')
                        csIons = {'Hplus';'Naplus';'Kplus';'NH4';'Ca2plus';'HCO3';'OH';'SO4';'Clminus';'C4H7O2';'C2H3O2';'CMT';'C3H5O3'};
                        for iIon = 1:length(csIons)
                            sFlowRateLogValue = [oBed.sName, ' ', oResin.sName, ' ', csIons{iIon},' Outlet Flow Rate'];
                            this.tiLogIndexes.(oBed.sName).(oResin.sName).tfResin_Flowrates.mfIon{iIon} = oLog.addValue([sBedPath, '.toBranches.Resin', num2str(iResin),'_to_',num2str(iResin+1), '.aoFlows(1)'],	['this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.', csIons{iIon},')'],      'kg/s',     sFlowRateLogValue);
                        end
                        warning('on', 'all')
                       
%                         spHLogValue = [oBed.sName, ' ', oResin.sName, '  Outlet pH'];
%                         this.tiLogIndexes.(oBed.sName).(oResin.sName).fResin_OutletPH = oLog.addValue([sBedPath, ':c:', oResin.sName, ':s:Resin.toPhases.Water_', num2str(oResin.iCells), '.toManips.substance'],	'fpH',      '-',     spHLogValue);
                        
                    end
                end
                
                
                miContaminants = find(abAllContaminants);
                for iContaminant = 1:sum(abAllContaminants)
                    sContaminant = oMT.csI2N{miContaminants(iContaminant)};
                    this.tiLogIndexes.WPA.ContaminantToCheckFlows{iContaminant}               = oLog.addValue('Example:c:WPA.toBranches.IonBed_to_Check.aoFlows(1)', ['this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.', sContaminant,')'],  'kg/s',   [sContaminant, ' flow to Check']);
                end
            end
            
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all % closes all currently open figures
            try
                this.toMonitors.oLogger.readDataFromMat;
            catch
                disp('no data outputted yet')
            end
            
            oPlotter = plot@simulation.infrastructure(this);
            tPlotOptions.sTimeUnit = 'hours';
            
            coPlots{1,1} = oPlotter.definePlot(this.tiLogIndexes.WPA.Masses,                    'WPA Water Mass',           tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(this.tiLogIndexes.WPA.Flowrates,                 'WPA Flowrates',            tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(this.tiLogIndexes.WPA.EffectiveFlows,            'WPA Gas Flows',            tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(this.tiLogIndexes.WPA.ContaminantToCheckFlows,   'WPA Contaminant Flows',    tPlotOptions);
            coPlots{1,3} = oPlotter.definePlot({this.tiLogIndexes.WPA.Outflows.PPM, this.tiLogIndexes.WPA.Outflows.TOC},   'WPA Contaminant Flows',    tPlotOptions);
            
            % {'"WPA O2 Output"', '"WPA N2 Output"', '"WPA CO2 Output"', '"WPA H2O Output"'}
            oPlotter.defineFigure(coPlots,  'WPA Parameters');
            
            oLogger = this.toMonitors.oLogger;
            for iLog = 1:oLogger.iNumberOfLogItems
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'WPA Total Volume Passed Through')
                    iSimulationBedVolume = iLog;
                end
            end
            
            % Individual cell plots, results in a very large number of
            % plots if outcommented!
            tPlotOptions.bLegend = false;
            oWPA = this.oSimulationContainer.toChildren.Example.toChildren.WPA;
            csBeds = oWPA.csChildren;
            for iBed = 1:length(csBeds)
                oBed = this.oSimulationContainer.toChildren.Example.toChildren.WPA.toChildren.(csBeds{iBed});
                coPlotsFlows    = cell(oBed.iChildren,5);
                coPlotsMasses   = cell(oBed.iChildren,5); 
                coPlotsOutFlows = cell(oBed.iChildren,5); 
                for iResin = 1:oBed.iChildren
                    oResin = oBed.toChildren.(oBed.csChildren{iResin});
                    iCells = oResin.iCells;
                    for iCell = 1:iCells
                        coPlotsFlows{iResin,iCell}      = oPlotter.definePlot(this.tiLogIndexes.(csBeds{iBed}).(oResin.sName).tfP2P_Flowrates(iCell).mfIon,	['Resin ',num2str(iResin),' Cell ',num2str(iCell),' Adsorption Flows'],   tPlotOptions);
                        coPlotsMasses{iResin,iCell}     = oPlotter.definePlot(this.tiLogIndexes.(csBeds{iBed}).(oResin.sName).tfResinMasses(iCell).mfIon,	['Resin ',num2str(iResin),' Cell ',num2str(iCell),' adsorbed Mass'],   tPlotOptions);
                        coPlotsOutFlows{iResin,iCell}   = oPlotter.definePlot(this.tiLogIndexes.(csBeds{iBed}).(oResin.sName).tfCellOutFlowrates(iCell).mfIon,	['Resin ',num2str(iResin),' Cell ',num2str(iCell),' Out Flows'],   tPlotOptions);
                    end
                end
                oPlotter.defineFigure(coPlotsFlows,  [csBeds{iBed}, ' Adsorption Flows']);
                oPlotter.defineFigure(coPlotsMasses,  [csBeds{iBed}, ' Adsorbed Masses']);
                oPlotter.defineFigure(coPlotsOutFlows,  [csBeds{iBed}, ' Out Flows']);
            end
            
            oPlotter.plot();
            
            %% Ion Verification Plots
            csIon = {'Sodium', 'Potassium', 'Calcium', 'Acetate', 'Butyrate', 'Chloride'};
            % Ions in tfResin_Flowrates.mfIon log entries:
            % csIons = {'Hplus';'Naplus';'Kplus';'NH4';'Ca2plus';'HCO3';'OH';'SO4';'Clminus';'C4H7O2';'C2H3O2';'CMT';'C3H5O3'};
            miIons = [2, 3, 5, 11, 10, 9];

            mfPassedVolume = oLogger.mfLog(:,iSimulationBedVolume) .* 1000;
            
            for iVerification = 1:length(csIon)
                fBedVolume                      = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRN150'], 'B1');
                mfBedVolumesData                = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRN150'], 'A5:A2000');
                mfIonOutFlowIRN150              = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRN150'], 'E5:E2000');
                mfVolumePassedThroughIRN150     = mfBedVolumesData .* fBedVolume;

                if iVerification > 3
                    sSecondBed = 'IRA-68';
                    fBedVolume                 	= xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRA-68'], 'B1');
                    mfBedVolumesData           	= xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRA-68'], 'A5:A2000');
                    mfIonOutFlowFinal          	= xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRA-68'], 'E5:E2000');
                else
                    sSecondBed = 'IRN-77';
                    fBedVolume                 	= xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRN-77'], 'B1');
                    mfBedVolumesData           	= xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRN-77'], 'A5:A2000');
                    mfIonOutFlowFinal          	= xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', [csIon{iVerification}, ' IRN-77'], 'E5:E2000');
                end
                mfVolumePassedThroughFinal      = mfBedVolumesData .* fBedVolume;

                % values from verification are in mg/l so we habe to
                % convert the kg/s flowrate from V-HAB into mg divide it
                % with the overall volumetric flowrate assuming a constant
                % density of water of 998.24 kg/m^3
                mfIonAfterIRN150 = oLogger.mfLog(:,this.tiLogIndexes.MultiBED1.Resin_2.tfResin_Flowrates.mfIon{miIons(iVerification)}) .* 1e6 ./ ((oLogger.mfLog(:,this.tiLogIndexes.WPA.Flowrates{3}) / 998.24) * 1000);
                if iVerification > 3
                    mfIonAfterFinal  = oLogger.mfLog(:,this.tiLogIndexes.MultiBED1.Resin_4.tfResin_Flowrates.mfIon{miIons(iVerification)}) .* 1e6 ./ ((oLogger.mfLog(:,this.tiLogIndexes.WPA.Flowrates{3}) / 998.24) * 1000);
                else
                    mfIonAfterFinal  = oLogger.mfLog(:,this.tiLogIndexes.MultiBED1.Resin_3.tfResin_Flowrates.mfIon{miIons(iVerification)}) .* 1e6 ./ ((oLogger.mfLog(:,this.tiLogIndexes.WPA.Flowrates{3}) / 998.24) * 1000);
                end
                figure('name', [csIon{iVerification}, ' Verification'])
                plot(mfPassedVolume, mfIonAfterIRN150);
                hold on
                plot(mfPassedVolume, mfIonAfterFinal);
                plot(mfVolumePassedThroughIRN150, mfIonOutFlowIRN150, '--');
                plot(mfVolumePassedThroughFinal, mfIonOutFlowFinal, '--');
                legend(['V-HAB ',csIon{iVerification},' after IRN150'],['V-HAB ',csIon{iVerification},' after ', sSecondBed], [csIon{iVerification},' after IRN150'], [csIon{iVerification}, ' after ', sSecondBed])
                grid on
                xlabel('Processed Water Volume / L')
                ylabel([csIon{iVerification}, ' Outlet / mg/L'])
            end
            
%             mfpHAfterIRN150 = oLogger.mfLog(:,this.tiLogIndexes.MultiBED1.Resin_2.fResin_OutletPH);
%             mfpHAfterIRN77  = oLogger.mfLog(:,this.tiLogIndexes.MultiBED1.Resin_3.fResin_OutletPH);
%             mfpHAfterIRA68  = oLogger.mfLog(:,this.tiLogIndexes.MultiBED1.Resin_4.fResin_OutletPH);
%             
%             fBedVolume                      = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IRN150', 'B1');
%             mfBedVolumesData                = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IRN150', 'A5:A2000');
%             mfpHOutFlowIRN150               = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IRN150', 'B5:B2000');
%             mfVolumePassedThroughIRN150     = mfBedVolumesData .* fBedVolume;
% 
%             fBedVolume                      = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IR-77', 'B1');
%             mfBedVolumesData                = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IR-77', 'A5:A2000');
%             mfpHOutFlowIRN77                = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IR-77', 'B5:B2000');
%             mfVolumePassedThroughIRN77      = mfBedVolumesData .* fBedVolume;
%             
%             fBedVolume                      = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IRA-68', 'B1');
%             mfBedVolumesData                = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IRA-68', 'A5:A2000');
%             mfpHOutFlowIRA68                = xlsread('user\+examples\+WPA\+VerificationData\WPA_Verification_Data.xlsx', 'pH IRA-68', 'B5:B2000');
%             mfVolumePassedThroughIRA68      = mfBedVolumesData .* fBedVolume;
%             
%             figure('name', 'pH Verification')
%             plot(mfPassedVolume, mfpHAfterIRN150);
%             hold on
%             plot(mfPassedVolume, mfpHAfterIRN77);
%             plot(mfPassedVolume, mfpHAfterIRA68);
%             plot(mfVolumePassedThroughIRN150, mfpHOutFlowIRN150, '--');
%             plot(mfVolumePassedThroughIRN77, mfpHOutFlowIRN77, '--');
%             plot(mfVolumePassedThroughIRA68, mfpHOutFlowIRA68, '--');
%             legend('V-HAB pH after IRN150', 'V-HAB pH after IRN77', 'V-HAB pH after IRA68', 'pH after IRN150', 'pH after IRN77', 'pH after IRA68');
%             grid on
%             xlabel('Processed Water Volume / L')
%             ylabel('pH / -')
            
        end
    end
end