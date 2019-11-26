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
        
        fTemperature; %temperatur of the fuel cell stack
        fPower = 0; %electric power of the fuel cell stack
        
        fStackZeroPotential = 1;
    end
    
    
    methods
        function this = FuelCell(oParent, sName, iCells, fMembraneArea, fMembraneThickness)
            
            this@vsys(oParent, sName, 30);
            
            this.iCells = iCells;
            
            if nargin > 3
                this.fMembraneArea = fMembraneArea;
            end
            if nargin > 4
                this.fMembraneThickness = fMembraneThickness;
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
            
            oH2 =       this.toStores.FuelCell.createPhase(  'gas', 'flow', 'H2_Channel',   0.05, struct('H2', 1e5),  fInitialTemperature, 0.8);
            oO2 =       this.toStores.FuelCell.createPhase(  'gas', 'flow', 'O2_Channel',   0.05, struct('O2', 1e5),  fInitialTemperature, 0.8);
            
            oMembrane = this.toStores.FuelCell.createPhase(  'gas',         'Membrane',     0.3, struct('O2', 0.5e5, 'H2', 0.5e5),  fInitialTemperature, 0.8);
            
            oCooling =  this.toStores.FuelCell.createPhase(  'liquid',      'CoolingSystem',0.1, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            % pipes
            components.matter.pipe(this, 'Pipe_H2_In',          1.5, 0.003);
            components.matter.pipe(this, 'Pipe_H2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_In',          1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_In',     1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_Out',    1.5, 0.003);
            
            % branches
            matter.branch(this, oH2,        {'Pipe_H2_In'},         'H2_Inlet',         'H2_Inlet');
            matter.branch(this, oH2,        {'Pipe_H2_Out'},        'H2_Outlet',        'H2_Outlet');
            
            matter.branch(this, oO2,        {'Pipe_O2_In'},         'O2_Inlet',         'O2_Inlet');
            matter.branch(this, oO2,        {'Pipe_O2_Out'},        'O2_Outlet',        'O2_Outlet');
            
            matter.branch(this, oCooling,   {'Pipe_Cooling_In'},    'Cooling_Inlet',  	'Cooling_Inlet');
            matter.branch(this, oCooling,   {'Pipe_Cooling_Out'},   'Coooling_Outlet',	'Cooling_Outlet');
            
            % adding the fuel cell reaction manip
            components.matter.FuelCell.components.FuelCellReaction('FuelCellReaction', oMembrane);
            
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'H2_to_Membrane',  oH2,        oMembrane);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'Membrane_to_H2',  oMembrane,  oH2);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'O2_to_Membrane',  oO2,        oMembrane);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'Membrane_to_O2',  oMembrane,  oO2);
        end
        
        function setIfFlows(this, sInlet1,sInlet2, sOutlet1,sOutlet2,sOutlet3,sInlet_cooling,sOutlet_cooling)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('Inlet1',  sInlet1);
            this.connectIF('Inlet2',  sInlet2);
            this.connectIF('Outlet1', sOutlet1);
            this.connectIF('Outlet2', sOutlet2);
            this.connectIF('Outlet3', sOutlet3);
            this.connectIF('Outlet_cooling', sOutlet_cooling);
            this.connectIF('Inlet_cooling', sInlet_cooling);
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
                                     this.toBranches.H2_Outlet;...
                                     this.toBranches.O2_Inlet;...
                                     this.toBranches.O2_Outlet;];
            
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            
            oCoolingInlet = solver.matter.residual.branch('Cooling_Inlet');
            oCoolingInlet.setPositiveFlowDirection(false);
            
            solver.matter.residual.branch('Cooling_Outlet');
            
            %% Assign thermal solvers
            this.setThermalSolvers();
        end
        
        function calculate_voltage(this)
            % calculate the voltage of the fuel cell
            % depending on input partial-pressure temperature
            % current and internal resistance
            
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
            
            %calculating the resistence of the membrane
            fMembraneResistance = this.fMembraneThickness/(this.fMembraneArea*(0.005139*fWaterContent+0.00326)*exp(1267*(1/303-1 / this.fTemperature)));
            
            %timeconstant of the output capacity
            fTau = 2;
            
            fPressure_H2 = this.toStores.H2_Inlet.afPP(this.oMT.tiN2I.H2);
            fPressure_O2 = this.toStores.H2_Inlet.afPP(this.oMT.tiN2I.O2);
            
            %calculate the static stack voltage
            if this.fStackCurrent > 0
                % TO DO: split equation up to make it easier to follow and
                % add source for the calculation
                % TO DO: Find reference for the 1.23 value, should be the
                % potential for hydrogen in V, but that should also be
                % adaptable or calculated based on oMT
                fNewVoltage = this.iCells * (1.23 - fGibbsLinearization * (this.fTemperature - 298) +...
                    this.oMT.Const.fUniversalGas * this.fTemperature / (2 * this.oMT.Const.fFaraday) *...
                    log(fPressure_H2 * sqrt(fPressure_O2)) - this.oMT.Const.fUniversalGas * this.fTemperature / (2 * this.oMT.Const.fFaraday) /fActivationCoefficient*log(this.fStackCurrent/fChangeCurrent)-fMembraneResistance*this.fStackCurrent-this.oMT.Const.fUniversalGas* this.fTemperature /2/ this.oMT.Const.fFaraday /fDiffusionCoefficient*log(1+this.fStackCurrent/fMaxCurrent));
            else
                %another function for the case i==0 because of the log()
                fNewVoltage = this.iCells * (1.23-fGibbsLinearization*(this.fTemperature - 298)+ this.oMT.Const.fUniversalGas * this.fTemperature /2/ this.oMT.Const.fFaraday *log(fPressure_H2*sqrt(fPressure_O2)));
            end
            
            %zero potential of the cell
            this.fStackZeroPotential = 1.23 - fGibbsLinearization*(this.fTemperature - 298)+ this.oMT.Const.fUniversalGas * this.fTemperature /2/ this.oMT.Const.fFaraday *log(fPressure_H2*sqrt(fPressure_O2));
            
            % the euler equation
            if this.oPhase.fTimeStep < 1
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
            
            this.toStores.FuelCell.toPhases.CoolingSystem.oCapacity.toHeatSources.FuelCellHeatSource.setPower(fHeatFlow);
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
        end
    end
end