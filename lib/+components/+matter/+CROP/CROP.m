classdef CROP < vsys
    %The system file for the C.R.O.P. system. 
    %   As is described in chapter 4 in the thesis, the CROP system
    %   contains 2 stores "Tank" and "BioFilter". The store "Tank" is
    %   implemented in this file including the phase "TankSolution" and two
    %   Exmes on it ("Tank.In" and "Tank.Out"). The modular "BioFilter" is
    %   implemented in the folder "+components". Two branches
    %   "Tank_to_BioFilter" and "BioFilter_to_Tank" are also implemented in
    %   this file to realize the wastewater circulation between "Tank" and
    %   "BioFilter".
    
    properties (SetAccess = protected, GetAccess = public)
        fCapacity = 30; % kg
        
        afInitialMasses;
        
        bManualUrineSupply = false;
        
        % Only power consumer is the pump circulation water which is e.g.
        % an EHEIM compactON 300 which consumes 7 W
        fCurrentPowerConsumption = 7;
        
        fInitialMassParentUrineSupply = 0;
        
        bResetInitialMass = false;
    end
    
    methods
        function this = CROP(oParent, sName, fTimeStep)
            if nargin < 3
                fTimeStep = 300;
            end
            this@vsys(oParent, sName, fTimeStep);
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % The volume of the store "Tank" is 0.03 m^3
            fVolume_Tank = 0.03;
            
            % The store "Tank" in the CROP model which can hold 0.03 m^3 water
            matter.store(this, 'CROP_Tank', fVolume_Tank + 0.005);
            
            % The phase "TankSolution" in the store "Tank" which contains
            % the initial masses of main reactants (CH4N2O, NH3, NH4OH, HNO2, HNO3)
            oTankSolution  =  matter.phases.mixture(this.toStores.CROP_Tank,'TankSolution','liquid',...
                struct('H2O', 1e-4),...
                293.15, 1e5);
            oFlow   = this.toStores.CROP_Tank.createPhase(    'mixture', 'flow',    'Aeration',     'liquid',        1e-6,       struct('H2O', 1),       293, 1e5);
            
            this.afInitialMasses = oTankSolution.afMass;
            
            % Two Exme processors on the phase "TankSolution"
            matter.procs.exmes.mixture(oTankSolution, 'Tank_Out');
            matter.procs.exmes.mixture(oTankSolution, 'Tank_In');
            matter.procs.exmes.mixture(oTankSolution, 'Urine_In');
            matter.procs.exmes.mixture(oTankSolution, 'Solution_Out');
            
