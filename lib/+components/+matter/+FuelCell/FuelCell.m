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
        
        fInitialH2;
        fInitialO2;
    end
    
    
    methods
        function this = FuelCell(oParent, sName, fTimeStep, txInput)
            % txInput has the required field:
            % iCells:   The number of cells for the fuel cell
            %
            % And the optional fields:
            % fMembraneArea:        The area of one cell membrane in m^2
            % fMembraneThickness:   the thickness of one cell membrane in m
            % fMaxCurrentDensity:   the maximum current density in A/m^2
            % rMaxReactingH2:       Maximum ratio of H2/O2 that passes 
            % rMaxReactingO2:       through the fuel cell that can be
            %                       reacted.
            % fPower:               The electrical power of the fuel cell
            %                       in W
            this@vsys(oParent, sName, fTimeStep);
            
            csFields = fieldnames(txInput);
            csValidFields = {'iCells',...
                             'fMembraneArea',...
                             'fMembraneThickness',...
                             'fMaxCurrentDensity',...
                             'rMaxReactingH2',...
                             'rMaxReactingO2',...
                             'fPower'};
            for iField = 1:length(csFields)
                if any(strcmp(csValidFields, csFields{iField}))
                    this.(csFields{iField}) = txInput.(csFields{iField});
                else
                    error(['Invalid input ', csFields{iField}, ' for the Fuel Cell']);
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
            fLoopVolume = 0.00025 * this.iCells * this.fMembraneArea / 0.025;
            
            matter.store(this, 'FuelCell', 0.4 * this.iCells * this.fMembraneArea + 0.1 + 2 * fLoopVolume + 4e-6);
            
            oH2      = 	this.toStores.FuelCell.createPhase(  'gas',     'flow', 'H2_Channel',   1e-6,   struct('H2', 3e5),	fInitialTemperature, 0.8);
            oH2_Out  =  this.toStores.FuelCell.createPhase(  'gas',     'flow', 'H2_Outlet',    1e-6,   struct('H2', 3e5),	fInitialTemperature, 0.8);
            oH2_Loop =  this.toStores.FuelCell.createPhase(  'gas'            , 'H2_Loop',      fLoopVolume,  struct('H2', 3e5),	fInitialTemperature, 0.8);
            oO2      = 	this.toStores.FuelCell.createPhase(  'gas',     'flow', 'O2_Channel',   1e-6,   struct('O2', 3e5),	fInitialTemperature, 0.8);
            oO2_Loop = 	this.toStores.FuelCell.createPhase(  'gas'            , 'O2_Loop',      fLoopVolume,  struct('O2', 3e5),	fInitialTemperature, 0.8);
            
            oMembrane = this.toStores.FuelCell.createPhase(  'gas',             'Membrane',     0.4 * this.iCells * this.fMembraneArea, struct('O2', 0.5e5, 'H2', 0.5e5),  fInitialTemperature, 0.8);
            
            oCooling =  this.toStores.FuelCell.createPhase(  'liquid',  'flow',	'CoolingSystem',0.1, struct('H2O', 1),  340, 1e5);
            
            this.fInitialH2 = oH2_Loop.afMass(this.oMT.tiN2I.H2);
            this.fInitialO2 = oO2_Loop.afMass(this.oMT.tiN2I.O2);
            
            % H2 water is seperated from inlet in case inflow hydrogen has
            % some amount of water
            matter.store(this, 'H2_WaterSeperation', 0.01334 * this.iCells * this.fMembraneArea + 1e-6);
            oH2_Dryer       = this.toStores.H2_WaterSeperation.createPhase(  'gas', 'flow', 'H2_Dry',   1e-6, struct('O2', 1e5),  fInitialTemperature, 0.8);
            oH2_RecoveredWater = this.toStores.H2_WaterSeperation.createPhase(  'liquid',      'Water',   0.01334 * this.iCells * this.fMembraneArea, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            matter.store(this, 'O2_WaterSeperation', 0.01334 * this.iCells * this.fMembraneArea + 1e-6);
            oO2_Dryer       = this.toStores.O2_WaterSeperation.createPhase(  'gas', 'flow', 'O2_Dry',   1e-6, struct('O2', 1e5),  fInitialTemperature, 0.8);
            oRecoveredWater = this.toStores.O2_WaterSeperation.createPhase(  'liquid',      'Water',   0.01334 * this.iCells * this.fMembraneArea, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            % pipes
            components.matter.pipe(this, 'Pipe_H2_Loop',        1.5, 0.0003 * this.iCells * this.fMembraneArea / 0.025);
            components.matter.pipe(this, 'Pipe_O2_Loop',        1.5, 0.0003 * this.iCells * this.fMembraneArea / 0.025);
            % fans
            components.matter.fan_simple(this, 'H2_Compressor', 0.5e5, false);
            components.matter.fan_simple(this, 'O2_Compressor', 0.5e5, false);
            
            matter.branch(this, oH2_Dryer,   	{},              	'H2_Inlet',         'H2_Inlet');
            matter.branch(this, oH2_Dryer,        	{},              	oH2_Loop,           'H2_from_Dryer');
            matter.branch(this, oH2_Out,          	{'Pipe_H2_Loop'},	oH2_Loop,         	'H2_Outlet');
            matter.branch(this, oH2_Loop,         	{},             	oH2,                'H2_Loop');
            matter.branch(this, oH2,                {'H2_Compressor'},	oH2_Out,            'H2_to_Outlet');
            
            matter.branch(this, oO2_Loop,        	{},              	'O2_Inlet',         'O2_Inlet');
            matter.branch(this, oO2_Dryer,          {'Pipe_O2_Loop'},	oO2_Loop,           'O2_Outlet');
            matter.branch(this, oO2_Loop,           {},             	oO2,                'O2_Loop');
            matter.branch(this, oO2,                {'O2_Compressor'},	oO2_Dryer,          'O2_to_Dryer');
           
            matter.branch(this, oCooling,           {},                 'Cooling_Inlet',  	'Cooling_Inlet');
            matter.branch(this, oCooling,           {},                 'Cooling_Outlet',	'Cooling_Outlet');
            
            matter.branch(this, oH2_RecoveredWater,	{},                 oRecoveredWater,    'H2_Water_to_Outlet');
            matter.branch(this, oRecoveredWater,  	{},                 'Water_Outlet',     'Water_Outlet');
            
            % adding the fuel cell reaction manip
            components.matter.FuelCell.components.FuelCellReaction('FuelCellReaction', oMembrane);
            
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'H2_to_Membrane',  oH2,        oMembrane);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'O2_to_Membrane',  oO2,        oMembrane);
            components.matter.P2Ps.ManualP2P(this.toStores.FuelCell, 'Membrane_to_O2',  oMembrane,  oO2);
            components.matter.FuelCell.components.Dryer(this.toStores.O2_WaterSeperation, 'O2_Dryer',   	oO2_Dryer,  oRecoveredWater,    0.8);
            components.matter.FuelCell.components.Dryer(this.toStores.H2_WaterSeperation, 'H2_Dryer',   	oH2_Dryer,  oH2_RecoveredWater, 0.8);
        end
        
        function setIfFlows(this, H2_Inlet, O2_Inlet, Cooling_Inlet, Cooling_Outlet, Water_Outlet)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('H2_Inlet',          H2_Inlet);
            this.connectIF('O2_Inlet',          O2_Inlet);
            this.connectIF('Cooling_Inlet',     Cooling_Inlet);
            this.connectIF('Cooling_Outlet',    Cooling_Outlet);
            this.connectIF('Water_Outlet',      Water_Outlet);
        end
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oFuelCellHeatSource = thermal.heatsource('FuelCell_HeatSource', 0);
            this.toStores.FuelCell.toPhases.CoolingSystem.oCapacity.addHeatSource(oFuelCellHeatSource);

            oCTHeatSource = components.thermal.heatsources.ConstantTemperature('H2_HeatSource');
            this.toStores.FuelCell.toPhases.H2_Loop.oCapacity.addHeatSource(oCTHeatSource);
            
            oCTHeatSource = components.thermal.heatsources.ConstantTemperature('O2_HeatSource');
            this.toStores.FuelCell.toPhases.O2_Loop.oCapacity.addHeatSource(oCTHeatSource);
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            tSolverProperties.fMaxError = 1e-6;
            tSolverProperties.iMaxIterations = 1000;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;
            
            aoMultiSolverBranches = [this.toBranches.H2_from_Dryer;...
                                     this.toBranches.H2_Outlet;...
                                     this.toBranches.H2_to_Outlet;...
                                     this.toBranches.O2_to_Dryer;...
                                     this.toBranches.O2_Outlet];
        
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            solver.matter.manual.branch(this.toBranches.H2_Loop);
            solver.matter.manual.branch(this.toBranches.O2_Loop);
            this.toBranches.H2_Loop.oHandler.setFlowRate(0.0001 * this.iCells * this.fMembraneArea / 0.025);
            this.toBranches.O2_Loop.oHandler.setFlowRate(0.0001 * this.iCells * this.fMembraneArea / 0.025);
            solver.matter.manual.branch(this.toBranches.H2_Inlet);
            solver.matter.manual.branch(this.toBranches.O2_Inlet);
            
            solver.matter.manual.branch(this.toBranches.Cooling_Inlet);
            solver.matter.manual.branch(this.toBranches.Cooling_Outlet);
            
            solver.matter.residual.branch(this.toBranches.H2_Water_to_Outlet);
            solver.matter.residual.branch(this.toBranches.Water_Outlet);
            
            csStores = fieldnames(this.toStores);
            % sets numerical properties for the phases of CDRA
            for iS = 1:length(csStores)
                for iP = 1:length(this.toStores.(csStores{iS}).aoPhases)
                    oPhase = this.toStores.(csStores{iS}).aoPhases(iP);
                    
                    tTimeStepProperties.rMaxChange = 0.1;
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;

                    oPhase.setTimeStepProperties(tTimeStepProperties);

                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
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
            
            fPressure_H2 = this.toStores.FuelCell.toPhases.H2_Channel.afPP(this.oMT.tiN2I.H2);
            fPressure_O2 = this.toStores.FuelCell.toPhases.O2_Channel.afPP(this.oMT.tiN2I.O2);
            
            %calculate the static stack voltage
            if this.oTimer.iTick > 5
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
            else
                fNewVoltage = this.fStackVoltage;
            end
            
            %zero potential of the cell
            this.fStackZeroPotential = 1.23 - fGibbsLinearization*(fTemperature - 298)+ this.oMT.Const.fUniversalGas * fTemperature /2/ this.oMT.Const.fFaraday *log(fPressure_H2*sqrt(fPressure_O2));
            
            % the euler equation
            % Currently the dynamic of this is neglected, as we use to
            % large time steps for this anyway, we just use a step change
            %timeconstant of the output capacity
