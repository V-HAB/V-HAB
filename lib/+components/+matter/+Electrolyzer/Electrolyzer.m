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
        fMembraneThickness  = 2.1e-4;      % m
        
        % The maximum current that can can pass through the membrane
        % See Fig. 5 from http://dx.doi.org/10.1016/j.electacta.2016.06.120
        fMaxCurrentDensity  = 40000;       % A/m^2
        
        % Charge transfer coefficient of anode and cathode. Base values are
        % from  http://www.electrochemsci.org/papers/vol7/7054143.pdf table 2
        % and match the kinetic losses shown in figure 6 from 
        % http://dx.doi.org/10.1016/j.electacta.2016.06.120
        fChargeTransferAnode = 1;
        fChargeTransferCatode = 0.5;
        
        % Properties of internal values of the Electrolyzer:
        fOhmicOverpotential         = 0; % V
        fKineticOverpotential       = 0; % V
        fConcentrationOverpotential = 0; % V
        fMassTransportOverpotential = 0; % V
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
            
            matter.store(this, 'Electrolyzer', 0.4 * this.iCells * this.fMembraneArea + 0.01334 * this.iCells * this.fMembraneArea + 0.1 + 0.0002);
            
            fInitialTemperature = 293;
            
            oMembrane   = this.toStores.Electrolyzer.createPhase(  'mixture',         	'Membrane', 'liquid', 0.4 * this.iCells * this.fMembraneArea, struct('H2O', 0.5, 'H2', 0.25, 'O2', 0.25),  fInitialTemperature, 1e5);
            
            
            oH2         = this.toStores.Electrolyzer.createPhase(  'gas',    'flow',    'H2_Channel',       0.05, struct('H2', 1e5),  fInitialTemperature, 0.8);
            oO2         = this.toStores.Electrolyzer.createPhase(  'gas',    'flow',    'O2_Channel',       0.05, struct('O2', 1e5),  fInitialTemperature, 0.8);
            
            oWater      = this.toStores.Electrolyzer.createPhase(  'liquid',            'ProductWater',     0.01334 * this.iCells * this.fMembraneArea, struct('H2O', 1),  fInitialTemperature, 1e5);
            
            oCooling    = this.toStores.Electrolyzer.createPhase(  'liquid', 'flow', 	'CoolingSystem',    0.0001, struct('H2O', 1),  340, 1e5);
            
            % pipes
            components.matter.pipe(this, 'Pipe_H2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_O2_Out',         1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Water_In',       1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_In',     1.5, 0.003);
            components.matter.pipe(this, 'Pipe_Cooling_Out',    1.5, 0.003);
            
            % valves
            components.matter.valve(this,'Valve_H2', true);
            components.matter.valve(this,'Valve_O2', true);
            
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
            tSolverProperties.bSolveOnlyFlowRates = true;
            
            aoMultiSolverBranches = [this.toBranches.H2_Outlet;...
                                     this.toBranches.O2_Outlet;];
            
            oSolver = solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            
            oWaterInlet = solver.matter.residual.branch(this.toBranches.Water_Inlet);
            
            solver.matter.manual.branch(this.toBranches.Cooling_Inlet);
            solver.matter.manual.branch(this.toBranches.Cooling_Outlet);
            
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
            % calculate the voltage of the electrolyseur
            
            fTemperature = this.toStores.Electrolyzer.toPhases.CoolingSystem.fTemperature;
            
            %Partialpressure of H2 and O2 in the output phase
            fPressureH2 = this.toStores.Electrolyzer.toPhases.H2_Channel.fPressure;
            fPressureO2 = this.toStores.Electrolyzer.toPhases.O2_Channel.fPressure;
            fPressureH2O = this.toStores.Electrolyzer.toPhases.ProductWater.fPressure;
            
            % Calculated for one cell because the full current passes
            % through each cell
            fMaxCurrent = this.fMaxCurrentDensity * this.fMembraneArea;
            
            fReversibleVoltage = this.calculateReversibleCellVoltage(fTemperature, fPressureH2, fPressureO2, fPressureH2O);
            
            if this.fPower == 0
                % If the power is 0, nothing is reacted and the cell
                % voltage is the reversible voltage without losses
                % (efficiency of 100%)
                this.fCellVoltage = fReversibleVoltage;

            else
                % Since the original iterative approach did not work for all
                % configurations of ELYs a nested intervall approach is used
                % instead. The current of the electrolyzer must be between 0
                % and the maximum current, therefore these values are used as
                % initial intervall
                mfCurrent = [1e-8, fMaxCurrent];
                
                mfError         = zeros(2,1);
                mfVoltage       = zeros(2,1);
                mfVoltage(1)    = this.calculateStackValues(mfCurrent(1), fTemperature, fPressureO2, fReversibleVoltage);
                mfError(1)      = mfCurrent(1) - (this.fPower / (this.iCells * mfVoltage(1)));
                
                mfVoltage(2)    = this.calculateStackValues(mfCurrent(2), fTemperature, fPressureO2, fReversibleVoltage);
                mfError(2)      = mfCurrent(2) - (this.fPower / (this.iCells * mfVoltage(2)));
                
                fError = inf;
                iCounter = 0;
                fIntervallSize = abs(mfCurrent(2) - mfCurrent(1));
                
                while abs(fError) > 1e-4 && fIntervallSize > 1e-18 && iCounter < 500
            
                    fCurrent = (mfCurrent(2) + mfCurrent(1)) / 2;
                    fNewCellVoltage = this.calculateStackValues(fCurrent, fTemperature, fPressureO2, fReversibleVoltage);
                
                    fNewCurrent = this.fPower / (this.iCells * fNewCellVoltage);
                    
                    fError = fCurrent - fNewCurrent;
                    
                    if sign(fError) == sign(mfError(1))
                        iReplace = 1;
                    else
                        iReplace = 2;
                    end
                    mfCurrent(iReplace) = fCurrent;
                    mfError(iReplace)   = fError;
                
                    fIntervallSize = abs(mfCurrent(2) - mfCurrent(1));
                    
                    iCounter = iCounter + 1;
                end
                
                this.fCellVoltage = fNewCellVoltage;
            end
            
            this.rEfficiency = fReversibleVoltage / this.fCellVoltage;

            this.fStackVoltage = this.iCells * this.fCellVoltage;
            
            this.fStackCurrent = this.fPower / this.fStackVoltage;

            if this.fStackCurrent > fMaxCurrent
                this.fStackCurrent = fMaxCurrent;
            end
            this.fPower = this.fStackCurrent * this.fStackVoltage;
                
            % Reset the power value because it might be lowered from the
            % set value because of limits in the electrolyzer
            this.fPower = this.fStackCurrent * this.fStackVoltage;
            
            fHeatFlow = this.fStackCurrent * this.fStackVoltage * (1 - this.rEfficiency);
            
            this.toStores.Electrolyzer.toPhases.CoolingSystem.oCapacity.toHeatSources.Electrolyzer_HeatSource.setHeatFlow(fHeatFlow);
            
            % We limit the temperature difference over the Electrolyzer to
            % ~10 K by setting the coolant flow accordingly:
            fCoolantFlow = fHeatFlow / (this.toBranches.Cooling_Inlet.coExmes{2}.oPhase.oCapacity.fSpecificHeatCapacity * 5);
            
            this.toBranches.Cooling_Inlet.oHandler.setFlowRate(-fCoolantFlow);
            this.toBranches.Cooling_Outlet.oHandler.setFlowRate(fCoolantFlow);
                
        end
        
        function fReversibleVoltage = calculateReversibleCellVoltage(~, fTemperature, fPressureH2, fPressureO2, fPressureH2O)
            % Nernst Equation e.g. from "Efficiency Calculationand
            % Configuration Design of a PEM Electrolyzer System for Hydrogen Production"
            % http://www.electrochemsci.org/papers/vol7/7054143.pdf (Eq. 5)
            % This is the "optimal" voltage where the electrolyzer would
            % operate at 100% efficiency
            fReversibleVoltage = 1.229 - 8.5*10^-4*(fTemperature-298) + 4.3085*10^-5 * fTemperature * log(fPressureH2 * sqrt(fPressureO2) / fPressureH2O);
        end
        
        
        function setPower(this, fPower)
            this.fPower = fPower;
            
            if this.fPower > 0
                if ~this.toProcsF2F.Valve_H2.bOpen
                    this.toProcsF2F.Valve_H2.setOpen(true);
                end
                if ~this.toProcsF2F.Valve_O2.bOpen
                    this.toProcsF2F.Valve_O2.setOpen(true);
                end
            elseif this.fPower == 0
                if this.toProcsF2F.Valve_H2.bOpen
                    this.toProcsF2F.Valve_H2.setOpen(false);
                end
                if this.toProcsF2F.Valve_O2.bOpen
                    this.toProcsF2F.Valve_O2.setOpen(false);
                end
            end
            
            this.calculate_voltage();
        end
    end
    
    methods (Access = protected)
        
        function fNewCellVoltage = calculateStackValues(this, fCurrent, fTemperature, fPressureO2, fReversibleVoltage)
            % This function can be used to calculate the cell voltage of
            % the electrolyzer for a specific desired current

            fCurrentDensity = fCurrent / this.fMembraneArea;

            %% Calculation of losses
            % Activiation losses/kinetic losses according to 
            % http://www.electrochemsci.org/papers/vol7/7054143.pdf
            % The losses also match the curve for kinetic losses from
            % http://dx.doi.org/10.1016/j.electacta.2016.06.120
            %
            % pressure factor is introduced and adjusted to match the
            % behavior from
            % http://dx.doi.org/10.1016/j.electacta.2016.06.120 
            % figure 6
            fPressureFactor = 1 / ((fPressureO2/1e5)^0.025);
            fActivationLossVoltage = fPressureFactor * ((this.fChargeTransferAnode + this.fChargeTransferCatode)/(this.fChargeTransferAnode * this.fChargeTransferCatode)) * ...
                                    (this.oMT.Const.fUniversalGas * fTemperature / (2 * this.oMT.Const.fFaraday)) * ...
                                    log((fCurrentDensity / 10000) / (1.08*10^-17 * exp(0.086 * fTemperature)));

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
            % Note that this equation is from
            % https://doi.org/10.1149/1.2085971 and is provided in cm!
            % Therefore the membrane thickness must be provided in cm and
            % the current density in A/cm^2
            fMembraneConducivity    = (0.005139 * fMembraneHumidity + 0.00326) * exp(1267 * (1/303 - 1/fTemperature));
            fOhmicLossVoltage       = (fCurrentDensity / 10000) * ((this.fMembraneThickness * 100) /fMembraneConducivity);

            % Concentration Losses (Eq. 8)
            fPressureX = fPressureO2 / (0.1173 * 101325) + (fWaterSaturationPressure / 101325);
            % However this equation is not well suited to high pressures,
            % therefore the pressure X is limited to 3. See also 
            % http://dx.doi.org/10.1016/j.electacta.2016.06.120
            % which states that "In the commonly used operating range
            % between 1 and 3 A/cm2 no cell voltage increase is observed,
            % the thermodynamic increase is completely compensated by
            % beneficial effects." for high pressure electrolysis of up to
            % 100 bar. The small increases a low current densities shown in
            % Table 2 of the source are mostly attributed to the delta
            % E_cell which is a result of the Nernst equation, which is
            % included in the calculation of the reversible cell voltage!
            if fPressureX > 10
                fPressureX = 10;
            end
            if fPressureX > 2
                fBetaOne = (8.66*10^-5 * fTemperature - 0.068) * fPressureX - 1.6*10^-4 * fTemperature + 0.54;
            else
                fBetaOne = (7.16*10^-4 * fTemperature - 0.622) * fPressureX - 1.45*10^-3 * fTemperature + 1.68;
            end
            % Note this equation is also only valid with current densitied
            % in A/cm^2. The value where the current density is divided
            % with the maximum current density can remain as is, as the
            % units cancle out.
            fConcentrationLossVoltage = (fCurrentDensity / 10000) * (fBetaOne * fCurrentDensity/this.fMaxCurrentDensity)^2;

            
            % Mass transport overpotential according to 
            % https://doi.org/10.1016/j.jclepro.2020.121184
            % equation 21, but using the transfer coefficient adjustment
            % from https://doi.org/10.1016/j.est.2016.06.006 to match the
            % results of http://dx.doi.org/10.1016/j.electacta.2016.06.120
            fTransferCoefficient = 0.075;
            % Therefore a sigmoid function is used to better approximate
            % the behavior. The sigmoid function goes from 0 to 1 between
            % -6 and 6 in a s-shaped curve, we want the behavior from 0 to
            % 6 for the later area, but before that the behavior is better
            % approximated by a linear curve. Therefore we set a linear
            % approximation for low current densities (up to basically a
            % sigmoidX value of 0.5) and then use the sigmoid function.
            fInflectionCurrentDensity = 15000;
            if fCurrentDensity < fInflectionCurrentDensity
                %fSigmoidX = ((fCurrentDensity ./ (2 * fPlateuCurrentDensity)) .* 12) - 6; 
                % For values below
                fMassTransportVoltage = (this.oMT.Const.fUniversalGas * fTemperature / (fTransferCoefficient * 2 * this.oMT.Const.fFaraday)) .* (fCurrentDensity ./ fInflectionCurrentDensity) .* 0.5;
            else
            	fSigmoidX = (((fCurrentDensity - (fInflectionCurrentDensity)) ./ (2 * (this.fMaxCurrentDensity - (fInflectionCurrentDensity)))) .* 12); 
            
                fMassTransportVoltage = (this.oMT.Const.fUniversalGas * fTemperature / (fTransferCoefficient * 2 * this.oMT.Const.fFaraday)) .* exp(fSigmoidX) ./ (exp(fSigmoidX) +1);
            end
            % Now we again adjust the value using a pressure factor to
            % match behavior from figure 6 of 
            % http://dx.doi.org/10.1016/j.electacta.2016.06.120
            % Since no data above 100 bar is available, no further
            % beneficial effects past that value are assumed
            fPressureFactor = 1 - ((fPressureO2) ./ (100e5) / 3.84);
            % The mass transport overpotential temperature behavior is
            % reflected by the following adjustments
            fTemperatureFactor = 0.65 + 0.6 * ((343.1500 - fTemperature) / 40);
            if fTemperatureFactor < 0.55
                fTemperatureFactor = 0.55;
            end
            fAdjustmentCurrentDensities = 25000;
            if fCurrentDensity < fAdjustmentCurrentDensities
                fTemperatureAdjustment = -(1/20) * (fTemperature - 323.15);
                if fTemperatureAdjustment > 1
                    fTemperatureAdjustment = 1;
                elseif fTemperatureAdjustment < 0
                    fTemperatureAdjustment = 0;
                end
                fAdjustmentFactor = (abs((abs(fCurrentDensity - (fAdjustmentCurrentDensities/2)) ./ (fAdjustmentCurrentDensities/2)) - 1)  .* 0.44 + 1)^fTemperatureAdjustment;
                fTemperatureFactor = fAdjustmentFactor * fTemperatureFactor;
            end
            
            fMassTransportVoltage = fPressureFactor * fTemperatureFactor * fMassTransportVoltage;
            
            fNewCellVoltage = (fReversibleVoltage + fActivationLossVoltage + fOhmicLossVoltage + fConcentrationLossVoltage + fMassTransportVoltage);
            
            % Store properties:
            this.fOhmicOverpotential            = fOhmicLossVoltage;
            this.fKineticOverpotential          = fActivationLossVoltage;
            this.fConcentrationOverpotential    = fConcentrationLossVoltage;
            this.fMassTransportOverpotential    = fMassTransportVoltage;
        end
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            this.calculate_voltage();
        end
    end
end