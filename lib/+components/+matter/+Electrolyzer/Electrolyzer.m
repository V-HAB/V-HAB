classdef Electrolyzer < vsys
    % model of a electrolyseur
    % calculates the required Voltage to cleave the water depending on
    % pressure and Temperatur
    properties
        fStackCurrent       = 0;    % current
        fCellVoltage        = 1.48; % cellvoltage
        fPower              = 0;    % power of the stack
        iCells              = 50;   % number of cells
        fStackVoltage;              % stack voltage
            
        % This property is used to store the current efficiency value of
        % the fuel cell. The efficiency is calculated dynamically within
        % the calculate_Voltage function
        rEfficiency = 1;
        
        % Area of the membrane for one cell
        fMembraneArea       = 0.01;	% m^2
             
        % Thickness of the membrane in one cell
        fMembraneThickness  = 2*10^-6;      % m
        
        % The maximum current that can can pass through the membrane
        fMaxCurrentDensity  = 20000;       % A/m^2
        
        % Charge transfer coefficient of anode and cathode. Base values are
        % from http://www.electrochemsci.org/papers/vol7/7054143.pdf table 2
        fChargeTransferAnode = 0.5;
        fChargeTransferCatode = 1;
    end
    
    methods
        function this = Electrolyzer(oParent, sName, fTimeStep, txInput)
            % txInput has the required field:
            % iCells:   The number of cells for the electrolyzer
            %
            % And the optional fields:
            % fMembraneArea:        The area of one cell membrane in m^2
            % fMembraneThickness:   the thickness of one cell membrane in m
            % fMaxCurrentDensity:   the maximum current density in A/m^2
            % fChargeTransferAnode: Charge transfer coefficient of anode and
            % fChargeTransferCatode: cathode. Base values are from
            %                        http://www.electrochemsci.org/papers/vol7/7054143.pdf table 2
            % fPower:               The electrical power of the
            %                       electrolyzer in W
            
            
            this@vsys(oParent, sName, fTimeStep);
            
            csFields = fieldnames(txInput);
            csValidFields = {'iCells',...
                             'fMembraneArea',...
                             'fMembraneThickness',...
                             'fMaxCurrentDensity',...
                             'fChargeTransferAnode',...
                             'fChargeTransferCatode',...
                             'fPower'};
            for iField = 1:length(csFields)
                if any(strcmp(csValidFields, csFields{iField}))
                    this.(csFields{iField}) = txInput.(csFields{iField});
                else
                    error(['Invalid input ', csFields{iField}, ' for the electrolyzer']);
                end
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
            
            oCooling    = this.toStores.Electrolyzer.createPhase(  'liquid',      'CoolingSystem',  0.1, struct('H2O', 1),  340, 1e5);
            
            % pipes
            components.matter.pipe(this, 'Pipe_H2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Water_In',       1.5, 0.003);
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
            fPressureH2 = this.toStores.Electrolyzer.toPhases.H2_Channel.fPressure;
            fPressureO2 = this.toStores.Electrolyzer.toPhases.O2_Channel.fPressure;
            fPressureH2O = this.toStores.Electrolyzer.toPhases.ProductWater.fPressure;
            
            % Calculated for one cell because the full current passes
            % through each cell
            fMaxCurrent = this.fMaxCurrentDensity * this.fMembraneArea;
            
            rError = 1;
            iIteration = 1;
            while rError > 1e-4 && iIteration < 500
                this.fStackCurrent = this.fPower / this.fStackVoltage;

                if this.fStackCurrent > fMaxCurrent
                    this.fStackCurrent = fMaxCurrent;
                end
                this.fPower = this.fStackCurrent * this.fStackVoltage;

                fCurrentDensity = this.fStackCurrent / this.fMembraneArea;

                % Nernst Equation e.g. from "Efficiency Calculationand
                % Configuration Design of a PEM Electrolyzer System for Hydrogen Production"
                % http://www.electrochemsci.org/papers/vol7/7054143.pdf (Eq. 5)
                % This is the "optimal" voltage where the electrolyzer would
                % operate at 100% efficiency
                fReversibleVoltage = 1.229 - 8.5*10^-4*(fTemperature-298) + 4.3085*10^-5 * fTemperature * log(fPressureH2 * sqrt(fPressureO2) / fPressureH2O);

                if this.fPower == 0
                    % If the power is 0, nothing is reacted and the cell
                    % voltage is the reversible voltage without losses
                    % (efficiency of 100%)
                    this.fCellVoltage = fReversibleVoltage;
                else
                    %% Calculation of losses
                    % activation losses (Eq 6) from the source above
                    fActivationLossVoltage = ((this.fChargeTransferAnode + this.fChargeTransferCatode)/(this.fChargeTransferAnode * this.fChargeTransferCatode)) * ...
                                            (this.oMT.Const.fUniversalGas * fTemperature / (2 * this.oMT.Const.fFaraday)) * ...
                                            log(fCurrentDensity / (1.08*10^-17 * exp(0.086 * fTemperature)));

                    % Ohmic Losses
                    % Equation 7 from the paper, conducivitiy and water content is 
                    % explained in the text below:
                    % a calculation for the membrane humidity could also be added,
                    % but the text states that PEM elys usually operate at this
                    % value. If the calculation for this is implemented, the model
                    % must also be improved to correctly model the water content of
                    % the membrane!
                    fWaterSaturationPressure = this.oMT.calculateVaporPressure(fTemperature, 'H2O');
                    fMembraneHumidity       = 14;
                    fMembraneConducivity    = (0.005139 * fMembraneHumidity + 0.00326) * exp(1267 * (1/303 - 1/fTemperature));
                    fOhmicLossVoltage       = fCurrentDensity * (this.fMembraneThickness/fMembraneConducivity);

                    % Concentration Losses (Eq. 8)
                    fPressureX = fPressureO2 / (0.1173 * 101325) + (fWaterSaturationPressure / 101325);
                    if fPressureX > 2
                        fBetaOne = (8.66*10^-5 * fTemperature - 0.068) * fPressureX - 1.6*10^-4 * fTemperature + 0.54;
                    else
                        fBetaOne = (7.16*10^-4 * fTemperature - 0.622) * fPressureX - 1.45*10^-3 * fTemperature + 1.68;
                    end
                    fConcentrationLossVoltage = fCurrentDensity * (fBetaOne * fCurrentDensity/this.fMaxCurrentDensity)^2;

                    this.fCellVoltage = (fReversibleVoltage + fActivationLossVoltage + fOhmicLossVoltage + fConcentrationLossVoltage);
                end
                this.rEfficiency = fReversibleVoltage / this.fCellVoltage;

                this.fStackVoltage = this.iCells * this.fCellVoltage;

                fCurrent = this.fPower / this.fStackVoltage;
                
                rError = abs(this.fStackCurrent - fCurrent);
                this.fStackCurrent = fCurrent;
                
                iIteration = iIteration + 1;
            end
            % Reset the power value because it might be lowered from the
            % set value because of limits in the electrolyzer
            this.fPower = this.fStackCurrent * this.fStackVoltage;
            
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