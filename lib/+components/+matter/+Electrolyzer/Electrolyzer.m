classdef Electrolyzer < vsys
    % model of a electrolyseur
    % calculates the required Voltage to cleave the water depending on
    % pressure and Temperatur
    properties
        fStackCurrent       = 0;    % current
        fCellVoltage        = 1.48; % cellvoltage
        fStackVoltage       = 12;   % stack voltage
        fPower              = 0;    % power of the stack
        iCells              = 100;  % number of cells
            
        % This property is used to store the current efficiency value of
        % the fuel cell. The efficiency is calculated dynamically within
        % the calculate_Voltage function
        rEfficiency = 1;
        
        % Area of the membrane for one cell
        fMembraneArea       = 25 / 10000;	% m^2
             
        % Thickness of the membrane in one cell
        fMembraneThickness  = 2*10^-6;      % m
        
        % The maximum current that can can pass through the membrane
        fMaxCurrentDensity  = 10000;       % A/m^2
    end
    
    methods
        function this = Electrolyzer(oParent, sName, fTimeStep, iCells, fMembraneArea, fMembraneThickness)
            
            this@vsys(oParent, sName, fTimeStep);
            
            this.iCells = iCells;
            
            if nargin > 4
                this.fMembraneArea = fMembraneArea;
            end
            if nargin > 5
                this.fMembraneThickness = fMembraneThickness;
            end
            
            this.fStackVoltage = this.iCells * this.fCellVoltage;
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Electrolyzer', 0.5);
            
            fInitialTemperature = 293;
            
            oMembrane   = matter.phases.mixture(this.toStores.Electrolyzer, 'Membrane', 'solid', struct('H2O',0.5,'H2',0.1,'O2',0.1), fInitialTemperature, 1e5);
            
            oH2         = this.toStores.Electrolyzer.createPhase(  'gas', 'flow', 'H2_Channel',   0.05, struct('H2', 1e5),  fInitialTemperature, 0.8);
            oO2         = this.toStores.Electrolyzer.createPhase(  'gas', 'flow', 'O2_Channel',   0.05, struct('O2', 1e5),  fInitialTemperature, 0.8);
            
            oWater      = this.toStores.Electrolyzer.createPhase(  'liquid',      'ProductWater',   0.1, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            oCooling    = this.toStores.Electrolyzer.createPhase(  'liquid',      'CoolingSystem',  0.1, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            % pipes
            components.matter.pipe(this, 'Pipe_H2_Out',          1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_Out',          1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Water_In',      1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_In',     1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_Out',    1.5, 0.003);
            
            % valves
            components.matter.valve(this,'Valve_H2', false);
            components.matter.valve(this,'Valve_O2', false);
            
            % branches
            matter.branch(this, oH2,        {'Valve_H2', 'Pipe_H2_Out'},  	'H2_Outlet',         'H2_Outlet');
            matter.branch(this, oO2,        {'Valve_O2', 'Pipe_O2_Out'},   	'O2_Outlet',         'O2_Outlet');
            matter.branch(this, oWater,     {'Pipe_Water_In'},              'Water_Inlet',       'Water_Inlet');
            
            matter.branch(this, oCooling,   {'Pipe_Cooling_In'},            'Cooling_Inlet',  	'Cooling_Inlet');
            matter.branch(this, oCooling,   {'Pipe_Cooling_Out'},           'Cooling_Outlet',	'Cooling_Outlet');
            
            %maipulator
            components.matter.Electrolyzer.components.ElectrolyzerReaction('ElectrolyzerReaction', oMembrane);
            
            components.matter.P2Ps.ManualP2P(this.toStores.Electrolyzer, 'H2_from_Membrane',    oMembrane,      oH2);
            components.matter.P2Ps.ManualP2P(this.toStores.Electrolyzer, 'O2_from_Membrane',    oMembrane,      oO2);
            components.matter.P2Ps.ManualP2P(this.toStores.Electrolyzer, 'H2O_to_Membrane',     oWater,         oMembrane);
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oElectrolyzerHeatSource = thermal.heatsource('Electrolyzer_HeatSource', 0);
            this.toStores.Electrolyzer.toPhases.CoolingSystem.oCapacity.addHeatSource(oElectrolyzerHeatSource);

        end
        
        function setIfFlows(this, H2_Outlet, O2_Outlet, Water_Inlet, Cooling_Inlet, Cooling_Outlet)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('H2_Outlet',         H2_Outlet);
            this.connectIF('O2_Outlet',         O2_Outlet);
            this.connectIF('Water_Inlet',       Water_Inlet);
            this.connectIF('Cooling_Outlet',    Cooling_Inlet);
            this.connectIF('Cooling_Inlet',     Cooling_Outlet);
            
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            tSolverProperties.fMaxError = 1e-6;
            tSolverProperties.iMaxIterations = 500;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;
            
            aoMultiSolverBranches = [this.toBranches.H2_Outlet;...
                                     this.toBranches.O2_Outlet;];
            
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            
            oWaterInlet = solver.matter.residual.branch(this.toBranches.Water_Inlet);
            oWaterInlet.setPositiveFlowDirection(false);
            
            solver.matter.manual.branch(this.toBranches.Cooling_Inlet);
            solver.matter.residual.branch(this.toBranches.Cooling_Outlet);
            
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
        
        function calculate_voltage(this)
            % calculate the voltage of the electrolyseur
            
            fTemperature = this.toStores.Electrolyzer.toPhases.CoolingSystem.fTemperature;
            
            %Partialpressure of H2 and O2 in the output phase
            fPressure_H2 = this.toStores.Electrolyzer.toPhases.H2_Channel.fPressure;
            fPressure_O2 = this.toStores.Electrolyzer.toPhases.O2_Channel.fPressure;
            
            fMaxCurrent = this.fMaxCurrentDensity * this.fMembraneArea;
            
            this.fStackCurrent = this.fPower / this.fStackVoltage;
            
            % TBD: where does this calue come from?
            fChangeCurrent = 0.01;
            
            %linearisation factor for gibbs energy
            fGibbsLinearization = 0.00085;
            
            % water content of the membrane 0-20 (no dynamic effects at the moment)
            % TO DO: add a dynamic calculation for this
            fWaterContent           = 14;
            fActivationCoefficient  = 0.4;
            fDiffusionCoefficient   = 0.8;
            
            fMembraneResistance = this.fMembraneThickness/(this.fMembraneArea*(0.005139*fWaterContent+0.00326)*exp(1267*(1/303-1/fTemperature))); %membrane resistentece of one cell
            %another case for p==0 and I==0 because of the log()
            if fPressure_H2 > 0
                if this.fStackCurrent > 0
                    this.fCellVoltage = 1.23+fGibbsLinearization*(fTemperature-298)+this.oMT.Const.fUniversalGas*fTemperature/2/this.oMT.Const.fFaraday*log(fPressure_H2*sqrt(fPressure_O2))+this.oMT.Const.fUniversalGas*fTemperature/2/this.oMT.Const.fFaraday/fActivationCoefficient*log(this.fStackCurrent/fChangeCurrent)+this.iCells*fMembraneResistance*this.fStackCurrent+this.oMT.Const.fUniversalGas*fTemperature/2/this.oMT.Const.fFaraday/fDiffusionCoefficient*log(1+this.fStackCurrent/fMaxCurrent);
                else
                    this.fCellVoltage = 1.48; %default value for starting
                end
            else
                this.fCellVoltage = 1.48;
            end
            
            this.rEfficiency = 1.48 / this.fCellVoltage;
            
            this.fStackVoltage = this.iCells * this.fCellVoltage;
            
            this.fStackCurrent = this.fPower / this.fStackVoltage;
            
            fHeatFlow = this.fStackCurrent * this.fStackVoltage * (1 - this.rEfficiency);
            
            this.toStores.Electrolyzer.toPhases.CoolingSystem.oCapacity.toHeatSources.Electrolyzer_HeatSource.setHeatFlow(fHeatFlow);
        end
        
        function setPower(this, fPower)
            this.fPower = fPower;
            
            this.calculate_voltage();
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            this.calculate_voltage();
        end
    end
end