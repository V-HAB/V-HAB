classdef UPA < vsys
    %% UPA
    % this a simple model of the Urine Processing Assembly used on the ISS
    % it only models the delays and recovery rates and is not based on
    % first principles. Also note the fact that 0.21 lbs hardware per 1 lbs
    % of distilatte of replacement hardware are required for UPA according
    % to "Upgrades to the ISS Water Recovery System", Jennifer M. Pruitt
    % et. al., 2015, ICES-2015-133
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Source "International Space Station Water Balance
        % Operations", Barry Tobias et al., 2011) is mentioned as [1] in
        % the following
        
        % UPA flowrate based on the Water Operations mentioned in [1] to
        % operate for 7.5 h and then pause for 5 h and the nominal flowrate
        % of 9 kg /day mentioned in "Status of ISS Water Management and
        % Recovery", Layner Carter et. al, 2019, ICES-2019-36
        fBaseFlowRate = 1.7361e-4;
        
        % Size of the Wastewater Storage Tank Assembly (WSTA)
        % According to the figures in [1] the thw WSTA moves from 62% to 8%
        % fill (so 545% of its capacity) and that equals a RFTA load in l
        % of 56.92 . 49.9 = 7.02 l. This means the WSTA has a capacity of
        % 7.02/0.54 = 13 l
        fWSTACapacity = 13 * 0.998;
        
        % Size of the Advanced Recycled Tank Filter Assembly (ARTFA) in which the
        % brine fluid is stored. According to "Upgrades to the ISS Water
        % Recovery System", Jennifer M. Pruitt et. al., 2015, ICES-2015-133
        % the ARTFA has a capacity of 22 l. However in "Closing the Water
        % Loop for Exploration: 2018 Status of the Brine Processor
        % Assembly", Laura K. Kelsey et.al., 2018, ICES-2018-272, the ARTFA
        % is mentioned to have 22.5 l capacity which are provided to the
        % BPA. Therefore this value is used as it appears to be the more
        % accurate value
        fARTFACapacity = 22.5 * 0.998;
        
        % Boolean that indicates UPA activity
        bProcessing = false;
        
        % Time at which the last UPA process finished
        fProcessingFinishTime = -20000;
        
        fUPAActivationFill;
        fTankCapacityNotProcessed;
        
        % Power usage in Standby from "Status of the Regenerative ECLSS Water Recovery System", D. Layne Carter, ICES-2009-2352
        fPower = 56 ; % [W]
        
        % This boolean can be used to decide whether the system should
        % automatically try to get the urine if it is required or if the
        % user will specify a urine supply logic in the parent system
        bManualUrineSupply  = false;
        
        fInitialMassParentUrineSupply = 0;
    end
    
    methods
        function this = UPA(oParent, sName, fTimeStep, ~)
            if nargin < 3
                fTimeStep = 60;
            end
            this@vsys(oParent, sName, fTimeStep);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            % The UPA starts working when the waste water tank is filled by
            % 70%, 8% of the tanks capacity are not being processed
            % Source: 
            this.fUPAActivationFill         = 0.70 * this.fWSTACapacity;
            this.fTankCapacityNotProcessed  = 0.08 * this.fWSTACapacity;
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating the WSTA (Wastewater Storage Tank Assembly)
            
            matter.store(this, 'WSTA', this.fWSTACapacity / 998);
            matter.phases.mixture(this.toStores.WSTA,           'Urine', 'liquid', struct('Urine', this.fUPAActivationFill + 0.1), 293, 1e5);
            
            % Creating the ARTFA (Advanced Recycle Filter Tank Assembly)
            matter.store(this, 'ARTFA', this.fARTFACapacity / 998);
            matter.phases.mixture(this.toStores.ARTFA,            'Brine', 'liquid', struct('Brine', 0.1), 293, 1e5);
           
            % Creating the distillation assembly
            matter.store(this, 'DistillationAssembly', 3e-3);
            this.toStores.DistillationAssembly.createPhase( 	'mixture',                	'Urine',  'liquid', 1e-3, struct('Urine', 1), 293, 1e5);
            this.toStores.DistillationAssembly.createPhase( 	'mixture',                	'Brine', 'liquid',  1e-3, struct('Brine', 1), 293, 1e5);
            this.toStores.DistillationAssembly.createPhase( 	'liquid',                	'H2O',              1e-3, struct('H2O', 1), 293, 1e5);
            
            % Creating the ExMes
            matter.procs.exmes.mixture(this.toStores.WSTA.toPhases.Urine,                   'Inlet');
            matter.procs.exmes.mixture(this.toStores.WSTA.toPhases.Urine,                   'WSTA_to_Distillation');
            matter.procs.exmes.liquid(this.toStores.DistillationAssembly.toPhases.H2O,      'Outlet');
            matter.procs.exmes.liquid(this.toStores.DistillationAssembly.toPhases.H2O,      'Water_from_P2P');
            matter.procs.exmes.mixture(this.toStores.DistillationAssembly.toPhases.Urine,   'Water_from_WSTA');
            matter.procs.exmes.mixture(this.toStores.DistillationAssembly.toPhases.Urine,   'Brine_to_P2P');
            matter.procs.exmes.mixture(this.toStores.DistillationAssembly.toPhases.Urine,   'Water_to_P2P');
            matter.procs.exmes.mixture(this.toStores.DistillationAssembly.toPhases.Brine,   'Brine_to_ARTFA');
            matter.procs.exmes.mixture(this.toStores.DistillationAssembly.toPhases.Brine,   'Brine_from_P2P');
            matter.procs.exmes.mixture(this.toStores.ARTFA.toPhases.Brine,                  'Brine_from_Distillation');
            matter.procs.exmes.mixture(this.toStores.ARTFA.toPhases.Brine,                  'Brine_to_Outlet');
            
            components.matter.P2Ps.ManualP2P(this.toStores.DistillationAssembly, 'BrineP2P', 'Urine.Brine_to_P2P', 'Brine.Brine_from_P2P');
            components.matter.P2Ps.ManualP2P(this.toStores.DistillationAssembly, 'WaterP2P', 'Urine.Water_to_P2P', 'H2O.Water_from_P2P');
            
            % Creating the manual branches
            matter.branch(this, 'WSTA.Inlet',                           {}, 'Inlet',        'Inlet');
            matter.branch(this, 'DistillationAssembly.Outlet',          {}, 'Outlet',       'Outlet');
            matter.branch(this, 'ARTFA.Brine_to_Outlet',                {}, 'BrineOutlet',  'BrineOutlet');
            
            matter.branch(this, 'WSTA.WSTA_to_Distillation',            {}, 'DistillationAssembly.Water_from_WSTA', 'WSTA_to_DA');
            matter.branch(this, 'DistillationAssembly.Brine_to_ARTFA',  {}, 'ARTFA.Brine_from_Distillation', 'DA_to_ARTFA');
            
            % Creating the manipulator
            components.matter.UPA.components.UPA_Manip('UPA_Manip', this.toStores.DistillationAssembly.toPhases.Urine);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Water can now flow into the UPA by using this inlet branch,
            % note that you have to use a negative flowrate / mass to
            % transfer for it to flow into the UPA, because of the way
            % interface branches are defined
            solver.matter.manual.branch(this.toBranches.Inlet);
            
            % Mass can be taken out of the WPA by using this branch, here a
            % positive flowrate will result in mass leaving the WPA!
            solver.matter.manual.branch(this.toBranches.Outlet);
            
            solver.matter.manual.branch(this.toBranches.BrineOutlet);
            
            solver.matter.manual.branch(this.toBranches.WSTA_to_DA);
            solver.matter.residual.branch(this.toBranches.DA_to_ARTFA);
            
            % The ARTFA mass change is not limited. Since it is only filled
            % and then emptied via mass change and the changes in between
            % are not relevant to the system
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = inf;
            tTimeStepProperties.fMaxStep = 5 * this.fTimeStep;

            this.toStores.ARTFA.toPhases.Brine.setTimeStepProperties(tTimeStepProperties);
                    
            tTimeStepProperties = struct();
            tTimeStepProperties.rMaxChange = inf;
            tTimeStepProperties.fMaxStep = 5 * this.fTimeStep;
            this.toStores.WSTA.toPhases.Urine.setTimeStepProperties(tTimeStepProperties);
                    
            this.setThermalSolvers();
            
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
        end
        
        function setUrineSupplyToManual(this, bManualUrineSupply)
            this.bManualUrineSupply = bManualUrineSupply;
        end
        
        function setIfFlows(this, sInlet, sOutlet, sBrineOultet)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('Inlet',         sInlet);
            this.connectIF('Outlet',        sOutlet);
            this.connectIF('BrineOutlet',   sBrineOultet);
            
            this.fInitialMassParentUrineSupply = this.toBranches.Inlet.coExmes{2}.oPhase.fMass;
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            if ~this.bManualUrineSupply && this.toStores.WSTA.toPhases.Urine.fMass < this.fWSTACapacity
                fDesiredUrineMass = this.fWSTACapacity - this.toStores.WSTA.toPhases.Urine.fMass;

                fCurrentlyAvailableUrineParent = this.toBranches.Inlet.coExmes{2}.oPhase.fMass - this.fInitialMassParentUrineSupply;
                if fCurrentlyAvailableUrineParent < 0
                    % in this case no Urine for UPA operation is available
                else
                    if ~this.toBranches.Inlet.oHandler.bMassTransferActive
                        if fCurrentlyAvailableUrineParent > fDesiredUrineMass
                            this.toBranches.Inlet.oHandler.setMassTransfer(-fDesiredUrineMass, 60);
                        else
                            this.toBranches.Inlet.oHandler.setMassTransfer(-fCurrentlyAvailableUrineParent, 60);
                        end
                    end
                end
            end
            
            % Time condition is because the UPA requires a 5 hour cooldown
            % after each cycle see [1]
            if (this.toStores.WSTA.toPhases.Urine.fMass >= this.fUPAActivationFill) && (this.oTimer.fTime - this.fProcessingFinishTime) > 18000
                this.bProcessing = true;
                this.fProcessingFinishTime = inf;
            end
            
            if (this.bProcessing == true)
                if this.oTimer.fTime >= this.fProcessingFinishTime
                    this.toStores.DistillationAssembly.toPhases.Urine.toManips.substance.setActive(false);
                    this.bProcessing = false;
                    this.fPower = 56;
                elseif(this.toStores.WSTA.toPhases.Urine.fMass >= this.fTankCapacityNotProcessed)
                    % The bMassTransferActive check prevents the logic to try
                    % and set a new flowrate if a mass transfer is already
                    % occuring at the moment
                    if ~this.toBranches.WSTA_to_DA.oHandler.bMassTransferActive
                        this.toStores.DistillationAssembly.toPhases.Urine.toManips.substance.setActive(true);
                        fMassToProcess = this.toStores.WSTA.toPhases.Urine.fMass - this.fTankCapacityNotProcessed;
                        fTimeToProcess = fMassToProcess / this.fBaseFlowRate;
                        this.fProcessingFinishTime = this.oTimer.fTime + fTimeToProcess;
                        this.toBranches.WSTA_to_DA.oHandler.setMassTransfer(fMassToProcess, fTimeToProcess);
                        this.fPower = 315; % [W]
                    end
                end
            end
            
            % According to "Closing the Water Loop for Exploration: 2018
            % Status of the Brine Processor Assembly", Laura K. Kelsey
            % et.al., 2018, ICES-2018-272, the complete 22.5 l of ARTFA
            % volume are provided to the BPA, since the initial mass in the
            % ARTFA here is 0.1 kg, we move the complete ARTFA Capacity
            % except the initial mass. The time for the operation is
            % unclear, we use 5 minutes here
            if this.toStores.ARTFA.toPhases.Brine.fMass >= this.fARTFACapacity + 0.1
                this.toBranches.BrineOutlet.oHandler.setMassTransfer(this.toStores.ARTFA.toPhases.Brine.fMass - 0.1, 300);
            end
        end
    end
end