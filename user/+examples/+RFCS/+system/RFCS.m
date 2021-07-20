classdef RFCS < vsys
    % This is an example model of a Regnerative Fuel Cell System, which
    % combines an electrolyzer, a fuel cell and H2, O2 and water tanks to
    % simulate an energy storage system. This example assumes solar cells
    % with a solar profile from earth as the energy input
    properties
        % array which contains the available solar power
        afPower;
        
        fSolarPanelArea         = 50; %m^2 solarpanele
        rSolarpanelEfficiency   = 0.12;
        fElectricalPayloadPower = 350; % W
    end
    
    methods
        function this = RFCS(oParent, sName, fSolarPanelArea, rSolarpanelEfficiency)
            
            this@vsys(oParent, sName, 5*60);
            eval(this.oRoot.oCfgParams.configCode(this));
            
            if nargin > 2
                this.fSolarPanelArea        = fSolarPanelArea;
            end
            if nargin > 3
                this.rSolarpanelEfficiency  = rSolarpanelEfficiency;
            end
            
            this.afPower = xlsread(strrep('user\+examples\+RFCS\+helper\HAPS_AvailableSolarPower.xlsx','\',filesep),'B40:C327');
            
            this.afPower(:,2) = this.afPower(:,2) .* this.rSolarpanelEfficiency .* this.fSolarPanelArea;
            
            tInputsEly.iCells               = 30;
            tInputsEly.fMembraneArea        = 1e-2;
            tInputsEly.fMembraneThickness   = 50e-6;
            tInputsEly.fMaxCurrentDensity   = 20000;
            
            components.matter.Electrolyzer.Electrolyzer(this, 'Electrolyzer', 5*60, tInputsEly);
            
            tInputsFC.iCells               = 30;
            components.matter.FuelCell.FuelCell(this, 'FuelCell', 5*60, tInputsFC);
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %stores and phases
            % water tank
            
            fInitialTemperature = 293;
            
            matter.store(this, 'Water_Tank', 0.004);
            oWater      = this.toStores.Water_Tank.createPhase(  'liquid',      'Water',   0.004, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            matter.store(this, 'CoolingSystem', 0.1);
            oCooling    = this.toStores.CoolingSystem.createPhase('liquid',     'CoolingWater',  0.1, struct('H2O', 1),  340, 1e5);
            
            matter.store(this, 'H2_Tank', 0.1);
            oH2         = this.toStores.H2_Tank.createPhase(  'gas', 'H2',   0.1, struct('H2', 50e5),  fInitialTemperature, 0.8);
            
            matter.store(this, 'O2_Tank', 0.05);
            oO2         = this.toStores.O2_Tank.createPhase(  'gas', 'O2',   0.05, struct('O2', 50e5),  fInitialTemperature, 0.8);
            
            %radiator area= 3.5m^2
            examples.RFCS.components.radiator(this, 'Radiator', 3.5, 0.4);
            
            components.matter.pipe(this, 'Radiator_Pipe',          3, 0.002);
            
            %% RFCS Connection
            matter.branch(this, oCooling,                       {'Radiator_Pipe', 'Radiator'},	oCooling,         'Radiator_Cooling');
            
            %% Fuel Cell Connections
            matter.branch(this, 'FuelCell_H2_Inlet',            {},                             oH2);
            matter.branch(this, 'FuelCell_O2_Inlet',            {},                             oO2);
            matter.branch(this, 'FuelCell_Water_Outlet',    	{},                             oWater);
            
            matter.branch(this, 'FuelCell_Cooling_Inlet',       {},                             oCooling);
            matter.branch(this, 'FuelCell_Cooling_Outlet',      {},                             oCooling);
            
            %% Electrolyzer Connections
            matter.branch(this, 'Electrolyzer_H2_Outlet',    	{},                             oH2);
            matter.branch(this, 'Electrolyzer_O2_Outlet',     	{},                             oO2);
            matter.branch(this, 'Electrolyzer_Water_Inlet',    	{},                             oWater);
            
            matter.branch(this, 'Electrolyzer_Cooling_Inlet',   {},                             oCooling);
            matter.branch(this, 'Electrolyzer_Coooling_Outlet',	{},                             oCooling);
            
            this.toChildren.FuelCell.setIfFlows('FuelCell_H2_Inlet', 'FuelCell_O2_Inlet', 'FuelCell_Cooling_Inlet', 'FuelCell_Cooling_Outlet', 'FuelCell_Water_Outlet')
            this.toChildren.Electrolyzer.setIfFlows('Electrolyzer_H2_Outlet', 'Electrolyzer_O2_Outlet', 'Electrolyzer_Water_Inlet', 'Electrolyzer_Cooling_Inlet', 'Electrolyzer_Coooling_Outlet')
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.Radiator_Cooling);
            
            csStores = fieldnames(this.toStores);
            % sets numerical properties for the phases of CDRA
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    
                    tTimeStepProperties.rMaxChange = 0.1;
                    tTimeStepProperties.fMaxStep = this.fTimeStep;

                    oPhase.setTimeStepProperties(tTimeStepProperties);
                        
                end
            end
            
            %% Assign thermal solvers
            this.setThermalSolvers();
        end
        
        
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            %second circle heat exchanger
            
            %this is the solar avaliable Solarpower read from a excel sheet
            %minus the required power for the pay load, you get the power
            %supply for the electrolyseur
            
            % Assume we start the simulation at noon therefore the + 0.5
            fCurrentTime = (this.oTimer.fTime/(24*3600)) + 0.5;
            
            afTimeDataPoints = abs(this.afPower(:,1) - mod(fCurrentTime, 1));
            
            fAvailablePower = this.afPower(afTimeDataPoints == min(afTimeDataPoints),2) - this.fElectricalPayloadPower;
            
            % Now we tell the subsystem either how much power is available
            % (in case the electrolyzer is operating) or how much power is
            % required for the operation of the payload
            if fAvailablePower > 0
                
                fLowestTankPressure = min(this.toStores.H2_Tank.toPhases.H2.fPressure, this.toStores.O2_Tank.toPhases.O2.fPressure);
                if fLowestTankPressure > 50e5
                    % reduce the power we set to the electrolyzer after we
                    % reach 50 bar pressure to increase efficiency. The
                    % function is selected so that after 80 bar only a few
                    % percent of the power are still used
                    fSetPower = (1 / ((fLowestTankPressure - 40e5) / 10e5)^2) * fAvailablePower;
                else
                    fSetPower = fAvailablePower;
                end
                this.toChildren.Electrolyzer.setPower(fSetPower);
                this.toChildren.FuelCell.setPower(0);
                
            else
                this.toChildren.Electrolyzer.setPower(0);
                this.toChildren.FuelCell.setPower(-fAvailablePower);
            end
            
            % The target temperature for the electrolyzer and fuel cell is
            % 65degC therefore, we regulate the coolant temperature to this
            % value. Since both systems produce heat, we only set a flow
            % through the radiator if the temperature is higher than 65degC
            fDeltaTemperature = this.toStores.CoolingSystem.toPhases.CoolingWater.fTemperature - 338.15;
            if fDeltaTemperature > 0
                this.toBranches.Radiator_Cooling.oHandler.setFlowRate(0.2 * fDeltaTemperature);
            else
                this.toBranches.Radiator_Cooling.oHandler.setFlowRate(0);
            end
            
            this.oTimer.synchronizeCallBacks();
        end
    end
end