%             components.matter.pH_Module.stationaryManip('CROP_pHManip', oTankSolution, this.fTimeStep);
            components.matter.pH_Module.flowManip('CROP_pHManip', oFlow);
            
            %% Calcite acidic dissolution 
            % A manipulator that calculates calcite dissolution in the
            % TankSolution phase depending on the pH value
            % Since only one manip can be present in the phase and we do
            % not want to remove calcite from CROP when exchanging the
            % solution, we create a seperate calcite solution phase.
            % Initial mass of calcite is 500g:
            oCalcite  =  matter.phases.mixture(this.toStores.CROP_Tank,'Calcite','liquid',...
                struct('H2O', 0.5, 'CaCO3', 0.5),...
                293.15, 1e5);
            components.matter.CROP.tools.AcidOnCalcite('Acid Reaction on Calcite', oCalcite); 
            
            % The phase "TankAir" in the store "CROP_Tank" which 
            % represents the air in the tank. It was decided to use a flow
            % phase, which will result in more outgassing than in realitiy,
            % but the other option would slow down the simulation
            oTankAir = this.toStores.CROP_Tank.createPhase( 'gas', 'flow', 'TankAir', 0.001, struct('N2', 0.9*8e4, 'O2', 0.9*2e4, 'CO2', 0.9*500, 'NH3', 0), 293, 0.5);
            
            % ExMes for NH3 outgassing
            matter.procs.exmes.mixture(oTankSolution,   'NH3TankSolutionOutgassing');
            matter.procs.exmes.gas(oTankAir,            'NH3OutgassingFromTankSolution');
            
            % ExMes for CO2 outgassing
            matter.procs.exmes.mixture(oTankSolution,   'CO2TankSolutionOutgassing');
            matter.procs.exmes.gas(oTankAir,            'CO2OutgassingFromTankSolution');

            % Outgassing P2Ps
            % Two P2P objects to realize the NH3 and CO2 outgassing from the 
            % phase "TankSolution" to the phase "TankAir" in the
            % Tank store
            components.matter.CROP.tools.P2P_Outgassing(this.toStores.CROP_Tank, 'NH3_Outgassing_Tank', 'TankSolution.NH3TankSolutionOutgassing', 'TankAir.NH3OutgassingFromTankSolution', 'NH3');
            components.matter.CROP.tools.P2P_Outgassing(this.toStores.CROP_Tank, 'CO2_Outgassing_Tank', 'TankSolution.CO2TankSolutionOutgassing', 'TankAir.CO2OutgassingFromTankSolution', 'CO2');    
            
            this.toStores.CROP_Tank.addStandardVolumeManipulators();
            
            % The modular store "BioFilter" in the CROP model which is
            % implemented in the folder "+components"
            components.matter.CROP.components.BioFilter(this,'CROP_BioFilter');
            
            components.matter.P2Ps.ManualP2P(this.toStores.CROP_Tank, 'O2_to_TankSolution',  oTankAir , oFlow);
            
            components.matter.P2Ps.ManualP2P(this.toStores.CROP_Tank, 'Calcite_to_TankSolution',  oCalcite , oTankSolution);
            
            components.matter.Manips.ManualManipulator(this.toStores.CROP_Tank, 'UrineConversion', oTankSolution);
            
            % Two branches to realize the wastewater circulation between
            % the two stores
            matter.branch(this, 'CROP_Tank.Tank_Out',       { }, oFlow,                     'Tank_to_BioFilter');
            matter.branch(this, oFlow,                      { }, 'CROP_BioFilter.In',       'Aeration_to_BioFilter');
            matter.branch(this, 'CROP_BioFilter.Out',       { }, 'CROP_Tank.Tank_In',       'BioFilter_to_Tank');
            
            matter.branch(this, 'CROP_Tank.Urine_In',       { }, 'CROP_Urine_Inlet',        'CROP_Urine_Inlet');
            matter.branch(this, 'CROP_Tank.Solution_Out',   { }, 'CROP_Solution_Outlet',    'CROP_Solution_Outlet');
            
            matter.branch(this, oTankAir,                   { }, 'CROP_Air_Inlet',          'CROP_Air_Inlet');
            matter.branch(this, oTankAir,                   { }, 'CROP_Air_Outlet',         'CROP_Air_Outlet');
            
            matter.branch(this, oCalcite,                   { }, 'CROP_Calcite_Inlet',    	'CROP_Calcite_Inlet');
        end
        
        function setUrineSupplyToManual(this, bManualUrineSupply)
            this.bManualUrineSupply = bManualUrineSupply;
        end
        
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
            oHeatSource = thermal.heatsource('Heater', 0);
            this.toStores.CROP_Tank.toPhases.TankSolution.oCapacity.addHeatSource(oHeatSource);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Use the "manual" solver to solve the two branches
            solver.matter.manual.branch(this.toBranches.Tank_to_BioFilter);
            solver.matter.manual.branch(this.toBranches.CROP_Air_Inlet);
            
            solver.matter.manual.branch(this.toBranches.CROP_Calcite_Inlet);
            
            this.toBranches.CROP_Air_Inlet.oHandler.setVolumetricFlowRate(-0.1);
            
            aoMultiSolverBranches = [this.toBranches.Aeration_to_BioFilter, this.toBranches.BioFilter_to_Tank, this.toBranches.CROP_Air_Outlet];
            solver.matter_multibranch.iterative.branch(aoMultiSolverBranches, 'complex');
            
            % The interface branches are also set to manual branches.
            % However, the system itself does not tell these what to do,
            % this must be done by the parent system!
            solver.matter.manual.branch(this.toBranches.CROP_Urine_Inlet);
            solver.matter.manual.branch(this.toBranches.CROP_Solution_Outlet);
            
            % Set the flow rate of the wastewater circulation to 1000L/h
            % with the equation Eq.(4-4) in the thesis from Yilun Sun.
            % Increased here to prevent trouble with the conversion
            this.toBranches.Tank_to_BioFilter.oHandler.setVolumetricFlowRate(1 / 3600);
            
            
            csStoreNames = fieldnames(this.toStores);
            for iStore = 1:length(csStoreNames)
                for iPhase = 1:length(this.toStores.(csStoreNames{iStore}).aoPhases)
                    oPhase = this.toStores.(csStoreNames{iStore}).aoPhases(iPhase);
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;

                    oPhase.setTimeStepProperties(tTimeStepProperties);

                    tTimeStepProperties = struct();
                    tTimeStepProperties.fMaxStep = this.fTimeStep * 5;
                    oPhase.oCapacity.setTimeStepProperties(tTimeStepProperties);
                end
            end
            
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = 0.01;
            this.toStores.CROP_Tank.toPhases.TankAir.setTimeStepProperties(tTimeStepProperties);
            
            tTimeStepProperties = struct();
            tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.CH4N2O)  = 0.1;
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.NH3)     = 0.1;
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.NH4)     = 0.1;
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.NO2)     = 0.1;
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.NO3)     = 0.1;
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.C6H5O7)  = 0.1;
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.CO3)     = 0.1;
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.CO2)     = 0.1;
            tTimeStepProperties.arMaxChange(this.oMT.tiN2I.Ca2plus) = 0.1;
            this.toStores.CROP_Tank.toPhases.TankSolution.setTimeStepProperties(tTimeStepProperties);
            
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = 0.1;
            this.toStores.CROP_Tank.toPhases.Calcite.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
        function setIfFlows(this, sUrineInlet, sSolutionOutlet, sAirInlet, sAirOutlet, sCalciteInlet)
            this.connectIF('CROP_Urine_Inlet' ,     sUrineInlet);
            this.connectIF('CROP_Solution_Outlet' , sSolutionOutlet);
            this.connectIF('CROP_Air_Inlet' ,       sAirInlet);
            this.connectIF('CROP_Air_Outlet' ,      sAirOutlet);
            this.connectIF('CROP_Calcite_Inlet' ,	sCalciteInlet);
            
            this.fInitialMassParentUrineSupply = this.toBranches.CROP_Urine_Inlet.coExmes{2}.oPhase.fMass;
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            exec@vsys(this);
            
            % Check if urine must be converted
            if  this.toStores.CROP_Tank.toPhases.TankSolution.afMass(this.oMT.tiN2I.Urine) > 0 && ~this.toBranches.CROP_Urine_Inlet.oHandler.bMassTransferActive && ~this.toStores.CROP_Tank.toPhases.TankSolution.toManips.substance.bMassTransferActive
                afUrineMass = zeros(1, this.oMT.iSubstances);
                if this.toStores.CROP_Tank.toPhases.TankSolution.afMass(this.oMT.tiN2I.Urine) > 1e-2
                    afUrineMass(this.oMT.tiN2I.Urine) = this.toStores.CROP_Tank.toPhases.TankSolution.afMass(this.oMT.tiN2I.Urine) - 1e-2;
                elseif this.toStores.CROP_Tank.toPhases.TankSolution.afMass(this.oMT.tiN2I.Urine) < 1e-8
                    afUrineMass(this.oMT.tiN2I.Urine) = this.toStores.CROP_Tank.toPhases.TankSolution.afMass(this.oMT.tiN2I.Urine);
                else
                    afUrineMass(this.oMT.tiN2I.Urine) = 0.99 * this.toStores.CROP_Tank.toPhases.TankSolution.afMass(this.oMT.tiN2I.Urine);
                end
                afResolvedCompoundMass = this.oMT.resolveCompoundMass(afUrineMass, this.toStores.CROP_Tank.toPhases.TankSolution.arCompoundMass);

                afResolvedCompoundMass(this.oMT.tiN2I.Urine) = - afUrineMass(this.oMT.tiN2I.Urine);

                this.toStores.CROP_Tank.toPhases.TankSolution.toManips.substance.setMassTransfer(afResolvedCompoundMass, 60);
            end

            if ~this.bManualUrineSupply
                % This part is only performed if crop should automatically
                % refill and this is not handled by the parent system
                if this.toStores.CROP_Tank.toPhases.TankSolution.afMass(this.oMT.tiN2I.CH4N2O) < 2e-3 &&...
                    ~this.toBranches.CROP_Solution_Outlet.oHandler.bMassTransferActive && ...
                    ~this.toStores.CROP_Tank.toPhases.TankSolution.toManips.substance.bMassTransferActive
                    % In this case the urea within the CROP system has been
                    % converted to ammonium or ammonia and can be used in plant
                    % systems. Therefore we first empty the tank and then
                    % refill it with fresh urine
                    if (this.toStores.CROP_Tank.toPhases.TankSolution.fMass > 0.02 * sum(this.afInitialMasses)) &&...
                            this.toStores.CROP_Tank.toPhases.TankSolution.fMass > 0.001 && this.toStores.CROP_Tank.toPhases.TankSolution.afMass(this.oMT.tiN2I.Urine) < 0.1

                        this.toBranches.CROP_Solution_Outlet.oHandler.setMassTransfer(0.99 * this.toStores.CROP_Tank.toPhases.TankSolution.fMass, 60);

                        tTimeStepProperties = struct();
                        tTimeStepProperties.rMaxChange = inf;
                        this.toStores.CROP_Tank.toPhases.TankSolution.oCapacity.setTimeStepProperties(tTimeStepProperties);
                        tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                        this.toStores.CROP_Tank.toPhases.TankSolution.setTimeStepProperties(tTimeStepProperties);

                        this.toBranches.Tank_to_BioFilter.oHandler.setFlowRate(0);

                    elseif ~this.toBranches.CROP_Urine_Inlet.oHandler.bMassTransferActive
                        if this.toBranches.CROP_Urine_Inlet.coExmes{2}.oPhase.fMass > this.fCapacity

                            csChilds = fieldnames(this.oParent.toChildren);
                            bOtherCROP_ReceivingUrine = false;
                            for iChild = 1:length(csChilds)
                                if isa(this.oParent.toChildren.(csChilds{iChild}), 'components.matter.CROP.CROP')
                                    if this.oParent.toChildren.(csChilds{iChild}).toBranches.CROP_Urine_Inlet.oHandler.bMassTransferActive
                                        bOtherCROP_ReceivingUrine = true;
                                    end
                                end
                            end
                            if ~bOtherCROP_ReceivingUrine
                            
                                tTimeStepProperties = struct();
                                tTimeStepProperties.rMaxChange = inf;
                                this.toStores.CROP_Tank.toPhases.TankSolution.oCapacity.setTimeStepProperties(tTimeStepProperties);
                                tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                                this.toStores.CROP_Tank.toPhases.TankSolution.setTimeStepProperties(tTimeStepProperties);

                                this.toBranches.CROP_Urine_Inlet.oHandler.setMassTransfer(-( this.fCapacity - this.toStores.CROP_Tank.toPhases.TankSolution.fMass), 60);
                            end
                        end
                    end
                    this.bResetInitialMass = true;
                end

                % Check if we have to reset the initial mass since we refilled
                % the tank:
                if this.bResetInitialMass && ~this.toBranches.CROP_Urine_Inlet.oHandler.bMassTransferActive && ~this.toStores.CROP_Tank.toPhases.TankSolution.toManips.substance.bMassTransferActive &&...
                        ~this.toBranches.CROP_Solution_Outlet.oHandler.bMassTransferActive && this.toStores.CROP_Tank.toPhases.TankSolution.fMass > 0.5 * this.fCapacity
                    this.afInitialMasses = this.toStores.CROP_Tank.toPhases.TankSolution.afMass;
                    this.toBranches.Tank_to_BioFilter.oHandler.setVolumetricFlowRate(1 / 3600);

                    tTimeStepProperties = struct();
                    tTimeStepProperties.rMaxChange = 1e-3;
                    this.toStores.CROP_Tank.toPhases.TankSolution.oCapacity.setTimeStepProperties(tTimeStepProperties);
                    tTimeStepProperties.arMaxChange = zeros(1, this.oMT.iSubstances);
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.CH4N2O)  = 0.1;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.NH3)     = 0.1;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.NH4)     = 0.1;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.NO2)     = 0.1;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.NO3)     = 0.1;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.C6H5O7)  = 0.1;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.CO3)     = 0.5;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.CO2)     = 0.5;
                    tTimeStepProperties.arMaxChange(this.oMT.tiN2I.Ca2plus) = 0.5;
                    this.toStores.CROP_Tank.toPhases.TankSolution.setTimeStepProperties(tTimeStepProperties);

                    this.bResetInitialMass = false;
                end
            end
            
            if this.toStores.CROP_Tank.toPhases.TankSolution.fMass < 1
                this.toBranches.Tank_to_BioFilter.oHandler.setVolumetricFlowRate(0);
                oCapacity = this.toStores.CROP_Tank.toPhases.TankSolution.oCapacity;
                oCapacity.toHeatSources.Heater.setHeatFlow(0);
            else
                % If the calcite mass within CROP drops below 50g resupply new
                % calcite:
                if this.toStores.CROP_Tank.toPhases.Calcite.afMass(this.oMT.tiN2I.CaCO3) < 0.05 && ~this.toBranches.CROP_Calcite_Inlet.oHandler.bMassTransferActive
                    fRequiredCalcite = 0.5 - this.toStores.CROP_Tank.toPhases.Calcite.afMass(this.oMT.tiN2I.CaCO3);
                    this.toBranches.CROP_Calcite_Inlet.oHandler.setMassTransfer(- fRequiredCalcite, 60)
                end

                % Check crop tank temperature and regulate it:
                oCapacity = this.toStores.CROP_Tank.toPhases.TankSolution.oCapacity;
                fHeatFlow = 0;
                if ~this.bResetInitialMass 
                    fTemperatureDifference = 298.15 - oCapacity.fTemperature;
                    fHeatFlow = (fTemperatureDifference * oCapacity.fTotalHeatCapacity) / (5*this.fTimeStep);
                    oCapacity.toHeatSources.Heater.setHeatFlow(fHeatFlow);
                else
                    oCapacity.toHeatSources.Heater.setHeatFlow(fHeatFlow);
                end
                this.fCurrentPowerConsumption = 7 + abs(fHeatFlow);
            end
        end
    end
end