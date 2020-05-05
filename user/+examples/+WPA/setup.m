classdef setup < simulation.infrastructure
    %plotting data of components and showing water balance operations
    
    % General information:
    % - Why do you have multiple MixedBed, MFBEDsolve files etc.? Especially
    %   since they seem to be not identical
    % - Use spaces, Tabs, etc to structure the code
    % - For more complex calculations include reference to either a source
    %   (if taken directly from the source) or to your thesis with the
    %   respective equation number
    % - Please maintain the V-HAB convenction for variable prefixes
    % - Check whether data types are necessary. E.g. a cell is not
    %   necessary to store integer values only. A cell requires more
    %   computation resource than an integer array. Also a strcmp command
    %   takes loner than a boolean query
    % - The description of your classes should contain the whole name of
    %   the component (e.g. MLS stands for Mostly Liquid Seperator ...) and
    %   a short information for the user what this component does and how
    %   the user can use it. If there is one general source state it (which
    %   you usually did but not always)
    properties
    end
    methods
        function this = setup(ptConfigParams, tSolverParams)
            %ttMonitorConfig = struct();
            ttMonitorConfig = struct('oLogger', struct('cParams', {{ true, 200000 }}));
            this@simulation.infrastructure('MFBED', ptConfigParams, tSolverParams, ttMonitorConfig);
            examples.WPA.systems.Example(this.oSimulationContainer,'Example');
            %% Simulation length
            
            this.fSimTime = 86400 * 12;  % 12; % In seconds
            
            this.bUseTime = true;
        end
       
        function configureMonitors(this)
            %% Logging
            oLog = this.toMonitors.oLogger;
            oPlot = this.toMonitors.oPlotter;
            
            iCells = this.oSimulationContainer.toChildren.MFBED.iFilter; %amount of ion and Ersatzphases
            %Getting several contaminants arrays from other classes
            cConataminents  = this.oSimulationContainer.toChildren.MFBED.cConataminents; %all contaminents
            cCations        = this.oSimulationContainer.toChildren.MFBED.toChildren.MultiBED1.toChildren.Bed1.toStores.MFBED_Tank.toProcsP2P.Ion_P2P1.cCations;
            [iCationAmount] = size(cCations);
            cKationNames    = cell(3, 1, 4, 25 + 1, iCationAmount(1), 3);
            
            cCation_Inflow_to_Outflow = cell(1, 1, 4, 2, iCationAmount(1), 3);
            
            csCationNames = {'H', 'Na', 'K', 'Ca','NH_4'};
            
            csBedNames  = {'MultiBED1', 'MultiBED2', 'IonBED'};
            csBeds      = fieldnames(this.oSimulationContainer.toChildren.MFBED.toChildren.MultiBED1.toChildren);
            csMFBEDs    = fieldnames(this.oSimulationContainer.toChildren.MFBED.toChildren);
            
            %% CationsBeds
            for iMFBEDs = 1 : 3
                for iCations = 1 : iCationAmount(1)
                    iCationBeds = 1;
                    iBedAmount  = this.oSimulationContainer.toChildren.MFBED.toChildren.MultiBED1.iChildren;
                    for iBeds= 1 : iBedAmount
                        for iK = 1 : iCells(iBeds)
                            if iK == 1
                                oLog.addValue(['MFBED.toChildren.',csBedNames{iMFBEDs},'.toChildren.Bed',num2str(iBeds),'.toBranches.Water_to_Bed.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cCations{iCations}),') * (-1)'], 'kg/s', [csCationNames{iCations} ,' into Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}]);
                                oLog.addValue(['MFBED.toChildren.',csBedNames{iMFBEDs},'.toChildren.Bed',num2str(iBeds),'.toBranches.tank_to_tank', num2str(iK), '.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cCations{iCations}),')'], 'kg/s', [csCationNames{iCations} ,' Flowrate out of Cell_', num2str(iK),' in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}]);
                            elseif iK == iCells(iBeds)
                                oLog.addValue(['MFBED.toChildren.',csBedNames{iMFBEDs},'.toChildren.Bed',num2str(iBeds),'.toBranches.BED_to_WT.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cCations{iCations}),')'], 'kg/s', [csCationNames{iCations} ,' Flowrate out of Cell_', num2str(iK),' in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}] );
                            else
                                oLog.addValue(['MFBED.toChildren.',csBedNames{iMFBEDs},'.toChildren.Bed',num2str(iBeds),'.toBranches.tank', num2str(iK-1),'_to_tank', num2str(iK), '.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cCations{iCations}),')'], 'kg/s', [csCationNames{iCations} ,' Flowrate out of Cell_', num2str(iK),' in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}]);
                            end
                            if this.oSimulationContainer.toChildren.MFBED.toChildren.(csMFBEDs{iMFBEDs}).toChildren.(csBeds{iBeds}).cBedType =='+' 
                                cKationNames{1,1,iCationBeds,iK+1,iCations, iMFBEDs} =    [csCationNames{iCations} ,' Flowrate out of Cell_', num2str(iK),' in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}];
                                cKationNames{2,1,iCationBeds,iK, iCations, iMFBEDs}  =    [csCationNames{iCations} ,' in Cell_', num2str(iK),' in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}];
                            end
                        end
                        cKationNames{1,1,iCationBeds,1,iCations}                        = [csCationNames{iCations} ,' into Bed_',num2str(iBeds)];
                        cCation_Inflow_to_Outflow{1,1,iCationBeds,1,iCations, iMFBEDs}  = [csCationNames{iCations} ,' into Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}];
                        cCation_Inflow_to_Outflow{1,1,iCationBeds,2,iCations, iMFBEDs}  = [csCationNames{iCations} ,' Flowrate out of Cell_', num2str(iK),' in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}];
                        if this.oSimulationContainer.toChildren.MFBED.toChildren.(csMFBEDs{iMFBEDs}).toChildren.(csBeds{iBeds}).cBedType == '+' 
                            iCationBeds = iCationBeds+1;
                        end
                    end
                end
            end
            
            %% AnionsBeds
            cAnions         = this.oSimulationContainer.toChildren.MFBED.toChildren.MultiBED1.toChildren.Bed1.toStores.MFBED_Tank.toProcsP2P.Ion_P2P1.cAnions;
            csAnionNames    = {'OH','CMT', 'Cl', 'C_4H_7O_2', 'CH_3COO', 'HCO_3', 'SO_4','C_3H_6O_3'};
            [iAnionAmount]  = size(cAnions);
            cAnionNames=cell(3,1,3,25+1, iAnionAmount(1),3);
            cAnion_Inflow_to_Outflow = cell(1,1,4,2, iAnionAmount(1),3);
            for iMFBEDs = 1 : 3
                for iAnions = 1 : iAnionAmount(1)
                    iAnionBeds = 1;
                    
                    for iBeds = 1 : iBedAmount
                        for iK = 1 : iCells(iBeds)
                            if iK == 1
                                oLog.addValue(['MFBED.toChildren.',csBedNames{iMFBEDs},'.toChildren.Bed',num2str(iBeds),'.toBranches.Water_to_Bed.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cAnions{iAnions}),') * (-1)'], 'kg/s', [csAnionNames{iAnions},' into Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}]);
                                oLog.addValue(['MFBED.toChildren.',csBedNames{iMFBEDs},'.toChildren.Bed',num2str(iBeds),'.toBranches.tank_to_tank', num2str(iK), '.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cAnions{iAnions}),')'], 'kg/s', [csAnionNames{iAnions} ,' Flowrate out of Cell_{', num2str(iK),'} in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}]);
                            elseif iK == iCells(iBeds)
                                oLog.addValue(['MFBED.toChildren.',csBedNames{iMFBEDs},'.toChildren.Bed',num2str(iBeds),'.toBranches.BED_to_WT.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cAnions{iAnions}),')'], 'kg/s', [csAnionNames{iAnions} ,' Flowrate out of Cell_{', num2str(iK),'} in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}] );
                            else
                                oLog.addValue(['MFBED.toChildren.',csBedNames{iMFBEDs},'.toChildren.Bed',num2str(iBeds),'.toBranches.tank', num2str(iK-1),'_to_tank', num2str(iK), '.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cAnions{iAnions}),')'], 'kg/s', [csAnionNames{iAnions} ,' Flowrate out of Cell_{', num2str(iK),'} in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}]);
                            end
                        
                            if this.oSimulationContainer.toChildren.MFBED.toChildren.(csMFBEDs{iMFBEDs}).toChildren.(csBeds{iBeds}).cBedType =='-' 
                    
                                cAnionNames{1,1,iAnionBeds,iK+1,iAnions,iMFBEDs} =    [csAnionNames{iAnions} ,' Flowrate out of Cell_{', num2str(iK),'} in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}];
                                cAnionNames{2,1,iAnionBeds,iK, iAnions,iMFBEDs}  =    [csAnionNames{iAnions} ,' in Cell_{', num2str(iK),'} in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}];
                            end
                        end
                        cAnionNames{1,1,iAnionBeds,1,iAnions}                       = [csAnionNames{iAnions} ,' into Bed_',num2str(iBeds)];
                        cAnion_Inflow_to_Outflow{1,1,iAnionBeds,1,iAnions, iMFBEDs} = [csAnionNames{iAnions} ,' into Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}];
                        cAnion_Inflow_to_Outflow{1,1,iAnionBeds,2,iAnions, iMFBEDs} = [csAnionNames{iAnions} ,' Flowrate out of Cell_{', num2str(iK),'} in Bed_',num2str(iBeds),'in ',csBedNames{iMFBEDs}];
                                                                                    
                        if this.oSimulationContainer.toChildren.MFBED.toChildren.(csMFBEDs{iMFBEDs}).toChildren.(csBeds{iBeds}).cBedType =='-' 
                            iAnionBeds = iAnionBeds + 1;
                        end
                    end
                end
            end
            %% Logging Reactor
            %CO2, O2, H2O
            csOrganicNames       = {'C_2H_6O','CH_2O_2','C_3H_8O_2','CH_2O','C_2H_6O_2','C_3H_6O', 'CH_4N_2O'};
            cVolatileOrganics    = this.oSimulationContainer.toChildren.MFBED.toStores.Reactor.toPhases.Ersatz.toManips.substance.cVolatileOrganics;
            iOrgancisAmount      = size(cVolatileOrganics);
            cReactorNames        = cell(2,2,2*iOrgancisAmount(1));
       
            oLog.addValue('MFBED.toStores.Reactor.toPhases.Ersatz', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'CO_2 in Reactor');
            oLog.addValue('MFBED.toStores.Reactor.toPhases.Ersatz', 'afMass(this.oMT.tiN2I.O2)',  'kg', 'O_2 in Reactor' );
            
            cReactorNames{1,2,1} = 'CO_2 in Reactor';
            cReactorNames{1,2,2} = 'O_2 in Reactor';
            %organcis
            
            for iOrganics=1:iOrgancisAmount(1)
                oLog.addValue('MFBED.toBranches.Water_to_Reactor.aoFlows(1)', ['this.fFlowRate * this.arPartialMass(', num2str(cVolatileOrganics{iOrganics}),')'], 'kg/s', [csOrganicNames{iOrganics},' into Reactor']);
                oLog.addValue('MFBED.toBranches.Water_to_MLS2.aoFlows(1)', ['this.fFlowRate * this.arPartialMass(', num2str(cVolatileOrganics{iOrganics}),')'], 'kg/s', [csOrganicNames{iOrganics},' out of Reactor']);
                cReactorNames{1,1, iOrganics*2-1} = [csOrganicNames{iOrganics},' into Reactor'];
                cReactorNames{1,1, iOrganics*2}   = [csOrganicNames{iOrganics},' out of Reactor'];
            end
            %CO2, H20 flowrates in Manip
            oLog.addValue('MFBED.toStores.Reactor.toPhases.Ersatz.toManips.substance', 'afPartialFlows(this.oMT.tiN2I.CO2)', 'kg/s', 'CO_2 Flowrate in Manipulater');
            oLog.addValue('MFBED.toStores.Reactor.toPhases.Ersatz.toManips.substance', 'afPartialFlows(this.oMT.tiN2I.H2O)', 'kg/s', 'H_2O Flowrate in Manipulater');
            oLog.addValue('MFBED.toStores.Reactor.toPhases.Ersatz.toManips.substance', 'afPartialFlows(this.oMT.tiN2I.O2)', 'kg/s', 'O_2 Flowrate in Manipulater');
            oLog.addValue('MFBED.toStores.Reactor.toPhases.Ersatz.toManips.substance', 'afPartialFlows(this.oMT.tiN2I.H)', 'kg/s', 'H_2 Flowrate in Manipulater');

            TotalOrganics='0';
            for iOrganics=1:iOrgancisAmount(1)
                oLog.addValue('MFBED.toStores.Reactor.toPhases.Ersatz.toManips.substance', ['afPartialFlows(', num2str(cVolatileOrganics{iOrganics}),')'], 'kg/s', [csOrganicNames{iOrganics},' Flowrate in Manipulater']);
                TotalOrganics                   = [TotalOrganics, ' + ', csOrganicNames{iOrganics},' Flowrate in Manipulater'];
                cReactorNames{2,1,4+iOrganics}  = [csOrganicNames{iOrganics},' Flowrate in Manipulater'];
            end
            
            cReactorNames{2,1,1} = 'CO_2 Flowrate in Manipulater';
            cReactorNames{2,1,2} = 'H_2O Flowrate in Manipulater';
            cReactorNames{2,1,3} = 'O_2 Flowrate in Manipulater';
            cReactorNames{2,1,4} = 'H_2 Flowrate in Manipulater';
           
            %OxygenMassConsumptionPotential
            oLog.addValue('MFBED.toStores.Reactor.toPhases.Ersatz.toManips.substance', 'OxygenMassConsumptionPotential', 'kg', 'O_2 useable for Oxidation');
            cReactorNames{2,2,1} = 'O_2 useable for Oxidation';
            
            %% Logging MLS
            cMLSNames       = cell(1,2,6,2);
            %flowrates into P2P
            cKnowngases     = cell(3,1);
            cKnowngases{1}  = this.oSimulationContainer.toChildren.MFBED.toStores.Reactor.oMT.tiN2I.O2;
            cKnowngases{2}  = this.oSimulationContainer.toChildren.MFBED.toStores.Reactor.oMT.tiN2I.CO2;
            cKnowngases{3}  = this.oSimulationContainer.toChildren.MFBED.toStores.Reactor.oMT.tiN2I.N2;
            iGasesAmount    = size(cKnowngases);
            csGasNames      = {'O_2', 'CO_2','N_2'};
            for iMLS = 1 : 2
                for iGases = 1 : iGasesAmount(1)
                    oLog.addValue(['MFBED.toStores.MLS',num2str(iMLS),'.toProcsP2P.MLS_P2P',num2str(iMLS)], ['this.fFlowRate * this.arPartialMass(',num2str(cKnowngases{iGases}) ,')'], 'kg/s', [csGasNames{iGases},' filtered by MLS', num2str(iMLS)]);
                    cMLSNames{1,1,iGases, iMLS} = [csGasNames{iGases},' filtered by MLS', num2str(iMLS)];
                end
                for iGases = 1 : iGasesAmount(1)
                
                    oLog.addValue(['MFBED.toBranches.Water_to_MLS',num2str(iMLS),'.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(',num2str(cKnowngases{iGases}) ,')'], 'kg/s', [csGasNames{iGases},' into MLS Tank_',num2str(iMLS)]);
                    if iMLS == 2
                        oLog.addValue('MFBED.toChildren.IonBED.toBranches.Water_to_Bed.aoFlows(1)', ['this.fFlowRate * this.arPartialMass(',num2str(cKnowngases{iGases}) ,') * (- 1)'], 'kg/s', [csGasNames{iGases},' ouf of MLS Tank_',num2str(iMLS)]);
                    else
                        oLog.addValue('MFBED.toChildren.MultiBED1.toBranches.Water_to_Bed.aoFlows(1)', ['this.fFlowRate * this.arPartialMass(',num2str(cKnowngases{iGases}) ,') * (- 1)'], 'kg/s', [csGasNames{iGases},' ouf of MLS Tank_',num2str(iMLS)]);
                    end
                    cMLSNames{1,2,2*iGases-1,iMLS}  =  [csGasNames{iGases},' into MLS Tank_',num2str(iMLS)];
                    cMLSNames{1,2,2*iGases,iMLS}    =  [csGasNames{iGases},' ouf of MLS Tank_',num2str(iMLS)];
                end
            end
            %organcis MFBEDs
            cBigOrganics        = this.oSimulationContainer.toChildren.MFBED.toChildren.MultiBED1.toStores.Tank8.toProcsP2P.BigOrganics_P2P.cBigOrganics;
            iAmountBigOrganics  = size(cBigOrganics);
            csBigOrganicNames   = {'C_{30}H_{50}'};
            cNamesBigOrganics   = cell(2, 2, iAmountBigOrganics(1)*2);
            
            for iBigOrganics = 1 : iAmountBigOrganics
                for i = 1 : 2
                    oLog.addValue(['MFBED.toChildren.',csBedNames{i},'.toChildren.Bed7.toBranches.BED_to_WT.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cBigOrganics{iBigOrganics}),')'], 'kg/s', [csBigOrganicNames{iBigOrganics} ,' into Tank 8 in ',csBedNames{i}]);
                    oLog.addValue(['MFBED.toChildren.',csBedNames{i},'.toBranches.BED_to_WT.aoFlows(1)'], ['this.fFlowRate * this.arPartialMass(', num2str(cBigOrganics{iBigOrganics}),')'], 'kg/s', [csBigOrganicNames{iBigOrganics} ,' out of Tank 8 in ',csBedNames{i}]);
                    oLog.addValue(['MFBED.toChildren.',csBedNames{i},'.toStores.Tank8.toProcsP2P.BigOrganics_P2P'], ['this.fFlowRate * this.arPartialMass(', num2str(cBigOrganics{iBigOrganics}),')'], 'kg/s', [csBigOrganicNames{iBigOrganics},' filtered by BigOrganics P2P in ',csBedNames{i}]);
                    
                    cNamesBigOrganics{i, 1, iBigOrganics}                       = [csBigOrganicNames{iBigOrganics} ,' into Tank 8 in ',csBedNames{i}];
                    cNamesBigOrganics{i, 1, iBigOrganics+iAmountBigOrganics(1)} = [csBigOrganicNames{iBigOrganics} ,' out of Tank 8 in ',csBedNames{i}];
                    cNamesBigOrganics{i, 2, iBigOrganics}                       = [csBigOrganicNames{iBigOrganics},' filtered by BigOrganics P2P in ',csBedNames{i}];
                end
            end
            %% WaterData - contaminants in waste water
            WaterQuality = cell(1,2, iCationAmount(1)+iAnionAmount(1)+iOrgancisAmount(1)+iGasesAmount(1)-1);
            for iCations = 2 : iCationAmount(1)
                oLog.addValue('MFBED.toStores.WW_Tank.toPhases.Ersatz', ['afMass(', num2str(cCations{iCations}),') / this.fMass * 1000 *1000'], 'mg/kg', [csCationNames{iCations},' in WWater']);
                WaterQuality{1, 1, iCations} = [csCationNames{iCations},' in WWater'];
                oLog.addValue('MFBED.toStores.WT_Tank.toPhases.Water', ['afMass(', num2str(cCations{iCations}),') / this.fMass * 1000 *1000'], 'mg/kg', [csCationNames{iCations},' in processed Water']);
                WaterQuality{1, 2, iCations} = [csCationNames{iCations},' in processed Water'];
                
            end
            
            for iAnions = 2:iAnionAmount(1)
                oLog.addValue('MFBED.toStores.WW_Tank.toPhases.Ersatz', ['afMass(', num2str(cAnions{iAnions}),') / this.fMass * 1000 *1000'], 'mg/kg', [csAnionNames{iAnions},' in WWater']);
                WaterQuality{1, 1, iCationAmount(1)-1+iAnions} = [csAnionNames{iAnions},' in WWater'];
                
                oLog.addValue('MFBED.toStores.WT_Tank.toPhases.Water', ['afMass(', num2str(cAnions{iAnions}),') / this.fMass * 1000 *1000'], 'mg/kg', [csAnionNames{iAnions},' in processed Water']);
                WaterQuality{1, 2, iCationAmount(1)-1+iAnions} = [csAnionNames{iAnions},' in processed Water'];
            end
            for iOrganics = 1:iOrgancisAmount(1)
                oLog.addValue('MFBED.toStores.WW_Tank.toPhases.Ersatz', ['afMass(', num2str(cVolatileOrganics{iOrganics}),') / this.fMass * 1000 *1000'], 'mg/kg', [csOrganicNames{iOrganics},' in WWater']);
                WaterQuality{1, 1, iCationAmount(1)-1+iAnionAmount(1)-1+iOrganics} = [csOrganicNames{iOrganics},' in WWater'];
                
                oLog.addValue('MFBED.toStores.WT_Tank.toPhases.Water', ['afMass(', num2str(cVolatileOrganics{iOrganics}),') / this.fMass * 1000 *1000'], 'mg/kg', [csOrganicNames{iOrganics},' in processed Water']);
                WaterQuality{1, 2, iCationAmount(1)-1+iAnionAmount(1)-1+iOrganics} = [csOrganicNames{iOrganics},' in processed Water'];
            end
            
            for iBOrganics = 1:iAmountBigOrganics(1)
                oLog.addValue('MFBED.toStores.WW_Tank.toPhases.Ersatz', ['afMass(', num2str(cBigOrganics{iBOrganics}),') / this.fMass * 1000 *1000'], 'mg/kg', [csBigOrganicNames{iBOrganics},' in WWater']);
                WaterQuality{1, 1, iCationAmount(1)+iAnionAmount(1)+iOrgancisAmount(1)+iBOrganics}   = [csBigOrganicNames{iBOrganics},' in WWater'];
                
                oLog.addValue('MFBED.toStores.WT_Tank.toPhases.Water', ['afMass(', num2str(cBigOrganics{iBOrganics}),') / this.fMass * 1000 *1000'], 'mg/kg', [csBigOrganicNames{iBOrganics},' in processed Water']);
                WaterQuality{1, 2, iCationAmount(1)+iAnionAmount(1)+iOrgancisAmount(1)+iBOrganics-2} = [csBigOrganicNames{iBOrganics},' in processed Water'];
            end
            
            %% Define plots
           
            %oPlot = this.toMonitors.oPlotter;
            %% Water balance Plotting
             [iConataminents, ~] = size(cConataminents);
             csWaterBalance      = cell(2,2, iConataminents);
             oLog.addValue('MFBED.toStores.WW_Tank.toPhases.Ersatz', 'fMass', 'kg', 'Wastewater in Wastewater Tank');
             oLog.addValue('MFBED.toStores.WT_Tank.toPhases.Water', 'fMass', 'kg',  'Water in Product Water Tank');
             oLog.addValue('MFBED.toStores.Delay_Tank.toPhases.Ersatz', 'fMass', 'kg',  'Water in Delay Tank');
             csWaterBalance{1,1,1} = 'Wastewater in Wastewater Tank';
             csWaterBalance{1,2,1} = 'Water in Product Water Tank';
             csWaterBalance{1,2,2} = 'Water in Delay Tank';
             oLog.addValue('MFBED.toBranches.Water_to_MLS1.aoFlows(1)', 'fFlowRate', 'kg/s', 'Water out of Wastewater Tank');
             oLog.addValue('MFBED.toBranches.WWater_to_WW_Tank.aoFlows(1)', 'fFlowRate', 'kg/s', 'Not clean enough Water back into Wastewater Tank');
             oLog.addValue('MFBED.toBranches.Water_to_WT_Tank.aoFlows(1)', 'fFlowRate', 'kg/s', 'Water to Product Water Tank');
             csWaterBalance{2,1,1} = 'Water out of Wastewater Tank';
             csWaterBalance{2,1,2} = 'Not clean enough Water back into Wastewater Tank';
             csWaterBalance{2,1,3} = 'Water to Product Water Tank';
             oLog.addValue('MFBED', 'ppmInOutflowOfWW' , '-', 'ppm in Water flowing out of Wastewater Tank');
             oLog.addValue('MFBED', 'TOCInOutflowOfWW' , '-', 'TOC in Water flowing out of Wastewater Tank');
             csWaterBalance{2,2,1} = 'ppm in Water flowing out of Wastewater Tank';
             csWaterBalance{2,2,2} = 'TOC in Water flowing out of Wastewater Tank';
             
             oPlot.definePlot(csWaterBalance, 'Water Balance ');
            %% MLS 1
            oPlot.definePlot(cMLSNames(:,:,:,1), 'MLS1 Data');
            
            %% MFBED 1
            cNamesMFBED1 = cell(2,2,18);
            for i = 1:2
                for iCations = 1 : iCationAmount(1)
                    cNamesMFBED1(1, 1, (i-1)*iCationAmount(1)+iCations)=cCation_Inflow_to_Outflow(1,1,(i-1)*3+1,i,iCations,1);
                end
            end
            for i=1:2
                for iAnions = 1:iAnionAmount(1)
                    cNamesMFBED1(1, 2, ( i-1)*iAnionAmount(1)+iAnions+2*iCationAmount(1))=cAnion_Inflow_to_Outflow(1,1,(i-1)*2+1,i,iAnions,1);
                end
            end
            for iBigOrganics = 1:iAmountBigOrganics*2 
                cNamesMFBED1{2,1,iBigOrganics}= cNamesBigOrganics{1, 1, iBigOrganics};
            end
            for iBigOrganics = 1:iAmountBigOrganics 
                cNamesMFBED1{2,2,iBigOrganics}= cNamesBigOrganics{1, 2, iBigOrganics};
            end
            oPlot.definePlot(cNamesMFBED1, 'MFBED#1 Data ');
            
            %% MFBED 2
            cNamesMFBED2= cell(2,2,10);
            for i=1:2
                for iCations = 1 : iCationAmount(1)
                    cNamesMFBED2(1, 1, (i-1)*iCationAmount(1)+iCations)                   = cCation_Inflow_to_Outflow(1,1,(i-1)*3+1,i,iCations,2);
                end
            end
            for i=1:2
                for iAnions = 1 : iAnionAmount(1)
                    cNamesMFBED2(1, 2, ( i-1)*iAnionAmount(1)+iAnions+2*iCationAmount(1)) = cAnion_Inflow_to_Outflow(1,1,(i-1)*2+1,i,iAnions,2);
                end
            end
            for iBigOrganics = 1 : iAmountBigOrganics*2
                cNamesMFBED2{2,1,iBigOrganics} = cNamesBigOrganics{2, 1, iBigOrganics};
            end   
            for iBigOrganics = 1 : iAmountBigOrganics 
                cNamesMFBED2{2,2,iBigOrganics} = cNamesBigOrganics{2, 2, iBigOrganics};
            end
            oPlot.definePlot(cNamesMFBED2, 'MFBED#2 Data ');
            
            %% Reactor
            oPlot.definePlot(cReactorNames, 'Reactor Data');
            oPlot.definePlot({TotalOrganics, cReactorNames{2,1,1}, cReactorNames{2,1,2}, cReactorNames{2,1,3}, cReactorNames{2,1,4}}, 'Manipulator flowrates ');
            
            %% MLS 2
            oPlot.definePlot(cMLSNames(:,:,:,2), 'MLS2 Data');
            
            %% IonBed
            cNamesIonBED = cell(1,2,10);
            for i=1:2
                for iCations = 1:iCationAmount(1)
                    cNamesIonBED(1, 1, (i-1)*iCationAmount(1)+iCations) = cCation_Inflow_to_Outflow(1,1,(i-1)*3+1,i,iCations,3); 
                end
            end
            for i=1:2
                for iAnions = 1:iAnionAmount(1)
                    cNamesIonBED(1, 2, (i-1)*iAnionAmount(1)+iAnions)   = cAnion_Inflow_to_Outflow(1,1,(i-1)*2+1,i,iAnions,3);
                end
            end
            oPlot.definePlot(cNamesIonBED, 'IonBED Data ');
            
            %% CheckTank
            oLog.addValue('MFBED', 'ppm' , '-', 'ppm in Checktank');
            oLog.addValue('MFBED', 'TOC' , '-', 'TOC in Checktank');
            csCheck_Tank        = cell(1, 2, 2);
            csCheck_Tank{1,1,1} = 'ppm in Checktank';
            csCheck_Tank{1,2,1} = 'TOC in Checktank';
            
            oPlot.definePlot(csCheck_Tank, 'Water Check ');
            
            %% ProductWater vs WWater
            
            oPlot.definePlot(WaterQuality, 'Processed Water ');
        
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all % closes all currently open figures
            tParameters.sTimeUnit = 'd';
            try
                this.toMonitors.oLogger.readDataFromMat;
            catch
                disp('no data outputted yet')
            end
            
            this.toMonitors.oPlotter.plot(tParameters);
            %this.toMonitors.oPlotter.plot();
            
            % get all currently open figures
            figHandles = get(groot, 'Children');
            
            % set a specific figure to the currently active figure
            set(0, 'CurrentFigure', figHandles(2));
            
            % gcf is always the current figure
            
            %axesObjs = get(gcf, 'Children');  %axes handles
            %dataObjs = get(axesObjs, 'Children');
            %dataObjs = dataObjs(2);
            %dataObjs = dataObjs{1};
            
            %xData = dataObjs(1).XData;
            %hold on;
            
            %fConstant = ((1.5*10^-7)/100)*2.5;
            %mfConstant = ones(1,length(xData));
            %mfConstant = mfConstant .* fConstant;
            
            % alternativ geradengleichung mit dieser Zeit und dann plotten
            % fTime = this.oSimulationContainer.oTimer.fTime;
            
            %plot(xData, mfConstant, 'b--');
            
        end
    end
end