%             fTau = 2;
%             fTimeStep =  2 / abs(fNewVoltage - this.fStackVoltage);
%             if fTimeStep > 300 || abs(fNewVoltage - this.fStackVoltage) < 2
%             	fTimeStep = 300;
%             elseif fTimeStep < 1e-3
%             	fTimeStep = 1e-3;
%             end
%             this.setTimeStep(fTimeStep);
%             if abs(fNewVoltage - this.fStackVoltage) > 2
%                 this.fStackVoltage = this.fStackVoltage + this.fTimeStep * (fNewVoltage - this.fStackVoltage) * fTau;
%             end
            
            this.fStackVoltage = fNewVoltage;
            
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
            
            % We limit the temperature difference over the Electrolyzer to
            % ~5 K by setting the coolant flow accordingly:
            fCoolantFlow = fHeatFlow / (4000 * 5); % this.toBranches.Cooling_Inlet.coExmes{2}.oPhase.oCapacity.fSpecificHeatCapacity
            
            this.toBranches.Cooling_Inlet.oHandler.setFlowRate(-fCoolantFlow);
            this.toBranches.Cooling_Outlet.oHandler.setFlowRate(fCoolantFlow);
            
            fMolarFlowH2 = this.iCells * ((this.fPower / this.fStackVoltage) / (2 * this.oMT.Const.fFaraday));
            fMolarFlowO2 = 0.5 * fMolarFlowH2;
            
            fH2InletFlow = fMolarFlowH2 * this.oMT.afMolarMass(this.oMT.tiN2I.H2);
            fO2InletFlow = fMolarFlowO2 * this.oMT.afMolarMass(this.oMT.tiN2I.O2);
            
            fReplacementH2 = (this.fInitialH2 - this.toStores.FuelCell.toPhases.H2_Loop.afMass(this.oMT.tiN2I.H2)) / 900;
            fReplacementO2 = (this.fInitialO2 - this.toStores.FuelCell.toPhases.O2_Loop.afMass(this.oMT.tiN2I.O2)) / 900;
            
            this.toBranches.H2_Inlet.oHandler.setFlowRate( - (fH2InletFlow + fReplacementH2));
            this.toBranches.O2_Inlet.oHandler.setFlowRate( - (fO2InletFlow + fReplacementO2));
            
        end
        
        function setPower(this, fPower)
            this.fPower = fPower;
            
            if this.fPower == 0
                if this.toProcsF2F.H2_Compressor.bTurnedOn
                    this.toProcsF2F.H2_Compressor.switchOff();
                end
                if this.toProcsF2F.O2_Compressor.bTurnedOn
                    this.toProcsF2F.O2_Compressor.switchOff();
                end
            elseif this.fPower > 0
                if ~this.toProcsF2F.H2_Compressor.bTurnedOn
                    this.toProcsF2F.H2_Compressor.switchOn();
                end
                if ~this.toProcsF2F.O2_Compressor.bTurnedOn
                    this.toProcsF2F.O2_Compressor.switchOn();
                end
            end
            
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