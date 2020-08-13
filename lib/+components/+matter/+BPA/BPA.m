classdef BPA < vsys
    %% BPA
    % this a simple model of the Brine Processing Assembly used on the ISS
    % it only models the delays and recovery rates and is not based on
    % first principles.
    
    properties (SetAccess = protected, GetAccess = public)
        % Source "Closing the Water Loop for Exploration: 2018
        % Status of the Brine Processor Assembly", Laura K. Kelsey
        % et.al., 2018, ICES-2018-272 is mentioned as [1] in
        % the following
        
        % Size of the Brine Bladder (WSTA)
        % According to  [1] the Brine Bladders are oversized to have a
        % capacity of 24 l but are only filled with 22.5 l which is the
        % UPAs ARTFA capacity
        fBladderCapacity = 24 * 0.998;
        
        fActivationFillBPA = 22.5 * 0.998;
        
        % BPA flowrate based on 22.5 l per 26 day cycle mentioned in [1] 
        fBaseFlowRate = 22.5*0.998 / (26*24*3600);
        
        % Boolean that indicates UPA activity
        bProcessing = false;
        
        % Time at which the last UPA process finished
        fProcessingFinishTime = -20000;
        
        % According to [1] each cycle requires 26 days
        fProcessingTime = 26*24*3600;
        
        % Power usage of BPA is currently unknown, but it uses fans and
        % heaters and some electronics, so a small power demand based on
        % the UPA standby power demand is used here
        fPower = 56 ; % [W]
    end
    
    methods
        function this = BPA(oParent, sName)
            % Set the initial time step to 60 s
            this@vsys(oParent, sName, 60);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating the WSTA (Wastewater Storage Tank Assembly)
            
            matter.store(this, 'Bladder', (this.fBladderCapacity / 998) + 0.5);
            % BPA is initialized as full as UPA ARTFA is initiliazed empty
            oBladder = matter.phases.mixture(this.toStores.Bladder,          'Brine', 'liquid', struct('Brine', 22.5*0.998 + 0.01), 293, 1e5);
            oAir     = this.toStores.Bladder.createPhase(  'gas', 'flow',   'Air',   0.5, struct('N2', 8e4, 'O2', 2e4, 'CO2', 400), 293, 0.5);
            
            components.matter.P2Ps.ManualP2P(this.toStores.Bladder, 'WaterP2P', oBladder, oAir);
            
            % The Brine Bladders actually have to be disposed manually,
            % here we use a store to move the concentrated brine there at
            % the end of each cycle.
            matter.store(this, 'ConcentratedBrineDisposal', 2);
            oConcentratedBrine = this.toStores.ConcentratedBrineDisposal.createPhase( 	'mixture', 	'ConcentratedBrine',  'liquid', 0.1, struct('ConcentratedBrine', 0.1), 293, 1e5);
            
            % Creating the manual branches
            matter.branch(this, oBladder,        	{}, 'BrineInlet',  	'BrineInlet');
            matter.branch(this, oAir,             	{}, 'AirInlet',    	'AirInlet');
            matter.branch(this, oAir,           	{}, 'AirOutlet',    'AirOutlet');
            
            matter.branch(this, oBladder,         	{}, oConcentratedBrine,  'ConcentratedBrineDisposal');
            
            % Creating the manipulator
            components.matter.BPA.components.BPA_Manip('BPA_Manip', this.toStores.Bladder.toPhases.Brine);
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            
            solver.matter.manual.branch(this.toBranches.BrineInlet);
            solver.matter.manual.branch(this.toBranches.AirInlet);
            solver.matter.manual.branch(this.toBranches.ConcentratedBrineDisposal);
            
            this.toBranches.AirInlet.oHandler.setFlowRate(-0.1);
            
            tSolverProperties.fMaxError = 1e-6;
            tSolverProperties.iMaxIterations = 1000;
            tSolverProperties.fMinimumTimeStep = 1;
            tSolverProperties.iIterationsBetweenP2PUpdate = 200;
            tSolverProperties.bSolveOnlyFlowRates = true;
            
            oSolver = solver.matter_multibranch.iterative.branch(this.toBranches.AirOutlet, 'complex');
            oSolver.setSolverProperties(tSolverProperties);
            
            tTimeStepProperties.rMaxChange = inf;
            tTimeStepProperties.fMaxStep = this.fTimeStep;

            this.toStores.Bladder.toPhases.Brine.setTimeStepProperties(tTimeStepProperties);
            this.toStores.ConcentratedBrineDisposal.toPhases.ConcentratedBrine.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();
        end
        
        function setIfFlows(this, sBrineInlet, sAirInlet, sAirOultet)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('BrineInlet',   	sBrineInlet);
            this.connectIF('AirInlet',      sAirInlet);
            this.connectIF('AirOutlet',     sAirOultet);
            
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            
            if (this.toStores.Bladder.toPhases.Brine.fMass >= this.fActivationFillBPA)
                this.bProcessing = true;
                this.fProcessingFinishTime = inf;
                
                % During processing the brine bladder mass change is
                % limited
                tTimeStepProperties = struct();
                tTimeStepProperties.rMaxChange = 1e-3;
                tTimeStepProperties.fMaxStep = 20;

                this.toStores.Bladder.toPhases.Brine.setTimeStepProperties(tTimeStepProperties);
            end
            
            if (this.bProcessing == true)
                if this.oTimer.fTime >= this.fProcessingFinishTime
                    this.toStores.Bladder.toPhases.Brine.toManips.substance.setActive(false);
                    this.bProcessing = false;
                    
                    % While BPA is not processing the mass in the brine
                    % bladder phase can change by as much as it likes
                    tTimeStepProperties = struct();
                    tTimeStepProperties.rMaxChange = inf;
                    tTimeStepProperties.fMaxStep = this.fTimeStep;

                    this.toStores.Bladder.toPhases.Brine.setTimeStepProperties(tTimeStepProperties);
                    
                elseif(this.toStores.Bladder.toPhases.Brine.fMass >= 0.01)
                    this.toStores.Bladder.toPhases.Brine.toManips.substance.setActive(true);
                    this.fProcessingFinishTime = this.oTimer.fTime + this.fProcessingTime;
                    
                end
            end
            
            if ~this.bProcessing && this.Bladder.toPhases.Brine.fMass >= 0.01
                this.toBranches.ConcentratedBrineDisposal.oHandler.setMassTransfer(this.toStores.Bladder.toPhases.Brine.fMass - 0.01, 300);
            end
        end
    end
end