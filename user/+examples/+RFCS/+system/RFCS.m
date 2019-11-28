classdef RFCS < vsys
    
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
            
            this.afPower = xlsread('user\+examples\+RFCS\+helper\HAPS Available Solar Power.xlsx','B40:C327');
            
            this.afPower(:,2) = this.afPower(:,2) .* this.rSolarpanelEfficiency .* this.fSolarPanelArea;
            
            components.matter.Electrolyzer.Electrolyzer(this, 'Electrolyzer', 5*60, 100);
            components.matter.FuelCell.FuelCell(this, 'FuelCell', 5*60, 30);
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            %stores and phases
            % water tank
            
            fInitialTemperature = 293;
            
            matter.store(this, 'Water_Tank', 0.1);
            oWater      = this.toStores.Water_Tank.createPhase(  'liquid',      'Water',   0.1, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            matter.store(this, 'CoolingSystem', 0.1);
            oCooling    = this.toStores.CoolingSystem.createPhase('liquid',     'CoolingWater',  0.1, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            matter.store(this, 'H2_Tank', 0.1);
            oH2         = this.toStores.H2_Tank.createPhase(  'gas', 'H2',   0.1, struct('H2', 50e5),  fInitialTemperature, 0.8);
            
            matter.store(this, 'O2_Tank', 0.05);
            oO2         = this.toStores.O2_Tank.createPhase(  'gas', 'O2',   0.05, struct('O2', 50e5),  fInitialTemperature, 0.8);
            
            tCharacteristic = struct(...
                ...% Upper and speed and respective characteristic function
                'fSpeedUpper', 100000, ...
                'calculateUpperDeltaP', @(fVolumetricFlowRate) 30*10^5-fVolumetricFlowRate*2*10^5*10^4, ...
                ...% Lower and speed and respective characteristic function
                'fSpeedLower', 1000, ...
                'calculateLowerDeltaP', @(fVolumetricFlowRate) 0.03*10^5-fVolumetricFlowRate*0.002*10^5*10^4, ...
                ...% Pressure, temperature, gas constant and density of the gas
                ...% used during the determination of the characteristic
                'fTestPressure',    29649, ...      Pa
                'fTestTemperature',   294.26, ...   K
                'fTestGasConstant',   287.058, ...  J/kgK
                'fTestDensity',         0.3510, ...  kg/m3
                'fZeroCrossingUpper',   0.007, ...  m^3/s
                'fZeroCrossingLower',   0.0048 ...  m^3/s
                );
        
            components.matter.fan(this, 'O2_Compressor', 100000, tCharacteristic);
            components.matter.fan(this, 'H2_Compressor', 100000, tCharacteristic);
            
%             %heat exchanger
%             %defines the heat exchanged object using the previously created properties
%             sHX_type = 'CounterPlate';
%             tHX_Parameters.fBroadness       = 1;    % broadness of the heat exchange area in m
%             tHX_Parameters.fHeight_1        = 0.15; % Height of the channel for fluid 1 in m
%             tHX_Parameters.fHeight_2        = 0.15; % Height of the channel for fluid 2 in m
%             tHX_Parameters.fLength          = 5;    % length of the heat exchanger in m
%             tHX_Parameters.fThickness       = 0.01; % thickness of the plate in m
%             
%             % Assume aluminium with 230W/K/m
%             Conductivity = 230;                          % Conductivity of the Heat exchanger solid material
%             
%             %defines the heat exchanged object using the previously created properties
%             components.matter.HX(this, 'FuelCell_HeatExchanger', tHX_Parameters, sHX_type, Conductivity);
%             components.matter.HX(this, 'Electrolyzer_HeatExchanger', tHX_Parameters, sHX_type, Conductivity);
            
            
            %valves
            components.matter.valve(this,'FuelCell_Valve_H2', false);
            components.matter.valve(this,'FuelCell_Valve_O2', false);
            
            components.matter.valve(this,'Electrolyzer_Valve_H2', false);
            components.matter.valve(this,'Electrolyzer_Valve_O2', false);
            
            %radiator area= 3.5m^2
            examples.RFCS.components.radiator(this, 'Radiator', 3.5, 0.4);
            
            components.matter.pipe(this, 'Radiator_Pipe',          3, 0.002);
            
            %% RFCS Connection
            matter.branch(this, oCooling,                       {'Radiator_Pipe', 'Radiator'},	oCooling,         'Radiator_Cooling');
            
            %% Fuel Cell Connections
            matter.branch(this, 'FuelCell_H2_Inlet',            {'FuelCell_Valve_H2'},      	oH2);
            matter.branch(this, 'FuelCell_H2_Outlet',       	{'H2_Compressor'},            	oH2);
            
            matter.branch(this, 'FuelCell_O2_Inlet',            {'FuelCell_Valve_O2'},       	oO2);
            matter.branch(this, 'FuelCell_O2_Outlet',           {'O2_Compressor'},          	oO2);
            
            matter.branch(this, 'FuelCell_Water_Outlet',    	{},                             oWater);
            
            matter.branch(this, 'FuelCell_Cooling_Inlet',       {},                             oCooling);
            matter.branch(this, 'FuelCell_Cooling_Outlet',      {},                             oCooling);
            
            %% Electrolyzer Connections
            matter.branch(this, 'Electrolyzer_H2_Outlet',    	{'Electrolyzer_Valve_H2'},      oH2);
            matter.branch(this, 'Electrolyzer_O2_Outlet',     	{'Electrolyzer_Valve_O2'},  	oO2);
            matter.branch(this, 'Electrolyzer_Water_Inlet',    	{},                             oWater);
            
            matter.branch(this, 'Electrolyzer_Cooling_Inlet',   {},                             oCooling);
            matter.branch(this, 'Electrolyzer_Coooling_Outlet',	{},                             oCooling);
            
            this.toChildren.FuelCell.setIfFlows('FuelCell_H2_Inlet', 'FuelCell_H2_Outlet', 'FuelCell_O2_Inlet', 'FuelCell_O2_Outlet', 'FuelCell_Water_Outlet', 'FuelCell_Cooling_Inlet', 'FuelCell_Cooling_Outlet')
            this.toChildren.Electrolyzer.setIfFlows('Electrolyzer_H2_Outlet', 'Electrolyzer_O2_Outlet', 'Electrolyzer_Water_Inlet', 'Electrolyzer_Cooling_Inlet', 'Electrolyzer_Coooling_Outlet')
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.manual.branch(this.toBranches.Radiator_Cooling);
            
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
                this.toChildren.Electrolyzer.setPower(fAvailablePower);
                this.toChildren.FuelCell.setPower(0);
                
                this.toChildren.Electrolyzer.toBranches.Cooling_Inlet.setFlowRate(-0.1);
                this.toChildren.FuelCell.toBranches.Cooling_Inlet.setFlowRate(0);
                
                if ~this.toProcsF2F.Electrolyzer_Valve_H2.bOpen
                    this.toProcsF2F.Electrolyzer_Valve_H2.setOpen(true);
                end
                if ~this.toProcsF2F.Electrolyzer_Valve_O2.bOpen
                    this.toProcsF2F.Electrolyzer_Valve_O2.setOpen(true);
                end
                
                if this.toProcsF2F.FuelCell_Valve_H2.bOpen
                    this.toProcsF2F.H2_Compressor.switchOff();
                    this.toProcsF2F.FuelCell_Valve_H2.setOpen(false);
                end
                if this.toProcsF2F.FuelCell_Valve_O2.bOpen
                    this.toProcsF2F.O2_Compressor.switchOff();
                    this.toProcsF2F.FuelCell_Valve_O2.setOpen(false);
                end
                
                
            else
                this.toChildren.Electrolyzer.setPower(0);
                this.toChildren.FuelCell.setPower(-fAvailablePower);
                
                this.toChildren.Electrolyzer.toBranches.Cooling_Inlet.setFlowRate(0);
                this.toChildren.FuelCell.toBranches.Cooling_Inlet.setFlowRate(-0.1);
                
                if ~this.toProcsF2F.Electrolyzer_Valve_H2.bOpen
                    this.toProcsF2F.Electrolyzer_Valve_H2.setOpen(false);
                end
                if ~this.toProcsF2F.Electrolyzer_Valve_O2.bOpen
                    this.toProcsF2F.Electrolyzer_Valve_O2.setOpen(false);
                end
            end
            
            % Already start supplying the fuel cell with hydrogen and
            % oxygen before it is required. No electricity is generated
            % beforehand because the electric circuit is not yet closed
            if fAvailablePower < 50
                if ~this.toProcsF2F.FuelCell_Valve_H2.bOpen
                    this.toProcsF2F.H2_Compressor.switchOn();
                    this.toProcsF2F.FuelCell_Valve_H2.setOpen(true);
                end
                if ~this.toProcsF2F.FuelCell_Valve_O2.bOpen
                    this.toProcsF2F.O2_Compressor.switchOn();
                    this.toProcsF2F.FuelCell_Valve_O2.setOpen(true);
                end
            end
            
            % The target temperature for the electrolyzer and fuel cell is
            % 65°C therefore, we regulate the coolant temperature to this
            % value. Since both systems produce heat, we only set a flow
            % through the radiator if the temperature is higher than 65°C
            fDeltaTemperature = this.toStores.CoolingSystem.toPhases.CoolingWater.fTemperature - 338.15;
            if fDeltaTemperature > 0
                this.toBranches.Radiator_Cooling.setFlowRate(0.2 * fDeltaTemperature);
            else
                this.toBranches.Radiator_Cooling.setFlowRate(0);
            end
            
        end
    end
end