classdef setup < simulation.infrastructure
    %The setup file for the simulation of the CROP model
    %   The simulation length and the plots for analysis are included in
    %   this class file.
    
    properties
        tiLog = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorCfg = struct();
            
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('CROP_Example', ptConfigParams, tSolverParams, ttMonitorCfg);
            
            
            % Creating the CROP system as a child of the root system
            % of this simulation.
            examples.CROP.system.Example(this.oSimulationContainer, 'Example');

  %% Simulation length
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 1 * 24 * 3600;
            this.iSimTicks = 200;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            oLogger = this.toMonitors.oLogger;
            
            % The logged values from the simulation results. The detailed
            % information is included in the name as an argument of the
            % function "oLogger.addValue".         
            this.tiLog.M_Tank                            = oLogger.addValue('Example:c:CROP:s:CROP_Tank.toPhases.TankSolution', 'fMass', 'CROP_Tank Mass', 'kg'); % 1
            this.tiLog.M_BioFilter_Liquid                = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.FlowPhase', 'fMass', 'CROP_BioFilter Liquid Mass', 'kg'); % 2
            this.tiLog.M_CROP_BioFilter_Gas              = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.Atmosphere', 'fMass', 'CROP_BioFilter Gas Mass', 'kg'); % 3

            this.tiLog.FR_TanFlt                         = oLogger.addValue('Example:c:CROP.toBranches.Tank_to_BioFilter', 'fFlowRate', 'Flow Rate To CROP_BioFilter', 'kg/s'); % 4
            this.tiLog.FR_FltTan                         = oLogger.addValue('Example:c:CROP.toBranches.BioFilter_to_Tank', 'fFlowRate', 'Flow Rate From CROP_BioFilter', 'kg/s'); % 5
                       
            this.tiLog.M_CROP_BioFilter_Liquid_CH4N2O    = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.FlowPhase', 'afMass(this.oMT.tiN2I.CH4N2O)', 'CROP_BioFilter Liquid CH4N2O Mass', 'kg'); % 6
            this.tiLog.M_CROP_BioFilter_Liquid_NH3       = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.FlowPhase', 'afMass(this.oMT.tiN2I.NH3)', 'CROP_BioFilter Liquid NH3 Mass', 'kg'); % 7
            this.tiLog.M_CROP_BioFilter_Gas_CO2          = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.Atmosphere', 'afMass(this.oMT.tiN2I.CO2)', 'CROP_BioFilter Gas CO2 Mass', 'kg'); % 8
            this.tiLog.M_CROP_BioFilter_Gas_O2           = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.Atmosphere', 'afMass(this.oMT.tiN2I.O2)', 'CROP_BioFilter Gas O2 Mass', 'kg'); % 9
            this.tiLog.M_CROP_BioFilter_Liquid_NH4OH     = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.FlowPhase', 'afMass(this.oMT.tiN2I.NH4OH)', 'CROP_BioFilter Liquid NH4OH Mass', 'kg'); % 10
            
            this.tiLog.M_CROP_Tank_Liquid_CH4N2O         = oLogger.addValue('Example:c:CROP:s:CROP_Tank.toPhases.TankSolution', 'afMass(this.oMT.tiN2I.CH4N2O)', 'CROP_Tank Liquid CH4N2O Mass', 'kg'); % 11
            this.tiLog.M_CROP_Tank_Liquid_NH3            = oLogger.addValue('Example:c:CROP:s:CROP_Tank.toPhases.TankSolution', 'afMass(this.oMT.tiN2I.NH3)', 'CROP_Tank Liquid NH3 Mass', 'kg'); % 12
            this.tiLog.M_CROP_Tank_Liquid_NH4OH          = oLogger.addValue('Example:c:CROP:s:CROP_Tank.toPhases.TankSolution', 'afMass(this.oMT.tiN2I.NH4OH)', 'CROP_Tank Liquid NH4OH Mass', 'kg'); % 13
            
            this.tiLog.M_CROP_BioFilter_Liquid_HNO2      = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.FlowPhase', 'afMass(this.oMT.tiN2I.HNO2)', 'CROP_BioFilter Liquid HNO2 Mass', 'kg'); % 14
            this.tiLog.M_CROP_BioFilter_Liquid_HNO3      = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.FlowPhase', 'afMass(this.oMT.tiN2I.HNO3)', 'CROP_BioFilter Liquid HNO3 Mass', 'kg'); % 15
            this.tiLog.M_CROP_Tank_Liquid_HNO2           = oLogger.addValue('Example:c:CROP:s:CROP_Tank.toPhases.TankSolution', 'afMass(this.oMT.tiN2I.HNO2)', 'CROP_Tank Liquid HNO2 Mass', 'kg'); % 16
            this.tiLog.M_CROP_Tank_Liquid_HNO3           = oLogger.addValue('Example:c:CROP:s:CROP_Tank.toPhases.TankSolution', 'afMass(this.oMT.tiN2I.HNO3)', 'CROP_Tank Liquid HNO3 Mass', 'kg'); % 17
            
            this.tiLog.M_CROP_BioFilter_Liquid_pH        = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'fpH', 'CROP_BioFilter Liquid pH', '-'); % 18
            this.tiLog.M_CROP_BioFilter_Bio_CH4N2O       = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase', 'afMass(this.oMT.tiN2I.CH4N2O)', 'CROP_BioFilter Bio CH4N2O Mass', 'kg'); % 19
            this.tiLog.M_CROP_BioFilter_Bio_NH3          = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase', 'afMass(this.oMT.tiN2I.NH3)', 'CROP_BioFilter Bio NH3 Mass', 'kg'); % 20
            this.tiLog.M_CROP_BioFilter_Bio_NH4OH        = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase', 'afMass(this.oMT.tiN2I.NH4OH)', 'CROP_BioFilter Bio NH4OH Mass', 'kg'); % 21
            
            this.tiLog.M_CROP_BioFilter_Bio_CO2          = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase', 'afMass(this.oMT.tiN2I.CO2)', 'CROP_BioFilter Bio CO2 Mass', 'kg'); % 26
            this.tiLog.M_CROP_BioFilter_Bio_O2           = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase', 'afMass(this.oMT.tiN2I.O2)', 'CROP_BioFilter Bio O2 Mass', 'kg'); % 27
            this.tiLog.M_CROP_BioFilter_Bio_HNO2         = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase', 'afMass(this.oMT.tiN2I.HNO2)', 'CROP_BioFilter Bio HNO2 Mass', 'kg'); % 28
            this.tiLog.M_CROP_BioFilter_Bio_HNO3         = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase', 'afMass(this.oMT.tiN2I.HNO3)', 'CROP_BioFilter Bio HNO3 Mass', 'kg'); % 29
            
            
            this.tiLog.M_CROP_BioFilter_Bio_AE           = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(9)', 'CROP_BioFilter Liquid Bio A.E Concentration', 'mol/l'); % 30
            this.tiLog.M_CROP_BioFilter_Bio_AI           = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(11)', 'CROP_BioFilter Liquid Bio A.I Concentration', 'mol/l'); % 31
            this.tiLog.M_CROP_BioFilter_Bio_AEI          = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(12)', 'CROP_BioFilter Liquid Bio A.EI Concentration', 'mol/l'); % 32
            
            this.tiLog.M_CROP_BioFilter_Bio_BE           = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(16)', 'CROP_BioFilter Liquid Bio B.E Concentration', 'mol/l'); % 33
            this.tiLog.M_CROP_BioFilter_Bio_BI           = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(18)', 'CROP_BioFilter Liquid Bio B.I Concentration', 'mol/l'); % 34
            this.tiLog.M_CROP_BioFilter_Bio_BEI          = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(19)', 'CROP_BioFilter Liquid Bio B.EI Concentration', 'mol/l'); % 35
            
            this.tiLog.M_CROP_BioFilter_Bio_CE           = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(23)', 'CROP_BioFilter Liquid Bio C.E Concentration', 'mol/l'); % 36
            this.tiLog.M_CROP_BioFilter_Bio_CI           = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(25)', 'CROP_BioFilter Liquid Bio C.I Concentration', 'mol/l'); % 37
            this.tiLog.M_CROP_BioFilter_Bio_CEI          = oLogger.addValue('Example:c:CROP:s:CROP_BioFilter.toPhases.BioPhase.toManips.substance', 'afConcentration(26)', 'CROP_BioFilter Liquid Bio C.EI Concentration', 'mol/l'); % 38
            
        end
        
         function plot(this)
            % The plots are defined in this function. The detailed informations 
            % are included in the figure name.
                       
            try
                this.toMonitors.oLogger.readFromMat;
            catch
                disp('no data outputted yet')
            end
            
            oPlotter = plot@simulation.infrastructure(this);
            oLogger = oPlotter.oSimulationInfrastructure.toMonitors.oLogger;
            
         end
    end
    
end

