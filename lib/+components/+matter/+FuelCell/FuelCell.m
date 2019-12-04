classdef FuelCell < vsys
    %PEM- Fuel cell build with 2 gaschanals and a membrane in between
    
    properties (SetAccess = protected, GetAccess = public)
        %number of cells of the fuelcell stack
        iCells = 30;
        
        % Area of the membrane for one cell
        fMembraneArea       = 250 / 10000;	% m^2
             
        % Thickness of the membrane in one cell
        fMembraneThickness  = 2*10^-6;      % m
        
        % The maximum current that can can pass through the membrane
        fMaxCurrentDensity  = 4000;       % A/m^2
        
        % This property is used to store the current efficiency value of
        % the fuel cell. The efficiency is calculated dynamically within
        % the calculate_Voltage function
        rEfficiency = 1;
        
        fStackCurrent = 0; % A
        fStackVoltage; % V
        
        fPower = 0; %electric power of the fuel cell stack
        
        fStackZeroPotential = 1;
        
        % Maximum ratio of H2/O2 that passes through the fuel cell that can be
        % reacted. For 1 all of the H2/O2 can be reacted
        rMaxReactingH2 = 0.5;
        rMaxReactingO2 = 0.5;
    end
    
    
    methods
        function this = FuelCell(oParent, sName, fTimeStep, iCells, tOptionalInputs)
            % The optional input struct can contain the following fields:
            % fMembraneArea
            % fMembraneThickness
            % fMaxCurrentDensity
            % rMaxReactingH2
            % rMaxReactingO2
            
            this@vsys(oParent, sName, fTimeStep);
            
            this.iCells = iCells;
            
            if nargin > 4
                csFields = fieldnames(tOptionalInputs);
                csValidFields = {'fMembraneArea',...
                                 'fMembraneThickness',...
                                 'fMaxCurrentDensity',...
                                 'rMaxReactingH2',...
                                 'rMaxReactingO2'};
                for iField = 1:length(csFields)
                    if any(strcmp(csValidFields, csFields{iField}))
                        this.(csFields{iField}) = tOptionalInputs.(csFields{iField});
                    else
                        error(['Invalid input ', csFields{iField}, ' for the Fuel Cell']);
                    end
                end
            end
            
            this.fStackVoltage = this.iCells * 1.23;
            
            eval(this.oRoot.oCfgParams.configCode(this));
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            fInitialTemperature = 293.15; %initial Temperatur of all phases of the fuelcell
            
            % The fuel cell is created as one store, containing the
            % different parts of the fuel cell. The store is therefore
            % split into different phases, to represent the different
            % components (H2 Channel, O2 Channel, Membrane, Cooling System)
            matter.store(this, 'FuelCell', 0.5);
            
            oH2 =       this.toStores.FuelCell.createPhase(  'gas', 'flow', 'H2_Channel',   0.025, struct('H2', 1e5),  fInitialTemperature, 0.8);
            oH2_Out =   this.toStores.FuelCell.createPhase(  'gas', 'flow', 'H2_Outlet',    0.025, struct('H2', 1e5),  fInitialTemperature, 0.8);
            oO2 =       this.toStores.FuelCell.createPhase(  'gas', 'flow', 'O2_Channel',   0.05, struct('O2', 1e5),  fInitialTemperature, 0.8);
            
            oMembrane = this.toStores.FuelCell.createPhase(  'gas',         'Membrane',     0.3, struct('O2', 0.5e5, 'H2', 0.5e5),  fInitialTemperature, 0.8);
            
            oCooling =  this.toStores.FuelCell.createPhase(  'liquid',      'CoolingSystem',0.1, struct('H2O', 1),  340, 1e5);
            
            matter.store(this, 'O2_WaterSeperation', 0.01);
            oO2_Dryer       = this.toStores.O2_WaterSeperation.createPhase(  'gas', 'flow', 'O2',   1e-6, struct('O2', 1e5),  fInitialTemperature, 0.8);
            oRecoveredWater = this.toStores.O2_WaterSeperation.createPhase(  'liquid',      'Water',   0.01, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            components.matter.FuelCell.components.Dryer(this.toStores.O2_WaterSeperation, 'Dryer', oO2_Dryer, oRecoveredWater, 0.9, 'H2O');
            
            % pipes
            components.matter.pipe(this, 'Pipe_H2_In',          1.5, 0.003);
            components.matter.pipe(this, 'Pipe_H2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_In',          1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_In',     1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_Out',    1.5, 0.003);
            
            % valves
            components.matter.valve(this,'Valve_H2', false);
            components.matter.valve(this,'Valve_O2', false);
            
            % fans
            components.matter.fan_simple(this, 'H2_Compressor', 2e5, false);
            components.matter.fan_simple(this, 'O2_Compressor', 2e5, false);
            
            % Internal Branches
            matter.branch(this, oH2,                {'H2_Compressor'},          oH2_Out,            'H2_to_Outlet');
            matter.branch(this, oO2,                {'O2_Compressor'},          oO2_Dryer,          'O2_to_Dryer');
            
            % Interfaces branches
            matter.branch(this, oH2,                {'Valve_H2', 'Pipe_H2_In'},	'H2_Inlet',         'H2_Inlet');
            matter.branch(this, oH2_Out,          	{'Pipe_H2_Out'},            'H2_Outlet',        'H2_Outlet');
            
            matter.branch(this, oO2,                {'Valve_O2', 'Pipe_O2_In'},	'O2_Inlet',         'O2_Inlet');
            matter.branch(this, oO2_Dryer,          {'Pipe_O2_Out'},            'O2_Outlet',        'O2_Outlet');
            
            
            matter.branch(this, oCooling,           {'Pipe_Cooling_In'},        'Cooling_Inlet',  	'Cooling_Inlet');
            matter.branch(this, oCooling,           {'Pipe_Cooling_Out'},       'Cooling_Outlet',	'Cooling_Outlet');
            
            matter.branch(this, oRecoveredWater,  	{},                         'Water_Outlet',     'Water_Outlet');
            
            % adding the fuel cell reaction manip
            components.matter.FuelCell.components.FuelCellReaction('FuelCellReaction', oMembrane);
            
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'H2_to_Membrane',  oH2,        oMembrane);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'O2_to_Membrane',  oO2,        oMembrane);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'Membrane_to_O2',  oMembrane,  oO2);
        end
        
        function setIfFlows(this, H2_Inlet, H2_Outlet, O2_Inlet, O2_Outlet, Cooling_Inlet, Cooling_Outlet, Water_Outlet)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('H2_Inlet',          H2_Inlet);
            this.connectIF('H2_Outlet',         H2_Outlet);
            this.connectIF('O2_Inlet',          O2_Inlet);
            this.connectIF('O2_Outlet',         O2_Outlet);
            this.connectIF('Cooling_Inlet',     Cooling_Inlet);
            this.connectIF('Cooling_Outlet',    Cooling_Outlet);
            this.connectIF('Water_Outlet',      Water_Outlet);
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oFuelCellHeatSource = thermal.heatsource('FuelCell_HeatSource', 0);
            this.toStores.FuelCell.toPhases.CoolingSystem.oCapacity.addHeatSource(oFuelCellHeatSource);

        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            tSolverProperties.fMaxError = 1e-6;
            tSolverProperties.iMaxIterations = 500;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;
            
            aoMultiSolverBranches = [this.toBranches.H2_Inlet;...
                                     this.toBranches.H2_to_Outlet;...
                                     this.toBranches.H2_Outlet;...
                                     this.toBranches.O2_Inlet;...
                                     this.toBranches.O2_to_Dryer;...
                                     this.toBranches.O2_Outlet];
            
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            
            solver.matter.manual.branch(this.toBranches.Cooling_Inlet);
            solver.matter.residual.branch(this.toBranches.Cooling_Outlet);
            
            solver.matter.residual.branch(this.toBranches.Water_Outlet);
            
            
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
            % calculate the voltage of the fuel cell
            % depending on input partial-pressure temperature
            % current and internal resistance
            
            fTemperature = this.toStores.FuelCell.toPhases.CoolingSystem.fTemperature;
            
            fMaxCurrent = this.fMaxCurrentDensity * this.fMembraneArea;
            
            fCurrentH2InletFlow = abs(this.toBranches.H2_Inlet.fFlowRate * this.toBranches.H2_Inlet.aoFlows(1).arPartialMass(this.oMT.tiN2I.H2));
            fCurrentO2InletFlow = abs(this.toBranches.O2_Inlet.fFlowRate * this.toBranches.O2_Inlet.aoFlows(1).arPartialMass(this.oMT.tiN2I.O2));
            
            fMolarFlowH2 = this.rMaxReactingH2 * fCurrentH2InletFlow / this.oMT.afMolarMass(this.oMT.tiN2I.H2);
            fMolarFlowO2 = this.rMaxReactingO2 * fCurrentO2InletFlow / this.oMT.afMolarMass(this.oMT.tiN2I.O2);
            if fMolarFlowH2 > 2 * fMolarFlowO2
                % In this case O2 limits the amount of H2 that can be
                % reacted O2 + 2*H2 -> 2*H2O
                fMolarFlowH2 = 2 * fMolarFlowO2;
            end
            fMaxCurrentH2 = (fMolarFlowH2 / this.iCells) * (2 * this.oMT.Const.fFaraday);
            
            if fMaxCurrentH2 < fMaxCurrent
                fMaxCurrent = fMaxCurrentH2;
            end
            
            this.fStackCurrent = this.fPower / this.fStackVoltage;
            
            if this.fStackCurrent > fMaxCurrent
                this.fStackCurrent = fMaxCurrent;
                this.fPower = this.fStackCurrent * this.fStackVoltage;
            end
            
            % TBD: where does this calue come from?
            fChangeCurrent = 0.01;
            
            %linearisation factor for gibbs energy
            fGibbsLinearization = 0.00085;
            
            % water content of the membrane 0-20 (no dynamic effects at the moment)
            % TO DO: add a dynamic calculation for this
            fWaterContent           = 14;
            fActivationCoefficient  = 0.4;
            fDiffusionCoefficient   = 0.8;
            
            %calculating the resistence of the membrane
            fMembraneResistance = this.fMembraneThickness/(this.fMembraneArea*(0.005139*fWaterContent+0.00326)*exp(1267*(1/303-1 / fTemperature)));
            
            %timeconstant of the output capacity
            fTau = 2;
            
            fPressure_H2 = this.toStores.FuelCell.toPhases.H2_Channel.afPP(this.oMT.tiN2I.H2);
            fPressure_O2 = this.toStores.FuelCell.toPhases.O2_Channel.afPP(this.oMT.tiN2I.O2);
            
            %calculate the static stack voltage
            if this.fStackCurrent > 0
                % TO DO: split equation up to make it easier to follow and
                % add source for the calculation
                % TO DO: Find reference for the 1.23 value, should be the
                % potential for hydrogen in V, but that should also be
                % adaptable or calculated based on oMT
                fNewVoltage = this.iCells * (1.23 - fGibbsLinearization * (fTemperature - 298) +...
                    this.oMT.Const.fUniversalGas * fTemperature / (2 * this.oMT.Const.fFaraday) *...
                    log(fPressure_H2 * sqrt(fPressure_O2)) - this.oMT.Const.fUniversalGas * fTemperature / (2 * this.oMT.Const.fFaraday) /fActivationCoefficient*log(this.fStackCurrent/fChangeCurrent)-fMembraneResistance*this.fStackCurrent-this.oMT.Const.fUniversalGas* fTemperature /2/ this.oMT.Const.fFaraday /fDiffusionCoefficient*log(1+this.fStackCurrent/fMaxCurrent));
            else
                %another function for the case i==0 because of the log()
                fNewVoltage = this.iCells * (1.23-fGibbsLinearization*(fTemperature - 298)+ this.oMT.Const.fUniversalGas * fTemperature /2/ this.oMT.Const.fFaraday *log(fPressure_H2*sqrt(fPressure_O2)));
            end
            
            %zero potential of the cell
            this.fStackZeroPotential = 1.23 - fGibbsLinearization*(fTemperature - 298)+ this.oMT.Const.fUniversalGas * fTemperature /2/ this.oMT.Const.fFaraday *log(fPressure_H2*sqrt(fPressure_O2));
            
            % the euler equation
            if ~isempty(this.toStores.FuelCell.toPhases.Membrane.fTimeStep) && this.toStores.FuelCell.toPhases.Membrane.fTimeStep < 1
                this.fStackVoltage = this.fStackVoltage + this.oPhase.fTimeStep * (fNewVoltage - this.fStackVoltage) * fTau;
            end
            
            this.fStackCurrent = this.fPower / this.fStackVoltage;
            
            % efficiency is calculatet by using the current voltage of the single cell
            % and the open circuit voltage regarding to current pressure and
            % temperature (fVoltage = Stack voltage)
            this.rEfficiency = (this.fStackVoltage / this.iCells) / this.fStackZeroPotential;
            
            % Now calculate the heat flow of the fuel cell and set it to
            % the heat source of the cooling system. The heatsource could
            % also be placed in the membrane and the thermal conduction of
            % the heat to the coolant channel could be calculated, but this
            % is simplified in this fuel cell
            fHeatFlow = this.fStackCurrent * this.fStackVoltage * (1 - this.rEfficiency);
            
            this.toStores.FuelCell.toPhases.CoolingSystem.oCapacity.toHeatSources.FuelCell_HeatSource.setHeatFlow(fHeatFlow);
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